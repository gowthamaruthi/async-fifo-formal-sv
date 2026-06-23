# async-fifo-formal-sv

![CI](https://github.com/gowthamaruthi/async-fifo-formal-sv/actions/workflows/ci.yml/badge.svg)
![Language](https://img.shields.io/badge/language-SystemVerilog-blue)
![Sim](https://img.shields.io/badge/sim-iverilog-green)
![Formal](https://img.shields.io/badge/formal-SymbiYosys-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

Parameterized **dual-clock asynchronous FIFO** in SystemVerilog.  
Gray-coded pointer CDC · SVA assertions · SymbiYosys formal verification.

---

## Features

- [x] Parameterizable `DEPTH` and `WIDTH` (any power-of-2 depth ≥ 4)
- [x] Dual independent clocks — `wr_clk` / `rd_clk` at different frequencies
- [x] Gray-coded pointer synchronization (2-FF CDC) — zero metastability
- [x] Combinational `full` / `empty` flags (Cummings dual-MSB inversion method)
- [x] Combinational read port — data valid when `!empty`
- [x] SVA assertions: `AST_NO_OVERFLOW`, `AST_NO_UNDERFLOW`, `AST_RST_EMPTY`
- [x] Self-checking testbench — scoreboard, 4 test cases, pass/fail count
- [x] GitHub Actions CI (compile + simulate on every push)
- [x] SymbiYosys formal config (prove no overflow/underflow for all inputs)

---

## Block Diagram

```
Write Domain              │  CDC (2-FF)  │  Read Domain
──────────────────────────┼──────────────┼──────────────────────────
wr_clk  wr_en  wr_data   │              │  rd_clk  rd_en  rd_data
    │      │      │       │              │      │      │      │
    ▼      ▼      ▼       │              │      ▼      ▼      ▼
┌─────────────────────┐   │              │  ┌─────────────────────┐
│   Write Pointer     │──gray──► 2FF ──►│  │   Read Pointer      │
│   (binary + gray)   │   │              │  │   (binary + gray)   │
└────────┬────────────┘   │              │  └────────┬────────────┘
         │                │              │           │
         ▼                │              │           ▼
┌─────────────────────┐   │              │     ┌──────────┐
│   Shared Memory     │◄──┘              └────►│  rd_data │
│   [DEPTH x WIDTH]   │                        └──────────┘
└─────────────────────┘
         │                              │
    wr_gray ─────── 2FF ──────────────►│──► empty (read domain)
    full (write domain) ◄──── 2FF ─────│─── rd_gray
```

---

## Simulation Results

> Screenshot goes here after running (see How to Run below)

```
============================================================
  ASYNC FIFO — SELF-CHECKING TESTBENCH
  DEPTH=16  WIDTH=8  WR=100 MHz  RD=77 MHz
============================================================

[RESET] Released — empty=1 full=0
── TEST 1: Write 8 items, then read 8 items ──────────────
[RD] PASS  got=0xA0  exp=0xA0
[RD] PASS  got=0xA1  exp=0xA1
...
── TEST 2: Fill FIFO → verify full flag ──────────────────
[TEST 2] PASS: full=1 correctly after 16 writes
── TEST 3: Drain FIFO → verify empty flag ────────────────
[TEST 3] PASS: empty=1 correctly after draining 16 items
── TEST 4: Interleaved writes/reads (async clocks) ───────
[TEST 4] Wrote 32 items, read 32 items

============================================================
  RESULTS  |  PASS: 42  |  FAIL: 0
  STATUS   :  ALL TESTS PASSED ✓
============================================================
```

---

## How to Run

### Prerequisites

```bash
# macOS (Homebrew)
brew install icarus-verilog
brew install --cask gtkwave     # waveform viewer
brew install verilator          # optional: lint check

# Ubuntu / Debian
sudo apt-get install iverilog gtkwave
```

### Simulate

```bash
git clone https://github.com/gowthamaruthi/async-fifo-formal-sv
cd async-fifo-formal-sv
bash sim/run.sh
```

### View Waveform

```bash
gtkwave sim/dump.vcd
```
Signals to add in GTKWave: `wr_clk`, `rd_clk`, `wr_en`, `rd_en`, `wr_data`, `rd_data`, `full`, `empty`

### Formal Verification (SymbiYosys)

```bash
pip install symbiyosys
brew install yosys          # macOS
sby -f formal/fifo.sby
```

---

## Verification Strategy

| Layer | Tool | What it proves |
|---|---|---|
| Self-checking TB | iverilog | Data integrity: every written byte matches the read byte |
| Flag checks | iverilog | `full` asserts after DEPTH writes; `empty` asserts after drain |
| Runtime assertions | iverilog SVA | No overflow or underflow during any test |
| Formal proof | SymbiYosys (sby) | Mathematically proves no overflow/underflow exists for **all** possible inputs |

---

## Repository Structure

```
async-fifo-formal-sv/
├── rtl/
│   └── async_fifo.sv          ← RTL source (parameterized, synthesizable)
├── tb/
│   └── tb_async_fifo.sv       ← Self-checking testbench + scoreboard
├── sim/
│   ├── run.sh                 ← One-command simulation script
│   ├── dump.vcd               ← Generated waveform (after running)
│   └── sim_log.txt            ← Generated simulation log
├── formal/
│   └── fifo.sby               ← SymbiYosys formal config
├── docs/
│   └── waveforms/             ← GTKWave screenshots
├── .github/
│   └── workflows/
│       └── ci.yml             ← GitHub Actions (compile + sim on push)
└── README.md
```

---

## Key Design Concepts

**Gray-coded CDC:** Binary pointers converted to Gray code before crossing clock domains.  
Only one bit changes per increment, eliminating multi-bit metastability risk.

**Full detection (Cummings dual-MSB inversion):**
```
full = (wr_gray == {~rd_gray_sync[MSB], ~rd_gray_sync[MSB-1], rd_gray_sync[MSB-2:0]})
```
When wr_ptr has wrapped around exactly DEPTH positions ahead of rd_ptr, the top-2 bits differ while lower bits match.

**Empty detection:**
```
empty = (rd_gray == wr_gray_sync)
```
When both pointers are equal (gray-encoded), the FIFO has been drained.

---

## Author

**Gowtham Kumar Maruthi**  
M.S. ECE @ Virginia Commonwealth University (May 2026)  
📧 gowthamkumarmaruthi@gmail.com  
🔗 [LinkedIn](https://linkedin.com/in/gowthamkumar-maruthi-323020258) · [GitHub](https://github.com/gowthamaruthi)

*Seeking DV/RTL internship or new-grad roles — F-1 OPT eligible May 2026*
