module serializer(
  input  [9:0] TMDS_red,
  input  [9:0] TMDS_green,
  input  [9:0] TMDS_blue,      
  input        pixclk,     
  output       TMDSp_clock,
  output       TMDSn_clock,
  output [2:0] TMDSp,
  output [2:0] TMDSn
);

  reg [4:0] count = 0;
reg clk_fast = 0;
  always @(posedge pixclk) begin
    for(count=0;count<4'd20;count=count=count+1) begin
      clk_fast=~clk_fast;
    end
  end

  
// Shift counters
reg [3:0] TMDS_mod10 = 0;
reg TMDS_shift_load = 0;

  always @(posedge clk_fast) begin 
  TMDS_mod10 <= (TMDS_mod10 == 9) ? 0 : TMDS_mod10 + 1;
  TMDS_shift_load <= (TMDS_mod10 == 9);
end

// Shift registers
reg [9:0] TMDS_shift_red   = 10'b0;
reg [9:0] TMDS_shift_green = 10'b0;
reg [9:0] TMDS_shift_blue  = 10'b0;

  always @(posedge clk_fast) begin 
  if (TMDS_shift_load) begin 
    TMDS_shift_red   <= TMDS_red;
    TMDS_shift_green <= TMDS_green;
    TMDS_shift_blue  <= TMDS_blue;
  end else if (TMDS_mod10 < 10) begin
    TMDS_shift_red   <= {1'b0, TMDS_shift_red[9:1]};
    TMDS_shift_green <= {1'b0, TMDS_shift_green[9:1]};
    TMDS_shift_blue  <= {1'b0, TMDS_shift_blue[9:1]};
  end
end


// Assign outputs (non-differential)
assign TMDSp = {TMDS_shift_red[0], TMDS_shift_green[0], TMDS_shift_blue[0]};
assign TMDSn = ~TMDSp; // simple differential emulation

assign TMDSp_clock = pixclk;
assign TMDSn_clock = ~pixclk;

endmodule
