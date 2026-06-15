#!/usr/bin/env bash
# =============================================================================
# run.sh — One-command async FIFO simulation
# Usage  : bash sim/run.sh
# Requires: icarus-verilog, gtkwave
#   macOS : brew install icarus-verilog && brew install --cask gtkwave
#   Linux : sudo apt-get install iverilog gtkwave
# =============================================================================

set -e
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="$REPO/sim"

echo "============================================================"
echo "  Async FIFO Simulation Runner"
echo "  Repo: $REPO"
echo "============================================================"

# ── Step 1: Lint (Verilator, optional) ──────────────────────────────────────
if command -v verilator &>/dev/null; then
  echo ""
  echo "[1/3] Verilator lint..."
  verilator --lint-only -Wall --quiet "$REPO/rtl/async_fifo.sv" \
    && echo "      Lint PASSED — zero warnings" \
    || echo "      Lint warnings found (see above)"
else
  echo "[1/3] Verilator not found — skipping lint"
  echo "      To install: brew install verilator"
fi

# ── Step 2: Compile ──────────────────────────────────────────────────────────
echo ""
echo "[2/3] Compiling with iverilog..."
iverilog -g2012 -Wall \
  -o "$SIM/sim.out" \
  "$REPO/rtl/async_fifo.sv" \
  "$REPO/tb/tb_async_fifo.sv"
echo "      Compilation OK → $SIM/sim.out"

# ── Step 3: Simulate ─────────────────────────────────────────────────────────
echo ""
echo "[3/3] Running simulation..."
cd "$SIM" && vvp sim.out | tee "$SIM/sim_log.txt"

echo ""
echo "============================================================"
if grep -q "ALL TESTS PASSED" "$SIM/sim_log.txt"; then
  echo "  ✅  ALL TESTS PASSED"
else
  echo "  ❌  FAILURES DETECTED — check sim/sim_log.txt"
fi
echo "============================================================"
echo ""
echo "Waveform : gtkwave $SIM/dump.vcd"
echo "Log      : $SIM/sim_log.txt"
