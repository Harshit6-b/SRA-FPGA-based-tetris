module TMDS_encoder (
    input  wire        pixclk,
    input  wire [7:0]  VD,         // Video Data
    input  wire [1:0]  CD,         // Control Data (hsync, vsync) use on BLUE channel only
    input  wire        VDE,        // Video Data Enable
    output reg  [9:0]  TMDS        // TMDS encoded output
);

    // q_m (combinational) 
    reg [8:0] q_m;                  // iTDMS in your code
    reg [3:0] ones_count;
    reg       use_XNOR;

    integer i;
    always @* begin
        ones_count = 0;
        for (i = 0; i < 8; i = i + 1)
            ones_count = ones_count + VD[i];

        use_XNOR = (ones_count > 4) || ((ones_count == 4) && (VD[0] == 1'b0));

        q_m[0] = VD[0];
        q_m[1] = use_XNOR ? (q_m[0] ~^ VD[1]) : (q_m[0] ^ VD[1]);
        q_m[2] = use_XNOR ? (q_m[1] ~^ VD[2]) : (q_m[1] ^ VD[2]);
        q_m[3] = use_XNOR ? (q_m[2] ~^ VD[3]) : (q_m[2] ^ VD[3]);
        q_m[4] = use_XNOR ? (q_m[3] ~^ VD[4]) : (q_m[3] ^ VD[4]);
        q_m[5] = use_XNOR ? (q_m[4] ~^ VD[5]) : (q_m[4] ^ VD[5]);
        q_m[6] = use_XNOR ? (q_m[5] ~^ VD[6]) : (q_m[5] ^ VD[6]);
        q_m[7] = use_XNOR ? (q_m[6] ~^ VD[7]) : (q_m[6] ^ VD[7]);
        q_m[8] = ~use_XNOR;  // 1 if XOR path, 0 if XNOR path
    end

    // Current-cycle counts derived combinationally from q_m
    wire signed [4:0] ones_w    = q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
    wire signed [4:0] zeros_w   = 5'sd8 - ones_w;
    wire signed [4:0] balance_w = ones_w - zeros_w;   // range -8..+8

  // Running disparity (sequential) 
    reg signed [6:0] disparity;   // enough headroom

    always @(posedge pixclk) begin
        if (!VDE) begin
            // Control period (BLUE channel uses HS/VS in CD; others must drive CD=2'b00)
            case (CD)
                2'b00: TMDS <= 10'b1101010100;
                2'b01: TMDS <= 10'b0010101011;
                2'b10: TMDS <= 10'b0101010100;
                2'b11: TMDS <= 10'b1010101011;
            endcase
            disparity <= 0;
        end else begin
            // Use current-cycle balance_w (not a registered old value)
            if ((disparity == 0) || (balance_w == 0)) begin
                if (q_m[8] == 1'b0) begin
                    TMDS      <= {2'b10, ~q_m[7:0]};
                    disparity <= disparity - balance_w;
                end else begin
                    TMDS      <= {2'b01,  q_m[7:0]};
                    disparity <= disparity + balance_w;
                end
            end
            else if ((disparity > 0 && balance_w > 0) || (disparity < 0 && balance_w < 0)) begin
                // same sign -> invert data
                TMDS      <= {1'b1, q_m[8], ~q_m[7:0]};
                disparity <= disparity + (q_m[8] ? 7'sd2 : -7'sd2) - balance_w;
            end
            else begin
                // opposite sign -> don’t invert
                TMDS      <= {1'b0, q_m[8],  q_m[7:0]};
                disparity <= disparity - (q_m[8] ? -7'sd2 : 7'sd2) + balance_w;
            end
        end
    end
endmodule
