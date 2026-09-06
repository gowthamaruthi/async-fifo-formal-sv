#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
python3 -m venv build/venv
build/venv/bin/pip install click==8.1.8
if [[ ! -d build/sby/.git ]]; then git clone https://github.com/YosysHQ/sby.git build/sby; fi
git -C build/sby checkout b1a1e98cba941ec8433f8dc27f416cd7bb7f14be
