module hdmi_top(
    input  wire clk_b,           
    output wire [2:0] TMDSp,
    output wire [2:0] TMDSn,
    output wire       TMDSp_clock,
    output wire       TMDSn_clock,
    output wire       clk_v
);

    // Pass board clock to output for testing
    assign clk_v = clk_b;

    // Clocking wizard outputs
    wire clk_fast;  // 10x pixel clock (~250 MHz)
    wire pixclk;    // Pixel clock (~25 MHz)
    wire clk_locked;

    // Instantiate Clock Wizard
    clk_wiz_0 clk_gen_inst (
        .clk_in1(clk_b),     // input
        .clk_10x(clk_fast),  // fast clock
        .clk_x(pixclk),      // pixel clock
        .reset(1'b0),        // no reset for now
        .locked(clk_locked)  // status
    );

    // Video timing signals
    wire VDE;
    wire [1:0] CD;
    wire [7:0] R_data, G_data, B_data;

    assign R_data = (VDE) ? 8'hFF : 8'h00;
    assign G_data = (VDE) ? 8'hFF : 8'h00;
    assign B_data = (VDE) ? 8'h00 : 8'h00;

    // Encoded TMDS data
    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;

    // Video timing generator
    hdmi_loader timing_gen (
        .pixclk(pixclk),
        .VDE(VDE),
        .CD(CD)
    );

    // TMDS encoders
    TMDS_encoder encoder_R (
        .pixclk(pixclk),
        .VD(R_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_red)
    );

    TMDS_encoder encoder_G (
        .pixclk(pixclk),
        .VD(G_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_green)
    );

    TMDS_encoder encoder_B (
        .pixclk(pixclk),
        .VD(B_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_blue)
    );

    // Serializer for TMDS signals
    serializer TMDS_serializer (
        .TMDS_red(TMDS_red),
        .TMDS_green(TMDS_green),
        .TMDS_blue(TMDS_blue),
        .pixclk(pixclk),
        .clk_fast(clk_fast),
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn)
    );

endmodule
