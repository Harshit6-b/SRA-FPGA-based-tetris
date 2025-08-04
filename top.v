module hdmi_top(
    input pixclk,
    input clk_TMDS,
    output [2:0] TMDSp,
    output [2:0] TMDSn,
    output TMDSp_clock,
    output TMDSn_clock
);

    wire VDE;
    wire [1:0] CD;

    wire [7:0] R_data, G_data, B_data;

    // Example color bars
    assign R_data = (VDE) ? 8'hFF : 8'h00;
    assign G_data = (VDE) ? 8'h00 : 8'h00;
    assign B_data = (VDE) ? 8'h00 : 8'h00;

    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;

    hdmi_loader timing_gen (
        .pixclk(pixclk),
        .VDE(VDE),
        .CD(CD)
    );

    TMDS_encoder encoder_R (
        .pixclk(pixclk),
        .clk_TMDS(clk_TMDS),
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
        .clk_TMDS(clk_TMDS),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn),
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock)
    );

endmodule

