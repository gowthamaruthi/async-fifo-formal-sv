// =============================================================================
// Module  : tb_async_fifo
// Author  : Gowtham Kumar Maruthi
// Desc    : Self-checking testbench for async_fifo.
//           Two independent clocks at different frequencies.
//           Scoreboard tracks every write/read for data integrity.
//           Tests: burst, full flag, empty flag, interleaved.
// =============================================================================

`timescale 1ns / 1ps

module tb_async_fifo;

  // ──── Parameters ────────────────────────────────────────────────────────
  localparam int DEPTH   = 16;
  localparam int WIDTH   = 8;
  localparam int ADDR_W  = $clog2(DEPTH);

  localparam real WR_PER = 10.0;   // 100 MHz  write clock
  localparam real RD_PER = 13.0;   //  ~77 MHz  read clock (intentionally different)

  // ──── DUT Signals ───────────────────────────────────────────────────────
  logic             wr_clk, wr_rst_n, wr_en;
  logic [WIDTH-1:0] wr_data;
  logic             full;

  logic             rd_clk, rd_rst_n, rd_en;
  logic [WIDTH-1:0] rd_data;
  logic             empty;

  // ──── DUT ───────────────────────────────────────────────────────────────
  async_fifo #(.DEPTH(DEPTH), .WIDTH(WIDTH)) dut (.*);

  // ──── Clock Generation ──────────────────────────────────────────────────
  initial wr_clk = 1'b0;
  always  #(WR_PER/2) wr_clk = ~wr_clk;

  initial rd_clk = 1'b0;
  always  #(RD_PER/2) rd_clk = ~rd_clk;

  // ──── VCD Dump (for GTKWave) ────────────────────────────────────────────
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_async_fifo);
  end

  // ──── Scoreboard ────────────────────────────────────────────────────────
  int pass_cnt = 0;
  int fail_cnt = 0;
  logic [WIDTH-1:0] exp_q [$];   // expected-data queue (write pushes, read pops)

  // Runtime monitors: catch assertion violations from RTL
  always @(posedge wr_clk)
    if (wr_rst_n && wr_en && full) begin
      $error("[TB MONITOR] OVERFLOW detected at %0t ns!", $time);
      fail_cnt++;
    end

  always @(posedge rd_clk)
    if (rd_rst_n && rd_en && empty) begin
      $error("[TB MONITOR] UNDERFLOW detected at %0t ns!", $time);
      fail_cnt++;
    end

  // ──── Tasks ─────────────────────────────────────────────────────────────

  // Reset both domains
  task automatic apply_reset();
    wr_rst_n = 1'b0;  rd_rst_n = 1'b0;
    wr_en    = 1'b0;  rd_en    = 1'b0;
    wr_data  = '0;
    exp_q    = {};
    repeat (6) @(posedge wr_clk);
    repeat (6) @(posedge rd_clk);
    @(negedge wr_clk); wr_rst_n = 1'b1;
    @(negedge rd_clk); rd_rst_n = 1'b1;
    repeat (2) @(posedge wr_clk);
    $display("[RESET] Released — empty=%0b full=%0b", empty, full);
  endtask

  // Write one item (no-op if full)
  task automatic do_write(input logic [WIDTH-1:0] data);
    @(negedge wr_clk);
    if (full) begin
      $display("[WR] SKIP 0x%02h — FIFO full", data);
    end else begin
      wr_en   = 1'b1;
      wr_data = data;
      exp_q.push_back(data);            // record for scoreboard
      @(posedge wr_clk); #1;
      wr_en = 1'b0;
    end
  endtask

  // Read one item and compare against expected (no-op if empty)
  task automatic do_read();
    logic [WIDTH-1:0] got;
    logic [WIDTH-1:0] expected;
    @(negedge rd_clk);
    if (empty) begin
      $display("[RD] SKIP — FIFO empty");
    end else begin
      got      = rd_data;             // comb output valid NOW (before rd_en)
      expected = exp_q.pop_front();
      rd_en = 1'b1;
      @(posedge rd_clk); #1;   // pointer advances
      rd_en = 1'b0;
      // Scoreboard compare
      if (got === expected) begin
        pass_cnt++;
        $display("[RD] PASS  got=0x%02h  exp=0x%02h", got, expected);
      end else begin
        fail_cnt++;
        $display("[RD] FAIL  got=0x%02h  exp=0x%02h  *** MISMATCH ***", got, expected);
      end
    end
  endtask

  // ──── Test Sequence ─────────────────────────────────────────────────────
  initial begin
    $display("\n============================================================");
    $display("  ASYNC FIFO — SELF-CHECKING TESTBENCH");
    $display("  DEPTH=%0d  WIDTH=%0d  WR=%.0f MHz  RD=%.0f MHz",
             DEPTH, WIDTH, 1000.0/WR_PER, 1000.0/RD_PER);
    $display("============================================================\n");

    apply_reset();

    // ── TEST 1: Burst write then burst read ────────────────────────────
    $display("── TEST 1: Write 8 items, then read 8 items ──────────────");
    for (int i = 0; i < 8; i++) do_write(8'hA0 + i[7:0]);
    // Allow a few wr_clk → rd_clk sync cycles before reading
    repeat(4) @(posedge rd_clk);
    for (int i = 0; i < 8; i++) do_read();

    // ── TEST 2: Fill FIFO to full ──────────────────────────────────────
    $display("\n── TEST 2: Fill FIFO → verify full flag ──────────────────");
    // Drain first
    repeat(4) @(posedge rd_clk);
    while (!empty) do_read();
    exp_q = {};
    repeat(6) @(posedge wr_clk);

    for (int i = 0; i < DEPTH; i++) do_write(8'h10 + i[7:0]);
    repeat(6) @(posedge wr_clk);   // flags settle after CDC sync

    if (full) begin
      pass_cnt++;
      $display("[TEST 2] PASS: full=1 correctly after %0d writes", DEPTH);
    end else begin
      fail_cnt++;
      $display("[TEST 2] FAIL: full not asserted *** ERROR ***");
    end

    // ── TEST 3: Drain FIFO to empty ────────────────────────────────────
    $display("\n── TEST 3: Drain FIFO → verify empty flag ────────────────");
    repeat(4) @(posedge rd_clk);
    for (int i = 0; i < DEPTH; i++) do_read();
    exp_q = {};
    repeat(6) @(posedge rd_clk);   // empty flag settles

    if (empty) begin
      pass_cnt++;
      $display("[TEST 3] PASS: empty=1 correctly after draining %0d items", DEPTH);
    end else begin
      fail_cnt++;
      $display("[TEST 3] FAIL: empty not asserted *** ERROR ***");
    end

    // ── TEST 4: Interleaved write/read (different clock rates) ─────────
    $display("\n── TEST 4: Interleaved writes/reads (async clocks) ───────");
    begin : test4
      integer wr_total;
      integer rd_total;
      reg [WIDTH-1:0] d;
      wr_total = 0; rd_total = 0;

      repeat(4) @(posedge wr_clk);

      for (int i = 0; i < 40; i++) begin
        // Write side: write every 2–3 wr_clk cycles
        repeat($urandom_range(2, 3)) @(posedge wr_clk);
        if (!full) begin
          d = $urandom_range(0, 255);
          do_write(d);
          wr_total++;
        end
        // Read side: read every 3–5 rd_clk cycles
        repeat($urandom_range(3, 5)) @(posedge rd_clk);
        if (!empty) begin
          do_read();
          rd_total++;
        end
      end

      // Drain anything remaining
      repeat(6) @(posedge rd_clk);
      while (!empty) do_read();
      exp_q = {};

      $display("[TEST 4] Wrote %0d items, read %0d items", wr_total, rd_total);
    end

    // ── Final Report ─────────────────────────────────────────────────────
    repeat(4) @(posedge wr_clk);
    $display("\n============================================================");
    $display("  RESULTS  |  PASS: %0d  |  FAIL: %0d", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("  STATUS   :  ALL TESTS PASSED ✓");
    else
      $display("  STATUS   :  %0d FAILURE(S) DETECTED ✗", fail_cnt);
    $display("============================================================\n");

    $finish;
  end

  // ── Watchdog ─────────────────────────────────────────────────────────────
  initial begin
    #500_000;
    $display("[TIMEOUT] Simulation exceeded limit — check for deadlock");
    $finish;
  end

endmodule
