"""HTTP API for the Aureum jewellery ledger."""

from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse

from aureum_api import calc
from aureum_api.db import (
    CATEGORIES,
    CURRENCIES,
    KARATS,
    STORAGES,
    UPLOADS,
    connect,
    init_db,
)
from aureum_api.seed import seed_if_empty

MAX_IMAGE_BYTES = 8 * 1024 * 1024

@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    seed_if_empty()
    yield


app = FastAPI(title="Aureum", version="1.0.0", lifespan=lifespan)


@app.exception_handler(RequestValidationError)
async def validation_error(_request, exc: RequestValidationError):
    parts: list[str] = []
    for err in exc.errors():
        loc = " ".join(str(item) for item in err.get("loc", []) if item not in ("body", "query"))
        parts.append(f"{loc}: {err.get('msg')}".strip())
    return JSONResponse(status_code=422, content={"detail": "; ".join(parts) or "Check the form and try again."})


@app.middleware("http")
async def nosniff(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _settings(conn) -> dict[str, Any]:
    row = conn.execute("SELECT currency, gold_rate_24k, updated_at FROM settings WHERE id = 1").fetchone()
    return {
        "currency": row["currency"],
        "gold_rate_24k": row["gold_rate_24k"],
        "updated_at": row["updated_at"],
    }


def _piece_out(row, rate: float) -> dict[str, Any]:
    net = calc.net_weight(row["gross_weight_g"], row["stone_weight_g"])
    fine = calc.fine_weight(net, row["karat"], row["wastage_percent"])
    metal = calc.gold_value(fine, rate)
    estimated = calc.estimated_value(metal, row["making_charge"])
    return {
        "id": row["id"],
        "name": row["name"],
        "category": row["category"],
        "gross_weight_g": calc.round_grams(row["gross_weight_g"]),
        "stone_weight_g": calc.round_grams(row["stone_weight_g"]),
        "net_weight_g": calc.round_grams(net),
        "karat": row["karat"],
        "wastage_percent": row["wastage_percent"],
        "making_charge": calc.round_money(row["making_charge"]),
        "purchase_price": calc.round_money(row["purchase_price"]),
        "acquired_on": row["acquired_on"],
        "storage": row["storage"],
        "hallmark": row["hallmark"],
        "notes": row["notes"],
        "has_image": bool(row["image_file"]),
        "has_bill": bool(row["bill_file"]),
        "fine_weight_g": calc.round_grams(fine),
        "gold_value": calc.round_money(metal),
        "estimated_value": calc.round_money(estimated),
        "unrealized": calc.round_money(calc.unrealized(estimated, row["purchase_price"])),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _totals(pieces: list[dict[str, Any]]) -> dict[str, Any]:
    def add(key: str) -> float:
        return calc.round_money(sum(piece[key] for piece in pieces)) if key != "pieces" else 0

    gross = calc.round_grams(sum(piece["gross_weight_g"] for piece in pieces))
    stone = calc.round_grams(sum(piece["stone_weight_g"] for piece in pieces))
    net = calc.round_grams(sum(piece["net_weight_g"] for piece in pieces))
    fine = calc.round_grams(sum(piece["fine_weight_g"] for piece in pieces))
    return {
        "pieces": len(pieces),
        "gross_weight_g": gross,
        "stone_weight_g": stone,
        "net_weight_g": net,
        "fine_weight_g": fine,
        "gold_value": add("gold_value"),
        "making_charges": add("making_charge"),
        "estimated_value": add("estimated_value"),
        "purchase_price": add("purchase_price"),
        "unrealized": add("unrealized"),
    }


def _by_category(pieces: list[dict[str, Any]]) -> list[dict[str, Any]]:
    buckets: dict[str, list[dict[str, Any]]] = {}
    for piece in pieces:
        buckets.setdefault(piece["category"], []).append(piece)
    rows = []
    for category in CATEGORIES:
        group = buckets.get(category)
        if not group:
            continue
        rows.append(
            {
                "category": category,
                "pieces": len(group),
                "net_weight_g": calc.round_grams(sum(item["net_weight_g"] for item in group)),
                "estimated_value": calc.round_money(sum(item["estimated_value"] for item in group)),
            }
        )
    return rows


def _by_karat(pieces: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows = []
    for karat in KARATS:
        group = [piece for piece in pieces if abs(piece["karat"] - karat) < 0.05]
        totals = _totals(group)
        rows.append(
            {
                "karat": karat,
                "pieces": totals["pieces"],
                "net_weight_g": totals["net_weight_g"],
                "fine_weight_g": totals["fine_weight_g"],
                "estimated_value": totals["estimated_value"],
            }
        )
    return rows


def _load_pieces(conn) -> list[dict[str, Any]]:
    rate = _settings(conn)["gold_rate_24k"]
    rows = conn.execute("SELECT * FROM pieces ORDER BY created_at DESC, name COLLATE NOCASE").fetchall()
    return [_piece_out(row, rate) for row in rows]


def _get_row(conn, piece_id: str):
    return conn.execute("SELECT * FROM pieces WHERE id = ?", (piece_id,)).fetchone()


def _clean_text(value: str, field: str, limit: int, required: bool = False) -> str:
    text = " ".join(value.split()) if field != "notes" else value.strip()
    if required and not text:
        raise HTTPException(status_code=422, detail=f"Enter a {field}.")
    if len(text) > limit:
        raise HTTPException(status_code=422, detail=f"{field.capitalize()} must be {limit} characters or fewer.")
    return text


def _validate_numbers(
    gross: float,
    stone: float,
    karat: float,
    wastage: float,
    making: float,
    purchase: float,
) -> None:
    if gross <= 0 or gross > 100_000:
        raise HTTPException(status_code=422, detail="Gross weight must be greater than 0 and at most 100,000 g.")
    if stone < 0:
        raise HTTPException(status_code=422, detail="Stone weight cannot be negative.")
    if stone > gross:
        raise HTTPException(status_code=422, detail="Stone weight cannot be heavier than the gross weight.")
    if not any(abs(karat - allowed) < 0.05 for allowed in KARATS):
        raise HTTPException(status_code=422, detail="Choose 18K, 22K, or 24K.")
    if wastage < 0 or wastage > 100:
        raise HTTPException(status_code=422, detail="Wastage must be between 0 and 100 percent.")
    if making < 0 or purchase < 0:
        raise HTTPException(status_code=422, detail="Money amounts cannot be negative.")
    if making > 1_000_000_000 or purchase > 1_000_000_000:
        raise HTTPException(status_code=422, detail="Money amounts are unreasonably large.")


def _sniff_image(data: bytes) -> str | None:
    if data.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if data.startswith((b"GIF87a", b"GIF89a")):
        return ".gif"
    if len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return ".webp"
    return None


def _media_type(filename: str) -> str:
    ext = Path(filename).suffix.lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }.get(ext, "application/octet-stream")


async def _store_image(upload: UploadFile | None) -> str | None:
    if upload is None or not upload.filename:
        return None
    data = await upload.read(MAX_IMAGE_BYTES + 1)
    if not data:
        return None
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Photograph must be 8 MB or smaller.")
    ext = _sniff_image(data)
    if ext is None:
        raise HTTPException(status_code=422, detail="Use a JPEG, PNG, WEBP, or GIF photograph.")
    filename = f"{uuid4()}{ext}"
    (UPLOADS / filename).write_bytes(data)
    return filename


def _delete_image(filename: str | None) -> None:
    if not filename:
        return
    path = (UPLOADS / filename).resolve()
    if path.is_relative_to(UPLOADS.resolve()) and path.is_file():
        path.unlink()


def _parse_date(value: str) -> str | None:
    text = value.strip()
    if not text:
        return None
    try:
        datetime.strptime(text, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=422, detail="Acquired date must be a real calendar date.")
    return text


@app.get("/api/health")
def health():
    return {"ok": True}


@app.get("/api/meta")
def meta():
    return {
        "categories": list(CATEGORIES),
        "storages": list(STORAGES),
        "currencies": list(CURRENCIES),
        "karats": list(KARATS),
    }


@app.get("/api/settings")
def read_settings():
    with connect() as conn:
        return _settings(conn)


@app.post("/api/settings")
def write_settings(
    currency: str = Form(...),
    gold_rate_24k: float = Form(...),
):
    code = currency.strip().upper()
    if code not in CURRENCIES:
        raise HTTPException(status_code=422, detail="Choose a supported currency.")
    if gold_rate_24k <= 0 or gold_rate_24k > 100_000_000:
        raise HTTPException(status_code=422, detail="Enter a 24K rate greater than zero.")
    stamp = _now()
    with connect() as conn:
        conn.execute(
            "UPDATE settings SET currency = ?, gold_rate_24k = ?, updated_at = ? WHERE id = 1",
            (code, gold_rate_24k, stamp),
        )
        conn.commit()
        return _settings(conn)


@app.get("/api/summary")
def summary(q: str = "", category: str = "", karat: str = ""):
    needle = q.strip().lower()
    chosen = category.strip().lower()
    if chosen and chosen not in CATEGORIES:
        raise HTTPException(status_code=422, detail="Unknown category.")
    chosen_karat = 0
    if karat.strip():
        try:
            chosen_karat = int(float(karat))
        except ValueError:
            raise HTTPException(status_code=422, detail="Choose 18K, 22K, or 24K.")
        if chosen_karat not in KARATS:
            raise HTTPException(status_code=422, detail="Choose 18K, 22K, or 24K.")
    with connect() as conn:
        settings = _settings(conn)
        pieces = _load_pieces(conn)
    available = [category for category in CATEGORIES if any(piece["category"] == category for piece in pieces)]
    available_karats = list(KARATS)
    if chosen:
        pieces = [piece for piece in pieces if piece["category"] == chosen]
    if chosen_karat:
        pieces = [piece for piece in pieces if abs(piece["karat"] - chosen_karat) < 0.05]
    if needle:
        pieces = [
            piece
            for piece in pieces
            if needle
            in " ".join(
                [
                    piece["name"],
                    piece["notes"],
                    piece["hallmark"],
                    piece["storage"],
                    piece["category"],
                ]
            ).lower()
        ]
    return {
        "settings": settings,
        "totals": _totals(pieces),
        "by_karat": _by_karat(pieces),
        "by_category": _by_category(pieces),
        "pieces": pieces,
        "query": q.strip(),
        "category": chosen,
        "karat": chosen_karat,
        "available_categories": available,
        "available_karats": available_karats,
    }


@app.get("/api/pieces/{piece_id}")
def read_piece(piece_id: str):
    with connect() as conn:
        row = _get_row(conn, piece_id)
        if row is None:
            raise HTTPException(status_code=404, detail="That piece is not in the vault.")
        settings = _settings(conn)
        return {"piece": _piece_out(row, settings["gold_rate_24k"]), "settings": settings}


@app.get("/api/pieces/{piece_id}/image")
def read_image(piece_id: str):
    with connect() as conn:
        row = _get_row(conn, piece_id)
    if row is None or not row["image_file"]:
        raise HTTPException(status_code=404, detail="No photograph for this piece.")
    path = (UPLOADS / row["image_file"]).resolve()
    if not path.is_relative_to(UPLOADS.resolve()) or not path.is_file():
        raise HTTPException(status_code=404, detail="Photograph file is missing.")
    return FileResponse(path, media_type=_media_type(path.name))


@app.post("/api/pieces", status_code=201)
async def create_piece(
    name: str = Form(...),
    category: str = Form(...),
    gross_weight_g: float = Form(...),
    stone_weight_g: float = Form(0),
    karat: float = Form(...),
    wastage_percent: float = Form(0),
    making_charge: float = Form(0),
    purchase_price: float = Form(0),
    acquired_on: str = Form(""),
    storage: str = Form("Home safe"),
    hallmark: str = Form(""),
    notes: str = Form(""),
    image: UploadFile | None = File(None),
    bill: UploadFile | None = File(None),
):
    fields = _checked_fields(
        name, category, gross_weight_g, stone_weight_g, karat, wastage_percent,
        making_charge, purchase_price, acquired_on, storage, hallmark, notes,
    )
    image_file = await _store_image(image)
    bill_file = await _store_image(bill)
    piece_id = str(uuid4())
    stamp = _now()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO pieces (
                id, name, category, gross_weight_g, stone_weight_g, karat,
                wastage_percent, making_charge, purchase_price, acquired_on,
                storage, hallmark, notes, image_file, bill_file, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                piece_id,
                fields["name"],
                fields["category"],
                gross_weight_g,
                stone_weight_g,
                karat,
                wastage_percent,
                making_charge,
                purchase_price,
                fields["acquired_on"],
                fields["storage"],
                fields["hallmark"],
                fields["notes"],
                image_file,
                bill_file,
                stamp,
                stamp,
            ),
        )
        conn.commit()
        row = _get_row(conn, piece_id)
        return _piece_out(row, _settings(conn)["gold_rate_24k"])


@app.post("/api/pieces/{piece_id}")
async def update_piece(
    piece_id: str,
    name: str = Form(...),
    category: str = Form(...),
    gross_weight_g: float = Form(...),
    stone_weight_g: float = Form(0),
    karat: float = Form(...),
    wastage_percent: float = Form(0),
    making_charge: float = Form(0),
    purchase_price: float = Form(0),
    acquired_on: str = Form(""),
    storage: str = Form("Home safe"),
    hallmark: str = Form(""),
    notes: str = Form(""),
    image: UploadFile | None = File(None),
    bill: UploadFile | None = File(None),
):
    fields = _checked_fields(
        name, category, gross_weight_g, stone_weight_g, karat, wastage_percent,
        making_charge, purchase_price, acquired_on, storage, hallmark, notes,
    )
    new_image = await _store_image(image)
    new_bill = await _store_image(bill)
    with connect() as conn:
        row = _get_row(conn, piece_id)
        if row is None:
            _delete_image(new_image)
            _delete_image(new_bill)
            raise HTTPException(status_code=404, detail="That piece is not in the vault.")
        image_file = row["image_file"]
        bill_file = row["bill_file"]
        if new_image:
            _delete_image(image_file)
            image_file = new_image
        if new_bill:
            _delete_image(bill_file)
            bill_file = new_bill
        stamp = _now()
        conn.execute(
            """
            UPDATE pieces SET
                name = ?, category = ?, gross_weight_g = ?, stone_weight_g = ?,
                karat = ?, wastage_percent = ?, making_charge = ?, purchase_price = ?,
                acquired_on = ?, storage = ?, hallmark = ?, notes = ?, image_file = ?,
                bill_file = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                fields["name"],
                fields["category"],
                gross_weight_g,
                stone_weight_g,
                karat,
                wastage_percent,
                making_charge,
                purchase_price,
                fields["acquired_on"],
                fields["storage"],
                fields["hallmark"],
                fields["notes"],
                image_file,
                bill_file,
                stamp,
                piece_id,
            ),
        )
        conn.commit()
        updated = _get_row(conn, piece_id)
        return _piece_out(updated, _settings(conn)["gold_rate_24k"])


@app.get("/api/pieces/{piece_id}/bill")
def read_bill(piece_id: str):
    with connect() as conn:
        row = _get_row(conn, piece_id)
    if row is None or not row["bill_file"]:
        raise HTTPException(status_code=404, detail="No bill for this piece.")
    path = (UPLOADS / row["bill_file"]).resolve()
    if not path.is_relative_to(UPLOADS.resolve()) or not path.is_file():
        raise HTTPException(status_code=404, detail="Bill file is missing.")
    return FileResponse(path, media_type=_media_type(path.name))


@app.post("/api/pieces/{piece_id}/image")
async def replace_image(piece_id: str, image: UploadFile = File(...)):
    return await _replace_attachment(piece_id, "image_file", image, "Take or choose a photograph first.")


@app.post("/api/pieces/{piece_id}/bill")
async def replace_bill(piece_id: str, bill: UploadFile = File(...)):
    return await _replace_attachment(piece_id, "bill_file", bill, "Take or choose a bill first.")


async def _replace_attachment(piece_id: str, column: str, upload: UploadFile, missing: str):
    if column not in ("image_file", "bill_file"):
        raise HTTPException(status_code=500, detail="Unknown attachment.")
    stored = await _store_image(upload)
    if stored is None:
        raise HTTPException(status_code=422, detail=missing)
    with connect() as conn:
        row = _get_row(conn, piece_id)
        if row is None:
            _delete_image(stored)
            raise HTTPException(status_code=404, detail="That piece is not in the vault.")
        previous = row[column]
        stamp = _now()
        conn.execute(
            f"UPDATE pieces SET {column} = ?, updated_at = ? WHERE id = ?",
            (stored, stamp, piece_id),
        )
        conn.commit()
        updated = _get_row(conn, piece_id)
        payload = _piece_out(updated, _settings(conn)["gold_rate_24k"])
    _delete_image(previous)
    return payload


@app.post("/api/pieces/{piece_id}/delete")
def delete_piece(piece_id: str):
    with connect() as conn:
        row = _get_row(conn, piece_id)
        if row is None:
            raise HTTPException(status_code=404, detail="That piece is not in the vault.")
        conn.execute("DELETE FROM pieces WHERE id = ?", (piece_id,))
        conn.commit()
    _delete_image(row["image_file"])
    _delete_image(row["bill_file"])
    return {"ok": True}


def _checked_fields(
    name: str,
    category: str,
    gross: float,
    stone: float,
    karat: float,
    wastage: float,
    making: float,
    purchase: float,
    acquired_on: str,
    storage: str,
    hallmark: str,
    notes: str,
) -> dict[str, Any]:
    _validate_numbers(gross, stone, karat, wastage, making, purchase)
    chosen = category.strip().lower()
    if chosen not in CATEGORIES:
        raise HTTPException(status_code=422, detail="Choose a category.")
    place = storage.strip()
    if place not in STORAGES:
        raise HTTPException(status_code=422, detail="Choose where this piece is kept.")
    return {
        "name": _clean_text(name, "name", 80, required=True),
        "category": chosen,
        "acquired_on": _parse_date(acquired_on),
        "storage": place,
        "hallmark": _clean_text(hallmark, "hallmark", 80),
        "notes": notes.strip()[:2000],
    }
