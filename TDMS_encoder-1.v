module TMDS_encoder (
    input clk_fast,
    input [7:0] VD,       // Video Data
    input [1:0] CD,       // Control Data (hsync, vsync)
    input  VDE,            // Video Data Enable
    output reg [9:0] TMDS // Output TMDS encoded signal
);
	reg [3:0] count = 0;
reg pixclk= 0;

always @(posedge clk_fast) begin
    if(count == 9) begin
        count <= 0;
        pixclk <= ~pixclk;  // divide by 10
    end else
        count <= count + 1;
end


    reg [8:0] iTDMS;                  // Intermediate TMDS encoding
    reg signed [4:0] disparity = 0;   // Running disparity

    reg [3:0] ones_count;
    reg use_XNOR;
    integer i;

    always @(*) begin
        // Count number of 1s in VD
        ones_count = 0;
	if (VD[0]) ones_count = ones_count + 1;
	if (VD[1]) ones_count = ones_count + 1;
	if (VD[2]) ones_count = ones_count + 1;
	if (VD[3]) ones_count = ones_count + 1;
	if (VD[4]) ones_count = ones_count + 1;
	if (VD[5]) ones_count = ones_count + 1;
	if (VD[6]) ones_count = ones_count + 1;
	if (VD[7]) ones_count = ones_count + 1;

        // Decide XOR or XNOR
        if ((ones_count > 4) || (ones_count == 4 && VD[0] == 0))
            use_XNOR = 1;
        else
            use_XNOR = 0;

        // Build 9-bit intermediate TMDS
        iTDMS[0] = VD[0];
        iTDMS[1] = use_XNOR ? ~(iTDMS[0] ^ VD[1]) : (iTDMS[0] ^ VD[1]);
	iTDMS[2] = use_XNOR ? ~(iTDMS[1] ^ VD[2]) : (iTDMS[1] ^ VD[2]);
	iTDMS[3] = use_XNOR ? ~(iTDMS[2] ^ VD[3]) : (iTDMS[2] ^ VD[3]);
	iTDMS[4] = use_XNOR ? ~(iTDMS[3] ^ VD[4]) : (iTDMS[3] ^ VD[4]);
	iTDMS[5] = use_XNOR ? ~(iTDMS[4] ^ VD[5]) : (iTDMS[4] ^ VD[5]);
	iTDMS[6] = use_XNOR ? ~(iTDMS[5] ^ VD[6]) : (iTDMS[5] ^ VD[6]);
	iTDMS[7] = use_XNOR ? ~(iTDMS[6] ^ VD[7]) : (iTDMS[6] ^ VD[7]);
        iTDMS[8] = ~use_XNOR; // Ninth bit is inverse of use_XNOR
    end
           reg [3:0] ones;
	   reg [3:0] zeros;


    // Final TMDS output based on disparity and control
    always @(posedge pixclk) begin
        if (VDE) begin
		ones<=0;
	ones <= ones + (iTDMS[0] ? 1 : 0);
	ones <= ones + (iTDMS[1] ? 1 : 0);
	ones <= ones + (iTDMS[2] ? 1 : 0);
	ones <= ones + (iTDMS[3] ? 1 : 0);
	ones <= ones + (iTDMS[4] ? 1 : 0);
	ones <= ones + (iTDMS[5] ? 1 : 0);
	ones <= ones + (iTDMS[6] ? 1 : 0);
	ones <= ones + (iTDMS[7] ? 1 : 0);


            zeros <= 8 - ones;

            // Update TMDS output based on running disparity
		if((disparity==0 || ones==4)) begin
			if(iTDMS[8]) begin
				TMDS[9]<=0;
				TMDS[8]<=1;
				TMDS[7:0]<=iTDMS[7:0];
				disparity <= disparity + ones - zeros;
			end
			else begin
				TMDS[9]<=1;
				TMDS[8]<=0;
				TMDS[7:0]<=~iTDMS[7:0];
				disparity <= disparity - ones + zeros;
		        end
		end
		else begin 
			if ((disparity>0 && ones>4) || (disparity < 0 && ones<4)) begin
				if (iTDMS[8]==0) begin
					TMDS[9]<=1;
					TMDS[8]<=0;
					TMDS[7:0]<=~iTDMS[7:0];
					disparity <= disparity - ones + zeros;
				end
				else begin
					TMDS[9]<=1;
					TMDS[8]<=1;
					TMDS[7:0]<=~iTDMS[7:0];
					disparity <= disparity - ones + zeros + 2;
				end
			end
			else begin
				if (iTDMS[8]==0) begin
					TMDS[9]<=0;
					TMDS[8]<=0;
					TMDS[7:0]<=iTDMS[7:0];
					disparity <= disparity - ones + zeros- 2;
				end
				else begin 
					TMDS[9]<=0;
					TMDS[8]<=1;
					TMDS[7:0]<=iTDMS[7:0];
					disparity <= disparity + ones - zeros;
				end
			end
		end
        end
        else begin
            // Control Period Encoding
            case (CD)
                2'b00: TMDS = 10'b1101010100;
                2'b01: TMDS = 10'b0010101011;
                2'b10: TMDS = 10'b0101010100;
                2'b11: TMDS = 10'b1010101011;
            endcase
            disparity = 0;
        end
    end

endmodule

