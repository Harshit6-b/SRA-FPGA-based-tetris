`timescale 1ns / 1ps

module hdmi_top_tb;

  reg pixclk = 0;
  reg clk_TMDS = 0;
  wire [2:0] TMDSp;
  wire [2:0] TMDSn;
  wire TMDSp_clock;
  wire TMDSn_clock;

  // Instantiate the design under test
  hdmi_top uut (
    .pixclk(pixclk),
    .clk_TMDS(clk_TMDS),
    .TMDSp(TMDSp),
    .TMDSn(TMDSn),
    .TMDSp_clock(TMDSp_clock),
    .TMDSn_clock(TMDSn_clock)
  );

  // Generate 40 MHz pixel clock
  always #12.5 pixclk = ~pixclk; // 25 ns period (40 MHz)

  // Generate 400 MHz TMDS clock
  always #1.25 clk_TMDS = ~clk_TMDS; // 2.5 ns period (400 MHz)

  initial begin
    $display("Starting HDMI simulation...");
    $dumpfile("hdmi_top_tb.vcd");  // For GTKWave or other waveform viewers
    $dumpvars(0, hdmi_top_tb);

    #10000; // Run simulation for 10 µs

    $display("Simulation finished.");
    $finish;
  end

endmodule
