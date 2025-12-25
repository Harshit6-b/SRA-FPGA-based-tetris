module hdmi_top (
    input  wire clk_b,           
    input  wire rst,
    output wire [2:0] TMDSp,
    output wire [2:0] TMDSn,
    output wire       TMDSp_clock,
    output wire       TMDSn_clock,
    output wire       clk_locked,
    output wire       clk_fast_o,
    output wire       pixclk_o,
    output wire       clk_50Mhz_testing,
    output wire       vde_testing,
    output wire [1:0] cd_testing
//    output wire [9:0] r_tmds_testing,
//    output wire [9:0] g_tmds_testing,
//    output wire [9:0] b_tmds_testing,
//    output wire       pre_obufds_r_testing
//    output wire       serialization_testing
);

    //Clocking wizard outputs
    wire clk_fast;  // 125 MHz
    wire pixclk;    // 25 MHz
    wire clk_locked_wire;
  
    wire clk_b_wire;
    assign clk_b_wire = clk_b;
  
    //Instantiate Clock Wizard
    clk_wiz_0 clk_gen_inst (
      .clk_in1(clk_b_wire),     // input
        .clk_5x(clk_fast),  // fast clock
        .clk_x(pixclk),      // pixel clock
        .reset(rst),        
        .locked(clk_locked_wire),  // status
      .clk_out3(clk_50MHz_testing)       
    );

    assign clk_locked = clk_locked_wire;
    assign clk_fast_o = clk_fast;
    assign pixclk_o = pixclk;
    
    //Video timing signals
    wire VDE;
    wire [1:0] CD;
    wire [7:0] R_data, G_data, B_data;

    assign R_data = (VDE) ? 8'h00 : 8'h00;
    assign G_data = (VDE) ? 8'hE4 : 8'h00;
    assign B_data = (VDE) ? 8'hE4 : 8'h00;

    //Encoded TMDS data
    wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
    
//  assign r_tmds_testing = TMDS_red;
//  assign g_tmds_testing = TMDS_green;
//  assign b_tmds_testing = TMDS_blue;

    //Video timing generator
    hdmi_loader timing_gen (
        .pixclk(pixclk),
        .rst(rst),
        .VDE(VDE),
        .CD(CD)
    );
    
    assign vde_testing = VDE;
    assign cd_testing = CD;

    //TMDS encoders
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
    
    reg rst_sync;
    always @(posedge pixclk) rst_sync <= ~clk_locked_wire;

    //Serializer
    serializer TMDS_serializer (
        .TMDS_red(TMDS_red),
        .TMDS_green(TMDS_green),
        .TMDS_blue(TMDS_blue),
        .pixclk(pixclk),
        .clk_5x(clk_fast),
        .rst(rst_sync),
        .TMDSp_clock(TMDSp_clock),
        .TMDSn_clock(TMDSn_clock),
        .TMDSp(TMDSp),
        .TMDSn(TMDSn)
//        .pre_obufds_r_testing(pre_obufds_r_testing)
//        .serialization_testing(serialization_testing)
    );

endmodule
