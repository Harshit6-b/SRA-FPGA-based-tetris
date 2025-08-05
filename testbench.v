`timescale 1ns / 1ps

module hdmi_top_tb;

  reg clk_fast = 0;        // 400 MHz clock 
  wire [2:0] TMDSp;
  wire [2:0] TMDSn;
  wire TMDSp_clock;
  wire TMDSn_clock;

  // Instantiate the design under test
  hdmi_top uut (
    .clk_fast(clk_fast),       // 400 MHz
    .TMDSp(TMDSp),
    .TMDSn(TMDSn),
    .TMDSp_clock(TMDSp_clock),
    .TMDSn_clock(TMDSn_clock)
  );

  // Generate 400 MHz fast clock (period 2.5 ns)
  always #12.5 pixclk = ~pixclk;

  initial begin
    $display("Starting HDMI simulation...");
    $dumpfile("hdmi_top_tb.vcd");
    $dumpvars(0, hdmi_top_tb);

    #10000; // Run simulation for 10 us

    $display("Simulation finished.");
    $finish;
  end

endmodule
