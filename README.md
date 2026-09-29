# Sona

A ledger for gold jewellery. Each piece keeps a photograph, a bill, a weight, and a karat. The vault totals net gold, making charges, and the change since you bought the pieces.

The interface is a Swift server. The ledger is a Python API. They run as two local processes, with no account and no live market feed.

## Valuation

Fine gold (grams) = (gross weight − stone weight) × (karat ÷ 24) × (1 + wastage ÷ 100)

Gold value = fine gold × your 24K price per gram

Vault value = gold value + making charge

Change = vault value − purchase price

Lower karats are scaled from the 24K rate. Wastage is the extra gold a jeweller sometimes charges on the invoice. Leave it at 0 when the bill did not include it. The making charge is a flat amount, not a rate per gram.

## On an iPhone

The phone app is a separate SwiftUI project in `ios/`. It keeps the pieces, photographs, and bills on the phone. It does not talk to the Python ledger, and it is not an App Store download. You install it from a Mac.

1. Install Xcode 16 or later from the Mac App Store.
2. Clone this repo and open `ios/Sona.xcodeproj`.
3. Select the Sona target, open Signing & Capabilities, and choose your Apple ID as the Team. Xcode can create the signing certificate for you.
4. Plug in the iPhone, tap Trust on the phone, and choose that iPhone as the run destination.
5. Press Run.

The first time the phone opens Sona, go to Settings, General, VPN & Device Management, and trust your developer certificate. A free Apple ID install lasts about 7 days, then run it from Xcode again. Photos you take or choose are saved in the same vault file as the weights and prices.

## Run the computer version

You need Python 3.11+ and Swift 6.

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn aureum_api.main:app --host 127.0.0.1 --port 8741
```

In another terminal:

```bash
cd frontend
swift run Aureum
```

Open [http://127.0.0.1:43123](http://127.0.0.1:43123).

If either command reports “address already in use”, that part is already running. Open the link above, or stop the old process and start it again. For the Swift interface, `PORT=43124 swift run Aureum` uses a different port.

`scripts/dev.sh` starts both. The first Swift build downloads Hummingbird and takes a while.

The API also serves its own docs at [http://127.0.0.1:8741/docs](http://127.0.0.1:8741/docs).

On first launch the vault includes six sample pieces. Photographs, bills, weights, and prices live together in `backend/data/aureum.db`. Pictures are SQLite blobs, not files in a folder. That database is created locally and is not part of the source tree.

`PORT` changes the Swift interface port (default `43123`). `AUREUM_API` is the ledger URL the interface calls (default `http://127.0.0.1:8741`).

## Tests

```bash
cd backend
.venv/bin/pytest
```

## What you can record

- Name, category, a photograph of the piece, and a photograph of the bill. Take either with the camera, or choose a JPEG, PNG, WEBP, or GIF up to 8 MB. On a piece that is already saved, each picture is stored as soon as you capture it.
- Gross weight, stone weight, karat (18K, 22K, or 24K), and wastage
- Making charge, purchase price, hallmark, acquired date, and where the piece is kept

Search covers name, hallmark, notes, and where a piece is kept.
