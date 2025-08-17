module TMDS_encoder (
    input  wire        pixclk,
    input  wire [7:0]  VD,         // Video Data
    input  wire [1:0]  CD,         // Control Data (hsync, vsync)
    input  wire        VDE,        // Video Data Enable
    output reg  [9:0]  TMDS        // Output TMDS encoded signal
);

    // Intermediate TMDS Encoding (combinational)
    reg [8:0] iTDMS;                  // 9-bit intermediate TMDS (q_m)
    reg  [3:0] ones_count;
    reg        use_XNOR;

    integer i;
    always @(*) begin
        // count ones in VD (combinational)
        ones_count = 0;
        for (i = 0; i < 8; i = i + 1)
            ones_count = ones_count + VD[i];

        // Decide XOR or XNOR
        use_XNOR = (ones_count > 4) || (ones_count == 4 && VD[0] == 1'b0);

        // Build q_m (iTDMS[7:0])
        iTDMS[0] = VD[0];
        iTDMS[1] = use_XNOR ? (iTDMS[0] ~^ VD[1]) : (iTDMS[0] ^ VD[1]);
        iTDMS[2] = use_XNOR ? (iTDMS[1] ~^ VD[2]) : (iTDMS[1] ^ VD[2]);
        iTDMS[3] = use_XNOR ? (iTDMS[2] ~^ VD[3]) : (iTDMS[2] ^ VD[3]);
        iTDMS[4] = use_XNOR ? (iTDMS[3] ~^ VD[4]) : (iTDMS[3] ^ VD[4]);
        iTDMS[5] = use_XNOR ? (iTDMS[4] ~^ VD[5]) : (iTDMS[4] ^ VD[5]);
        iTDMS[6] = use_XNOR ? (iTDMS[5] ~^ VD[6]) : (iTDMS[5] ^ VD[6]);
        iTDMS[7] = use_XNOR ? (iTDMS[6] ~^ VD[7]) : (iTDMS[6] ^ VD[7]);
        iTDMS[8] = ~use_XNOR;  // Ninth bit
    end

    // Running Disparity (sequential) 
    reg signed [6:0] disparity;   // make a few extra bits safe
    reg signed [4:0] ones, zeros, balance;

    always @(posedge pixclk) begin
        if (!VDE) begin
            // Control Period Encoding (per DVI/HDMI spec)
            case (CD)
                2'b00: TMDS <= 10'b1101010100;
                2'b01: TMDS <= 10'b0010101011;
                2'b10: TMDS <= 10'b0101010100;
                2'b11: TMDS <= 10'b1010101011;
                default: TMDS <= 10'b1010101010;
            endcase
            disparity <= 0;
        end
        else begin
            // Count ones/zeros in q_m (use non-blocking to avoid race)
            ones  <= iTDMS[0] + iTDMS[1] + iTDMS[2] + iTDMS[3] +
                     iTDMS[4] + iTDMS[5] + iTDMS[6] + iTDMS[7];
            zeros <= 8 - (iTDMS[0] + iTDMS[1] + iTDMS[2] + iTDMS[3] +
                          iTDMS[4] + iTDMS[5] + iTDMS[6] + iTDMS[7]);
            // compute balance combinationally for use in this cycle:
            balance <= (ones - zeros);

            // Now the TMDS decision. To avoid subtle ordering issues,
            // read local copies of quantities and update disparity accordingly.
            // We'll do this with the expected semantics (registered on next cycle).
            // Use the classic algorithm:
            if ((disparity == 0) || (balance == 0)) begin
                if (iTDMS[8] == 1'b0) begin
                    TMDS <= {2'b10, ~iTDMS[7:0]};
                    disparity <= disparity - balance;
                end else begin
                    TMDS <= {2'b01, iTDMS[7:0]};
                    disparity <= disparity + balance;
                end
            end
            else if ((disparity > 0 && balance > 0) || (disparity < 0 && balance < 0)) begin
                // same sign -> invert data
                TMDS <= {1'b1, iTDMS[8], ~iTDMS[7:0]};
                // iTDMS[8] == 1 means q_m[8] = 1 (prefers non-invert)
                disparity <= disparity + (iTDMS[8] ? 5'sd2 : -5'sd2) - balance;
            end
            else begin
                TMDS <= {1'b0, iTDMS[8], iTDMS[7:0]};
                disparity <= disparity - (iTDMS[8] ? -5'sd2 : 5'sd2) + balance;
            end
        end
    end

endmodule
