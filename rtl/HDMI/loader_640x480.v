module hdmi_loader (
    input  wire        pixclk,
    input wire         rst,
    output reg         VDE,     // Video Data Enable (active video region)
    output reg [1:0]   CD       // {hsync, vsync}
);

    //Horizontal &bvertical counters
    reg [9:0] hcount;  // 0..799
    reg [9:0] vcount;  // 0..524

    reg hsync;
    reg vsync;

    initial begin
        hcount <= 10'd0;
        vcount <= 10'd0;
        hsync  <= 1'b1;
        vsync  <= 1'b1;
        VDE    <= 1'b1;
        CD     <= 2'b11;
    end

    always @(posedge pixclk) begin
        //Horizontal counter
        if (hcount == 10'd799) begin
            hcount <= 10'd0;

            //Vertical counter
            if (vcount == 10'd524)
                vcount <= 10'd0;
            else
                vcount <= vcount + 10'd1;
        end else begin
            hcount <= hcount + 10'd1;
        end

        //Generate hsync (active low)
        if ((hcount >= (640 + 16)) && (hcount < (640 + 16 + 96)))
            hsync <= 1'b0;
        else
            hsync <= 1'b1;

        //Generate vsync (active low)
        if ((vcount >= (480 + 10)) && (vcount < (480 + 10 + 2)))
            vsync <= 1'b0;
        else
            vsync <= 1'b1;

        //Active video region
        VDE <= (hcount < 640) && (vcount < 480);

        //Combine syncs into CD
        CD <= {hsync, vsync};
    end

endmodule
