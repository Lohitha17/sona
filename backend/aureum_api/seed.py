"""Sample pieces so the vault is usable the first time it opens."""

from __future__ import annotations

import shutil
import uuid
from datetime import datetime, timezone

from aureum_api.db import SEED_IMAGES, UPLOADS, connect

PIECES = [
    {
        "name": "Temple mango necklace",
        "category": "necklace",
        "gross_weight_g": 46.80,
        "stone_weight_g": 4.20,
        "karat": 22,
        "wastage_percent": 6,
        "making_charge": 18500,
        "purchase_price": 312000,
        "acquired_on": "2019-11-02",
        "storage": "Bank locker",
        "hallmark": "BIS 916",
        "notes": "Mango motifs with ruby-red stones. Bought for a wedding, kept in the bank locker.",
        "image": "temple-necklace.jpg",
    },
    {
        "name": "Polki cocktail ring",
        "category": "ring",
        "gross_weight_g": 11.40,
        "stone_weight_g": 2.15,
        "karat": 18,
        "wastage_percent": 0,
        "making_charge": 8500,
        "purchase_price": 96000,
        "acquired_on": "2022-04-18",
        "storage": "Home safe",
        "hallmark": "BIS 750",
        "notes": "Uncut polki cluster. Stone weight is the diamond estimate from the invoice.",
        "image": "polki-ring.jpg",
    },
    {
        "name": "Kada bangles, pair",
        "category": "bangle",
        "gross_weight_g": 55.00,
        "stone_weight_g": 0,
        "karat": 22,
        "wastage_percent": 2,
        "making_charge": 4200,
        "purchase_price": 390000,
        "acquired_on": "2016-08-09",
        "storage": "Bank locker",
        "hallmark": "BIS 916",
        "notes": "Plain polished kadas. Weighed together as a pair.",
        "image": "kada-bangles.jpg",
    },
    {
        "name": "Pearl jhumka earrings",
        "category": "earring",
        "gross_weight_g": 18.60,
        "stone_weight_g": 1.80,
        "karat": 22,
        "wastage_percent": 8,
        "making_charge": 6400,
        "purchase_price": 145000,
        "acquired_on": "2021-01-26",
        "storage": "Worn",
        "hallmark": "BIS 916",
        "notes": "Pearl drops under the bells. Stone weight covers the pearls.",
        "image": "jhumka-earrings.jpg",
    },
    {
        "name": "Figaro chain",
        "category": "chain",
        "gross_weight_g": 28.35,
        "stone_weight_g": 0,
        "karat": 22,
        "wastage_percent": 0,
        "making_charge": 2500,
        "purchase_price": 210000,
        "acquired_on": "2024-06-14",
        "storage": "Home safe",
        "hallmark": "BIS 916",
        "notes": "Everyday chain. No stones, no wastage on the invoice.",
        "image": "figaro-chain.jpg",
    },
    {
        "name": "Pearl drop pendant",
        "category": "pendant",
        "gross_weight_g": 7.90,
        "stone_weight_g": 1.25,
        "karat": 18,
        "wastage_percent": 4,
        "making_charge": 3200,
        "purchase_price": 48000,
        "acquired_on": "2023-09-30",
        "storage": "Worn",
        "hallmark": "BIS 750",
        "notes": "Single pearl with a small emerald halo. Chain is catalogued separately.",
        "image": "pearl-pendant.jpg",
    },
]


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def seed_if_empty() -> None:
    if __import__("os").environ.get("AUREUM_SEED", "1") == "0":
        return
    with connect() as conn:
        count = conn.execute("SELECT COUNT(*) AS n FROM pieces").fetchone()["n"]
        if count:
            return
        stamp = _now()
        for piece in PIECES:
            piece_id = str(uuid.uuid4())
            image_file = None
            source = SEED_IMAGES / piece["image"]
            if source.is_file():
                image_file = f"{piece_id}.jpg"
                shutil.copyfile(source, UPLOADS / image_file)
            conn.execute(
                """
                INSERT INTO pieces (
                    id, name, category, gross_weight_g, stone_weight_g, karat,
                    wastage_percent, making_charge, purchase_price, acquired_on,
                    storage, hallmark, notes, image_file, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    piece_id,
                    piece["name"],
                    piece["category"],
                    piece["gross_weight_g"],
                    piece["stone_weight_g"],
                    piece["karat"],
                    piece["wastage_percent"],
                    piece["making_charge"],
                    piece["purchase_price"],
                    piece["acquired_on"],
                    piece["storage"],
                    piece["hallmark"],
                    piece["notes"],
                    image_file,
                    stamp,
                    stamp,
                ),
            )
        conn.commit()
