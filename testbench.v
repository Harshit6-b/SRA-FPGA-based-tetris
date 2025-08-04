`timescale 1ns / 1ps

module hdmi_tb();

    // Input clocks and reset
    reg pixclk;        // 40 MHz pixel clock
    reg clk_TMDS;      // 400 MHz TMDS serialization clock
    reg reset;

    // HDMI TMDS Outputs
    wire [2:0] TMDSp;
    wire [2:0] TMDSn;
    wire TMDSp_clock;
    wire TMDSn_clock;

    // Instantiate the top-level HDMI module
    hdmi_top uut (
        .pixclk(pixclk),
        .clk_TMDS(clk_TMDS),
        .reset(reset),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn),
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock)
    );

    // Generate 40 MHz pixel clock (period = 25 ns)
    initial begin
        pixclk = 0;
        forever #(12.5) pixclk = ~pixclk;
    end

    // Generate 400 MHz TMDS clock (period = 2.5 ns)
    initial begin
        clk_TMDS = 0;
        forever #(1.25) clk_TMDS = ~clk_TMDS;
    end

    // Stimulus
    initial begin
        $display("Starting HDMI simulation...");

        // Initialize reset
        reset = 1;
        #100;
        reset = 0;

        // Run simulation for some time
        #200000; // Adjust as needed to simulate enough lines/frames

        $display("Ending simulation at time=%g", $time);
        $finish;
    end

    // Optional: Monitor TMDS outputs
    initial begin
        $monitor("Time=%g | TMDSp=%b | TMDSn=%b | TMDSp_clk=%b | TMDSn_clk=%b", 
                 $time, TMDSp, TMDSn, TMDSp_clock, TMDSn_clock);
    end

    // Optional: Dump waveform (for GTKWave)
    initial begin
        $dumpfile("hdmi_tb.vcd");
        $dumpvars(0, hdmi_tb);
    end

endmodule
