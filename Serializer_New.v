module serializer (
    input  wire        pixclk,       // pixel clock
    input  wire        clk_5x,       // 5x pixel clock
    input  wire [9:0]  TMDS_red,
    input  wire [9:0]  TMDS_green,
    input  wire [9:0]  TMDS_blue,
    output wire        TMDSp_clock,
    output wire        TMDSn_clock,
    output wire [2:0]  TMDSp,
    output wire [2:0]  TMDSn
);

    // Serialize TMDS data channels 
    wire tmds_red_s, tmds_green_s, tmds_blue_s;

    oserdes_10to1 ser_red (
        .clk(pixclk),
        .clk_5x(clk_5x),
        .data(TMDS_red),
        .out(tmds_red_s)
    );

    oserdes_10to1 ser_green (
        .clk(pixclk),
        .clk_5x(clk_5x),
        .data(TMDS_green),
        .out(tmds_green_s)
    );

    oserdes_10to1 ser_blue (
        .clk(pixclk),
        .clk_5x(clk_5x),
        .data(TMDS_blue),
        .out(tmds_blue_s)
    );

    // Serialize TMDS clock channel 
    // HDMI clock channel is simply 1111100000 pattern serialized
    wire tmds_clk_s;
    oserdes_10to1 ser_clk (
        .clk(pixclk),
        .clk_5x(clk_5x),
        .data(10'b1111100000),
        .out(tmds_clk_s)
    );

    // Differential outputs
    OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_clk (
        .I(tmds_clk_s), .O(TMDSp_clock), .OB(TMDSn_clock)
    );
    OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_red (
        .I(tmds_red_s), .O(TMDSp[2]),    .OB(TMDSn[2])
    );
    OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_green (
        .I(tmds_green_s), .O(TMDSp[1]),  .OB(TMDSn[1])
    );
    OBUFDS #(.IOSTANDARD("TMDS_33")) obufds_blue (
        .I(tmds_blue_s), .O(TMDSp[0]),   .OB(TMDSn[0])
    );

endmodule


// OSERDESE2 wrapper: 10:1 DDR

module oserdes_10to1 (
    input  wire        clk,      // pixel clock
    input  wire        clk_5x,   // 5x pixel clock
    input  wire [9:0]  data,     // TMDS 10-bit word
    output wire        out
);
    // Master/Slave OSERDESE2 arrangement for 10:1 serialization
    wire shift1, shift2;

    OSERDESE2 #(
        .DATA_WIDTH(10),
        .TRISTATE_WIDTH(1),
        .DATA_RATE_OQ("DDR")
    ) oserdes_master (
        .OQ(out),
        .OCE(1'b1),
        .CLK(clk_5x),
        .CLKDIV(clk),
        .D1(data[0]), .D2(data[1]),
        .D3(data[2]), .D4(data[3]),
        .D5(data[4]), .D6(data[5]),
        .D7(data[6]), .D8(data[7]),
        .T1(1'b0),
        .SHIFTIN1(shift1), .SHIFTIN2(shift2),
        .SHIFTIN3(1'b0),   .SHIFTIN4(1'b0),
        .SHIFTOUT1(), .SHIFTOUT2(), .SHIFTOUT3(), .SHIFTOUT4(),
        .RST(1'b0)
    );

    OSERDESE2 #(
        .DATA_WIDTH(10),
        .TRISTATE_WIDTH(1),
        .DATA_RATE_OQ("DDR")
    ) oserdes_slave (
        .OQ(),
        .OCE(1'b1),
        .CLK(clk_5x),
        .CLKDIV(clk),
        .D1(data[8]), .D2(data[9]),
        .D3(1'b0),    .D4(1'b0),
        .D5(1'b0),    .D6(1'b0),
        .D7(1'b0),    .D8(1'b0),
        .T1(1'b0),
        .SHIFTIN1(1'b0), .SHIFTIN2(1'b0),
        .SHIFTIN3(1'b0), .SHIFTIN4(1'b0),
        .SHIFTOUT1(shift1), .SHIFTOUT2(shift2),
        .SHIFTOUT3(), .SHIFTOUT4(),
        .RST(1'b0)
    );

endmodule
