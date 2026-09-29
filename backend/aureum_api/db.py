"""SQLite storage for pieces and the gold-rate setting."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = Path(os.environ.get("AUREUM_DATA", ROOT / "data"))
DB_PATH = DATA / "aureum.db"
SEED_IMAGES = ROOT / "seed_images"

CATEGORIES = (
    "necklace",
    "earring",
    "ring",
    "bangle",
    "bracelet",
    "chain",
    "pendant",
    "anklet",
    "nose-pin",
    "other",
)

STORAGES = (
    "Home safe",
    "Bank locker",
    "Worn",
    "With family",
    "Other",
)

CURRENCIES = ("INR", "USD", "EUR", "GBP", "AED", "SAR")
KARATS = (24, 22, 18)

SCHEMA = """
CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    currency TEXT NOT NULL,
    gold_rate_24k REAL NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pieces (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    gross_weight_g REAL NOT NULL,
    stone_weight_g REAL NOT NULL,
    karat REAL NOT NULL,
    wastage_percent REAL NOT NULL,
    making_charge REAL NOT NULL,
    purchase_price REAL NOT NULL,
    acquired_on TEXT,
    storage TEXT NOT NULL,
    hallmark TEXT NOT NULL,
    notes TEXT NOT NULL,
    image_blob BLOB,
    image_type TEXT,
    bill_blob BLOB,
    bill_type TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
"""


def ensure_dirs() -> None:
    DATA.mkdir(parents=True, exist_ok=True)


def connect() -> sqlite3.Connection:
    ensure_dirs()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.executescript(SCHEMA)
        columns = {info[1] for info in conn.execute("PRAGMA table_info(pieces)")}
        for name, kind in (
            ("image_blob", "BLOB"),
            ("image_type", "TEXT"),
            ("bill_blob", "BLOB"),
            ("bill_type", "TEXT"),
        ):
            if name not in columns:
                conn.execute(f"ALTER TABLE pieces ADD COLUMN {name} {kind}")
        columns = {info[1] for info in conn.execute("PRAGMA table_info(pieces)")}
        _fold_files_into_blobs(conn, columns)
        for name in ("image_file", "bill_file"):
            if name in columns:
                conn.execute(f"ALTER TABLE pieces DROP COLUMN {name}")
        row = conn.execute("SELECT id FROM settings WHERE id = 1").fetchone()
        if row is None:
            conn.execute(
                """
                INSERT INTO settings (id, currency, gold_rate_24k, updated_at)
                VALUES (1, 'INR', 9860, datetime('now'))
                """
            )
        conn.commit()


def _fold_files_into_blobs(conn: sqlite3.Connection, columns: set[str]) -> None:
    uploads = DATA / "uploads"
    pairs = (
        ("image_file", "image_blob", "image_type"),
        ("bill_file", "bill_blob", "bill_type"),
    )
    types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }
    for filename_column, blob_column, type_column in pairs:
        if filename_column not in columns:
            continue
        rows = conn.execute(
            f"SELECT id, {filename_column} AS filename FROM pieces WHERE {filename_column} IS NOT NULL"
        ).fetchall()
        for row in rows:
            path = (uploads / row["filename"]).resolve()
            if not path.is_relative_to(uploads.resolve()) or not path.is_file():
                continue
            media = types.get(path.suffix.lower(), "application/octet-stream")
            conn.execute(
                f"UPDATE pieces SET {blob_column} = ?, {type_column} = ? WHERE id = ?",
                (path.read_bytes(), media, row["id"]),
            )
            path.unlink()
