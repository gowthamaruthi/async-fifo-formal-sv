# Structural crossing and reset audit

I use `scripts/cdc_audit.py` to inspect the elaborated Yosys JSON netlist. It checks the two registered Gray-pointer crossings, destination clock/reset connections, two-stage wiring, zero reset values, `ASYNC_REG` attributes and exclusive first-stage fanout. It also traces register D-pin combinational dependencies to flag unexpected register-to-register clock or reset-domain crossings.

```sh
python3 scripts/cdc_audit.py
python3 scripts/cdc_audit.py --depth 4 --width 1 --out build/cdc-minimum
python3 scripts/cdc_negative.py
```

Default (16,8) and minimum (4,1) configurations pass with Yosys 0.66. Five isolated RTL mutations fail: bypassed second stage, wrong destination reset, first-stage fanout, binary pointer crossing and missing implementation attribute. The checker preserves synchronizer net names during elaboration so optimization cannot hide unused/bypassed stages. Reports and elaboration logs are written to the selected output directory; [recorded reports](results/cdc/) show the checked configurations.

## Crossing inventory and integration obligations

| Crossing | Structure | Required checks outside this script |
|---|---|---|
| `wr_gray` into `rd_clk` | Two destination-clock registers | Gray bus delay/skew, synchronizer placement and metastability MTBF |
| `rd_gray` into `wr_clk` | Two destination-clock registers | Same requirements in the other direction |
| Shared memory data | Write-clock storage, combinational read | FIFO ordering/occupancy verification and technology-specific memory behavior |
| External resets | Active-low asynchronous assertion | Coordinated flush and synchronous release in each clock domain |

The shared-memory data path is explicitly excluded from the register-crossing graph; existing simulation and bounded formal checks cover its protocol behavior. Input ports and physical delays are not analyzed. Same-clock registers with different resets are flagged, but this is not a complete reset-domain-crossing analysis: it cannot establish recovery/removal timing, safe reset release, analog behavior or all reconvergence hazards.

This is a project-specific structural audit built on Yosys, not experience with a commercial CDC/RDC signoff product. The documented coordinated-reset contract still applies; independent resets are unsupported. No DUT behavior changes are introduced by this audit.
