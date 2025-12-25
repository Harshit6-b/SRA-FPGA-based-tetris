module oserdes_10to1 (
    input  wire clk,        // pixel clock
    input  wire clk_5x,      // 5x pixel clock
    input  wire rst,         // synchronous reset
    input  wire [9:0] data,  // TMDS word (bit9 = MSB)
    output wire out
);

wire shift1, shift2;

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .SERDES_MODE("MASTER"),
    .TRISTATE_WIDTH(1)
) oserdes_master (
    .OQ(out),
    .OCE(1'b1),
    .CLK(clk_5x),
    .CLKDIV(clk),

    .D1(data[9]),
    .D2(data[8]),
    .D3(data[7]),
    .D4(data[6]),
    .D5(data[5]),
    .D6(data[4]),
    .D7(data[3]),
    .D8(data[2]),

    .SHIFTIN1(shift1),
    .SHIFTIN2(shift2),

    .T1(1'b0),
    .TCE(1'b0),
    .RST(rst)
);

OSERDESE2 #(
    .DATA_RATE_OQ("DDR"),
    .DATA_WIDTH(10),
    .SERDES_MODE("SLAVE"),
    .TRISTATE_WIDTH(1)
) oserdes_slave (
    .OQ(),
    .OCE(1'b1),
    .CLK(clk_5x),
    .CLKDIV(clk),

    .D1(1'b0),
    .D2(1'b0),
    .D3(data[1]),
    .D4(data[0]),
    .D5(1'b0),
    .D6(1'b0),
    .D7(1'b0),
    .D8(1'b0),

    .SHIFTOUT1(shift1),
    .SHIFTOUT2(shift2),

    .T1(1'b0),
    .TCE(1'b0),
    .RST(rst)
);

endmodule


module serializer (
    input  wire        pixclk,       // pixel clock
    input  wire        clk_5x,       // 5x pixel clock
    input  wire [9:0]  TMDS_red,
    input  wire [9:0]  TMDS_green,
    input  wire [9:0]  TMDS_blue,
    input  wire        rst,
    output wire        TMDSp_clock,
    output wire        TMDSn_clock,
    output wire [2:0]  TMDSp,
    output wire [2:0]  TMDSn
//    output wire        pre_obufds_r_testing
//    output wire        serialization_testing
);

//    oserdes_10to1 serialization_testing_module (
//        .clk(pixclk),
//        .rst(rst),
//        .clk_5x(clk_5x),
//        .data(10'b1111111110),
//        .out(serialization_testing)
//    );
    
    //Serialize TMDS data channels 
    wire tmds_red_s, tmds_green_s, tmds_blue_s;
  
//    assign pre_obufds_r_testing = tmds_red_s;

    oserdes_10to1 ser_red (
        .clk(pixclk),
        .rst(rst),
        .clk_5x(clk_5x),
        .data(TMDS_red),
        .out(tmds_red_s)
    );

    oserdes_10to1 ser_green (
        .clk(pixclk),
        .rst(rst),
        .clk_5x(clk_5x),
        .data(TMDS_green),
        .out(tmds_green_s)
    );

    oserdes_10to1 ser_blue (
        .clk(pixclk),
        .rst(rst),
        .clk_5x(clk_5x),
        .data(TMDS_blue),
        .out(tmds_blue_s)
    );

    //Serialize TMDS clock channel 
    wire tmds_clk_s;
    oserdes_10to1 ser_clk (
        .clk(pixclk),
        .rst(rst),
        .clk_5x(clk_5x),
        .data(10'b1111100000),
        .out(tmds_clk_s)
    );

    //Differential outputs
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
