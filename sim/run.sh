#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
seed=${SEED:-1}
for config in '4 1 3 7 0' '4 8 7 3 0' '8 17 5 5 2' '16 32 5 5 0' '32 8 3 5 1'; do
  read -r depth width wr rd phase <<< "$config"
  tag="d${depth}_w${width}_${wr}_${rd}_${phase}"
  iverilog -g2012 -Wall -s tb_async_fifo -Ptb_async_fifo.DEPTH="$depth" \
    -Ptb_async_fifo.WIDTH="$width" -Ptb_async_fifo.WR_HALF="$wr" \
    -Ptb_async_fifo.RD_HALF="$rd" -Ptb_async_fifo.RD_PHASE="$phase" \
    -o "build/$tag.vvp" rtl/async_fifo.sv tb/tb_async_fifo.sv
  if vvp "build/$tag.vvp" +SEED="$seed" | tee "build/$tag.log"; then
    :
  else
    (cd build; vvp "$tag.vvp" +SEED="$seed" +WAVES > "$tag.failure.log" 2>&1) || true
    if [[ -f build/failure.vcd ]]; then mv build/failure.vcd "build/$tag.failure.vcd"; fi
    exit 1
  fi
done
