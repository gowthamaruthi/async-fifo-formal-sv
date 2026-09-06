module harness;
  (* anyseq *) reg wr_clk, rd_clk;
  (* anyseq *) reg wr_en, rd_en;
  (* anyseq *) reg [1:0] wr_data;
  reg [2:0] startup=0;
  wire rst_n = startup==3;
  always @($global_clock) begin
    if(startup<3) startup <= startup+1;
    if(startup<2) begin assume(!wr_clk); assume(!rd_clk); end
  end
  wire full,empty;
  wire [1:0] rd_data;
  async_fifo #(.DEPTH(4),.WIDTH(2)) dut(
    .wr_clk(wr_clk),.rd_clk(rd_clk),.wr_rst_n(rst_n),.rd_rst_n(rst_n),
    .wr_en(wr_en),.rd_en(rd_en),.wr_data(wr_data),.rd_data(rd_data),.full(full),.empty(empty));
endmodule
