#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
"${SBY_PYTHON:-build/venv/bin/python}" "${SBY_SOURCE:-build/sby/sbysrc/sby.py}" -f formal/fifo.sby "$@"
