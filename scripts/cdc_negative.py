#!/usr/bin/env python3
import pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
source=(ROOT/'rtl/async_fifo.sv').read_text()
mutations={
 'bypass':('wr_gray_sync <= wr_gray_q1;','wr_gray_sync <= wr_gray;','synchronizer bypass'),
 'wrong_reset':('always_ff @(posedge rd_clk or negedge rd_rst_n) begin\n    if (!rd_rst_n) begin\n      wr_gray_q1','always_ff @(posedge rd_clk or negedge wr_rst_n) begin\n    if (!wr_rst_n) begin\n      wr_gray_q1','wrong reset domain'),
 'first_stage_fanout':('assign empty = (rd_gray == wr_gray_sync);','assign empty = (rd_gray == wr_gray_q1);','stage-one fanout'),
 'binary_crossing':('wr_gray_q1   <= wr_gray;','wr_gray_q1   <= wr_bin;','input must be registered Gray pointer'),
 'missing_attribute':('(* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wr_gray_q1','logic [PTR_W-1:0] wr_gray_q1','missing ASYNC_REG'),
}
for name,(old,new,reason) in mutations.items():
 assert old in source,name
 out=ROOT/'build/cdc-negative'/name;out.mkdir(parents=True,exist_ok=True)
 rtl=out/'mutation.sv';rtl.write_text(source.replace(old,new))
 run=subprocess.run([sys.executable,str(ROOT/'scripts/cdc_audit.py'),'--rtl',str(rtl),'--out',str(out)],capture_output=True,text=True)
 log=run.stdout+run.stderr;(out/'result.log').write_text(log)
 assert run.returncode and reason in log,(name,log)
 print(f'PASS rejected {name}: {reason}')
