`timescale 1ns / 1ps

module hdmi_top_tb;

  // Inputs
  reg clk_b = 0;
  reg rst   = 0;   

  // Outputs
  wire [2:0] TMDSp;
  wire [2:0] TMDSn;
  wire       TMDSp_clock;
  wire       TMDSn_clock;
  wire       clk_locked;
  wire       clk_fast_o;
  wire       pixclk_o;
  wire       clk_50MHz_testing;
  wire       vde_testing;
  wire [1:0] cd_testing;
//  wire [9:0] r_tmds_testing;
//  wire [9:0] g_tmds_testing;
//  wire [9:0] b_tmds_testing;
//  wire       pre_obufds_r_testing;
//  wire       serialization_testing;

  // DUT
  hdmi_top uut (
    .clk_b(clk_b),
    .rst(rst),
    .TMDSp(TMDSp),
    .TMDSn(TMDSn),
    .TMDSp_clock(TMDSp_clock),
    .TMDSn_clock(TMDSn_clock),
    .clk_locked(clk_locked),
    .clk_fast_o(clk_fast_o),
    .pixclk_o(pixclk_o),
    .clk_50MHz_testing(clk_50MHz_testing),
    .vde_testing(vde_testing),
    .cd_testing(cd_testing)
//    .r_tmds_testing(r_tmds_testing),
//    .g_tmds_testing(g_tmds_testing),
//    .b_tmds_testing(b_tmds_testing),
//    .pre_obufds_r_testing(pre_obufds_r_testing),
//    .serialization_testing(serialization_testing)
  );

  // 100 MHz clock
  always #5 clk_b = ~clk_b;

  initial begin
    $display("Starting HDMI simulation (reset permanently asserted)");
    $dumpfile("hdmi_top_tb.vcd");
    $dumpvars(0, hdmi_top_tb);

    #100_000;
    $display("Simulation finished.");
    $finish;
  end

endmodule
