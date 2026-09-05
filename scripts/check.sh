#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
# Reset intentionally drives asynchronous pointer reset and synchronous RAM write enable.
verilator --lint-only -Wall -Wno-SYNCASYNCNET rtl/async_fifo.sv 2>&1 | tee build/lint.log
yosys -Q -T -p 'read_verilog -sv rtl/async_fifo.sv; synth -top async_fifo; check -assert' > build/synthesis.log
bash sim/run.sh
