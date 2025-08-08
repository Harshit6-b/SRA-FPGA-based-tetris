module hdmi_top(
    input  clk_fast,        // 10x pixel clock (e.g. 400 MHz)
    input [7:0] R_data.
    input [7:0] B_data,
    input [7:0] G_data,
    output [2:0] TMDSp,
    output [2:0] TMDSn,
    output TMDSp_clock,
    output TMDSn_clock
);
    
    wire VDE;
    wire [1:0] CD;
   
    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;

     clk_div_10x X (
        .clk_in(clk_fast),
        .clk_out(pixclk)
    );

    hdmi_loader timing_gen (
        .pixclk(pixclk),     // now passing divided pixclk (pixel clock)
        .VDE(VDE),
        .CD(CD)
    );

    TMDS_encoder encoder_R (
        .pixclk(pixclk),     // pixel clock
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

    serializer TMDS_serializer (
        .TMDS_red(TMDS_red),
        .TMDS_green(TMDS_green),
        .TMDS_blue(TMDS_blue),
        .pixclk(pixclk),
        .clk_fast(clk_fast),    // pass the original fast clock here!
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn)
    );

endmodule
