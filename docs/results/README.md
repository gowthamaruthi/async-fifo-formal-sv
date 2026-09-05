# Local verification evidence

Run 2026-09-05 on arm64 macOS. Base: dd4c16e66a4854fe7466773e999d973c6b8a9c19. These logs apply to the source fingerprints below; use the commit containing this report to reproduce. Formal local run used the documented SBY_PYTHON/SBY_SOURCE overrides.

```text
24a25b925cc376c68e2d5f6dadd88d516f79e6eb1cc65a834e72b291de603e09  rtl/async_fifo.sv
28670a89e7be93fb1c806def8019917635d5de2f5d6f7a1e0c0f102cc75869ab  tb/tb_async_fifo.sv
9170076be0d2628e369df32f7464d478ee7aa149994fa03cd0b5787c96f59dd8  formal/harness.sv
44f3b0b7cb1c5011d6c0358e8d8ec56914bfc828ae610e45712943637da841eb  formal/properties.svh
923651bcdc286ee0c906bd4ce6bc238805a4fa1568518d6eeb8c48a97a386519  formal/fifo.sby
```

See check.log, seed-20260905.log, parameters.log, negative.log, formal.log, and formal-negative.log. The formal negative log intentionally contains FAIL; its driver requires that counterexample.
