module serializer(
input [9:0] TMDS_red,
input [9:0] TMDS_green,
input [9:0] TMDS_blue,
input pixclk, //normal clock
output [2:0] TMDSp,
output [2:0] TMDSn,
output TMDSp_clock,
output TMDSn_clock
);


wire clk_TMDS;       // 10x pixel clock output
wire clkfb;          // feedback wire for MMCM
wire clk_mmcm_out;   // unbuffered MMCM output
wire locked;         // MMCM lock indicator

// Use MMCM to multiply pixel clock by 10
MMCME2_BASE #(
	.CLKIN1_PERIOD(25.0),       // 40 MHz input clock → 25 ns period
    .CLKFBOUT_MULT_F(10.0),     // Multiply by 10
    .CLKOUT0_DIVIDE_F(1.0),     // No divide: net ×10
    .CLKOUT0_PHASE(0.0)
) mmcm_inst (
    .CLKIN1(pixclk),
    .CLKFBIN(clkfb),
    .CLKFBOUT(clkfb),
    .CLKOUT0(clk_mmcm_out),
    .LOCKED(locked),
    .PWRDWN(1'b0),
    .RST(1'b0)
);

// Global clock buffer for MMCM output
BUFG BUFG_TMDS (
    .I(clk_mmcm_out),
    .O(clk_TMDS)
);
//shifting to send 1 bit at a time
reg [3:0] TMDS_mod10 = 0;
reg TMDS_shift_load = 0;

always @(posedge clk_TMDS) begin 
	TMDS_mod10 <= (TMDS_mod10 == 9) ? 0: TMDS_mod10+1;
	TMDS_shift_load <= (TMDS_mod10 == 9);
end

reg [9:0] TMDS_shift_red = 10'b0;
reg [9:0] TMDS_shift_green = 10'b0;
reg [9:0] TMDS_shift_blue = 10'b0;

always @(posedge clk_TMDS) begin 
	if (TMDS_shift_load) begin 
		TMDS_shift_red <= TMDS_red;
		TMDS_shift_green <= TMDS_green;
		TMDS_shift_blue <= TMDS_blue;
	end
	else begin
		TMDS_shift_red <= {1'b0, TMDS_shift_red[9:1]};
		TMDS_shift_green <= {1'b0, TMDS_shift_green[9:1]};
		TMDS_shift_blue <= {1'b0, TMDS_shift_blue[9:1]};
	end
end

//positive and negative output k liye 
OBUFDS OBUFDS_red (
	.I(TMDS_shift_red[0]),
	.O(TMDSp[2]),
	.OB(TMDSn[2])
	);
	
OBUFDS OBUFDS_green (
	.I(TMDS_shift_green[0]),
	.O(TMDSp[1]),
	.OB(TMDSn[1])
	);
	
OBUFDS OBUFDS_blue (
	.I(TMDS_shift_blue[0]),
	.O(TMDSp[0]),
	.OB(TMDSn[0])
	);
	
OBUFDS OBUFDS_clock (
	.I(pixclk),
	.O(TMDSp_clock),
	.OB(TMDSn_clock)
	);

endmodule
