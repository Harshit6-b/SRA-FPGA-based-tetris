module hdmi_top(
    input clk_fast,        // 10x pixel clock (e.g. 400 MHz)
    output [2:0] TMDSp,
    output [2:0] TMDSn,
    output TMDSp_clock,
    output TMDSn_clock
);

    // Generate pixclk by dividing clk_fast by 10 once
    reg [3:0] count = 0;
    reg pixclk = 0;
    always @(posedge clk_fast) begin
        if(count == 9) begin
            count <= 0;
            pixclk <= ~pixclk;
        end else begin
            count <= count + 1;
        end
    end

    wire VDE;
    wire [1:0] CD;

    wire [7:0] R_data, G_data, B_data;

    assign R_data = (VDE) ? 8'hFF : 8'h00;
    assign G_data = (VDE) ? 8'h00 : 8'h00;
    assign B_data = (VDE) ? 8'h00 : 8'h00;

    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;

    hdmi_loader timing_gen (
        .clk_fast(clk_fast),     // now passing divided pixclk (pixel clock)
        .VDE(VDE),
        .CD(CD)
    );

    TMDS_encoder encoder_R (
        .clk_fast(clk_fast),     // pixel clock
        .VD(R_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_red)
    );

    TMDS_encoder encoder_G (
        .clk_fast(clk_fast),
        .VD(G_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_green)
    );

    TMDS_encoder encoder_B (
        .clk_fast(clk_fast),
        .VD(B_data),
        .CD(CD),
        .VDE(VDE),
        .TMDS(TMDS_blue)
    );

    serializer TMDS_serializer (
        .TMDS_red(TMDS_red),
        .TMDS_green(TMDS_green),
        .TMDS_blue(TMDS_blue),
        .clk_fast(clk_fast),   // pass the original fast clock here!
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn)
    );

endmodule
