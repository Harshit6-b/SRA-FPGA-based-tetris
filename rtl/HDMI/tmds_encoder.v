module TMDS_encoder (
    input  wire        pixclk,
    input  wire [7:0]  VD,     // Video data
    input  wire [1:0]  CD,     // Control data (hsync, vsync) - used on B channel only
    input  wire        VDE,    // Video Data Enable
    output reg  [9:0]  TMDS
);

    //Stage 1: XOR / XNOR encoding
    reg [8:0] q_m;
    integer i;
    wire [3:0] ones_cnt =
        VD[0]+VD[1]+VD[2]+VD[3]+VD[4]+VD[5]+VD[6]+VD[7];

    wire use_xnor = (ones_cnt > 4) || ((ones_cnt == 4) && (VD[0] == 1'b0));

    always @* begin
        q_m[0] = VD[0];
        for (i = 1; i < 8; i = i + 1)
            q_m[i] = use_xnor ? (q_m[i-1] ~^ VD[i])
                              : (q_m[i-1]  ^ VD[i]);
        q_m[8] = ~use_xnor;
    end

    //Stage 2: Running disparity
    wire signed [4:0] balance =
        (q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7]) - 4'sd4;

    reg signed [5:0] disparity = 0;

    always @(posedge pixclk) begin
        if (!VDE) begin
            //Control symbols
            case (CD)
                2'b00: TMDS <= 10'b1101010100;
                2'b01: TMDS <= 10'b0010101011;
                2'b10: TMDS <= 10'b0101010100;
                2'b11: TMDS <= 10'b1010101011;
            endcase
            disparity <= 0;
        end else begin
            //Video symbols
            if ((disparity == 0) || (balance == 0)) begin
                if (q_m[8]) begin
                    TMDS      <= {2'b01, q_m[7:0]};
                    disparity <= disparity + balance;
                end else begin
                    TMDS      <= {2'b10, ~q_m[7:0]};
                    disparity <= disparity - balance;
                end
            end else if ((disparity > 0 && balance > 0) ||
                         (disparity < 0 && balance < 0)) begin
                TMDS      <= {1'b1, q_m[8], ~q_m[7:0]};
                disparity <= disparity - balance;
            end else begin
                TMDS      <= {1'b0, q_m[8],  q_m[7:0]};
                disparity <= disparity + balance;
            end
        end
    end

endmodule
