`timescale 1ns / 1ps

module hdmi_tb();

    // Inputs to the top module
    reg pixclk;
    reg reset;

    // Outputs from the top module
    wire [2:0] TMDSp;
    wire [2:0] TMDSn;
    wire TMDSp_clock;
    wire TMDSn_clock;

    // Instantiate the top-level HDMI module
    hdmi_top uut (
        .pixclk(pixclk),
        .reset(reset),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn),
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock)
    );

    // Clock generation: 40 MHz clock 
    initial begin
        pixclk = 0;
        forever #(12.5) pixclk = ~pixclk; // Toggle every 12.5 ns
    end

    // Stimulus block
    initial begin
        $display("Starting HDMI simulation...");

        // Initialize reset
        reset = 1;
        #100;
        reset = 0;

        // Wait and finish (removed vcount-based wait)
        #100000; // You can adjust the delay as needed

        $display("Ending simulation at time=%g", $time);
        $finish;
    end

    // Optional: Monitor TMDS outputs (good for debugging)
    initial begin
        $monitor("Time=%g | TMDSp=%b | TMDSn=%b | TMDSp_clock=%b | TMDSn_clock=%b", 
                  $time, TMDSp, TMDSn, TMDSp_clock, TMDSn_clock);
    end

endmodule
