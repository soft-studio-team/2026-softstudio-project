#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/parsing-engine/server"
python3 -m pip install -r requirements.txt
exec python3 -m uvicorn api_server_engine:app --host 0.0.0.0 --port 8000 --reload
