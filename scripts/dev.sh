#!/usr/bin/env bash
# Start the Python ledger and the Swift interface together.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"
if [[ ! -x .venv/bin/uvicorn ]]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi
.venv/bin/uvicorn aureum_api.main:app --host 0.0.0.0 --port 8741 &
api_pid=$!
cleanup() { kill "$api_pid" 2>/dev/null || true; }
trap cleanup EXIT
cd "$ROOT/frontend"
exec swift run Aureum
