`timescale 1ns/1ps
module tb_async_fifo;
  parameter integer DEPTH=4, WIDTH=8, WR_HALF=5, RD_HALF=7, RD_PHASE=0;
  reg wr_clk=0, rd_clk=0, wr_rst_n=0, rd_rst_n=0, wr_en=0, rd_en=0;
  reg [WIDTH-1:0] wr_data=0;
  wire [WIDTH-1:0] rd_data;
  wire full, empty;
  reg pause_wr=0, pause_rd=0;
  integer wm=0, rm=0, nw=0, nr=0, discarded=0, rejected_w=0, rejected_r=0;
  integer seed=1, ws, rs, dummy;
  reg [WIDTH-1:0] expected[0:65535];
  async_fifo #(.DEPTH(DEPTH),.WIDTH(WIDTH)) dut(.*);
  always begin #(WR_HALF); if (!pause_wr) wr_clk=~wr_clk; end
  initial begin #(RD_PHASE); forever begin #(RD_HALF); if (!pause_rd) rd_clk=~rd_clk; end end
  function automatic integer next_random(input integer x);
    integer y;
    begin y=x^(x<<13); y=y^(y>>17); next_random=y^(y<<5); end
  endfunction
  always @(negedge wr_clk) begin
    ws=next_random(ws); wr_en=wr_rst_n && ((wm==1) || (wm==2 && (ws & 7)<5));
    wr_data=WIDTH'(ws);
  end
  always @(negedge rd_clk) begin
    rs=next_random(rs); rd_en=rd_rst_n && ((rm==1) || (rm==2 && (rs & 7)<5));
  end
  // Independent monotonic indices: no shared queue mutation at coincident edges.
  // An empty FIFO cannot accept a read of a write from the same simulation tick.
  always @(posedge wr_clk) if (wr_rst_n && wr_en) begin
    if (!full) begin
      if(nw>=65536) $fatal(1,"scoreboard capacity");
      expected[nw]=wr_data; nw=nw+1;
    end else rejected_w=rejected_w+1;
  end
  always @(posedge rd_clk) if (rd_rst_n && rd_en) begin
    if (!empty) begin
      if(nr>=nw) $fatal(1,"unexpected read");
      if(rd_data !== expected[nr]) $fatal(1,"order/data mismatch index=%0d got=%h expected=%h",nr,rd_data,expected[nr]);
      nr=nr+1;
    end else rejected_r=rejected_r+1;
  end
  task automatic run_cycles(input integer n);
    repeat(n) @(negedge wr_clk);
  endtask
  task automatic drain;
    begin
      wm=0; @(negedge wr_clk); #1; rm=1;
      wait(nr==nw); repeat(5) @(negedge rd_clk); #1;
      if(!empty || nr!=nw) $fatal(1,"incomplete drain");
      rm=0; @(negedge rd_clk); #1;
    end
  endtask
  task automatic reset_both(input bit discard_pending);
    reg [WIDTH-1:0] reset_word;
    begin
      wm=0; rm=0;
      @(negedge wr_clk); #1; wr_rst_n=0; rd_rst_n=0;
      if(!discard_pending && nr!=nw) $fatal(1,"reset would hide missing data");
      // Explicit reset discard is accounted, never reported as a consumed transfer.
      discarded=discarded+(nw-nr); nr=nw;
      reset_word=dut.mem[0]; force wr_en=1; force wr_data='1;
      repeat(4) @(negedge wr_clk); repeat(4) @(negedge rd_clk);
      #1; if(dut.mem[0] !== reset_word) $fatal(1,"memory changed during reset");
      release wr_en; release wr_data; wr_en=0;
      wr_rst_n=1; rd_rst_n=1;
      repeat(4) @(negedge wr_clk); repeat(4) @(negedge rd_clk); #1;
      if(!empty || full) $fatal(1,"reset flags");
    end
  endtask
  initial begin
    dummy=$value$plusargs("SEED=%d",seed); ws=seed|1; rs=seed^32'h13579bdf;
    $display("SEED=%0d DEPTH=%0d WIDTH=%0d WR_HALF=%0d RD_HALF=%0d PHASE=%0d",seed,DEPTH,WIDTH,WR_HALF,RD_HALF,RD_PHASE);
    if($test$plusargs("WAVES")) begin $dumpfile("failure.vcd"); $dumpvars(0,tb_async_fifo); end
    reset_both(0);
    wm=1; run_cycles(DEPTH+10); #1; if(!full) $fatal(1,"full not reached");
    drain(); // also exercises rejected full and empty requests
    wm=2; rm=2; run_cycles(1000); drain();
    wm=1; rm=1; run_cycles(200);
    @(negedge rd_clk); #1; pause_rd=1; run_cycles(DEPTH+12); pause_rd=0;
    run_cycles(100);
    @(negedge wr_clk); #1; pause_wr=1; repeat(DEPTH+12) @(negedge rd_clk); pause_wr=0;
    run_cycles(100); drain();
    reset_both(0);
    wm=1; run_cycles(DEPTH+8); reset_both(1);
    wm=2; rm=2; run_cycles(500); drain();
    if(nw<DEPTH*10 || rejected_w==0 || rejected_r==0) $fatal(1,"insufficient stimulus");
    $display("PASS accepted_writes=%0d consumed=%0d reset_discarded=%0d rejected_writes=%0d rejected_reads=%0d",nw,nr-discarded,discarded,rejected_w,rejected_r);
    $finish;
  end
  initial begin #1000000; $fatal(1,"watchdog timeout"); end
endmodule
