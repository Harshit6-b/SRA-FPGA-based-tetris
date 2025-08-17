module hdmi_loader (
    input wire pixclk,      
    output reg VDE,          // Video Data Enable (active video)
    output reg [1:0] CD      // {vsync, hsync}
);

    // Horizontal and vertical counters
    reg [9:0] hcount;  // 0..799
    reg [9:0] vcount;  // 0..524

    reg hsync, vsync;

    initial begin
        hcount <= 0;
        vcount <= 0;
        hsync  <= 1;
        vsync  <= 1;
        VDE    <= 0;
        CD     <= 2'b11;
    end

    always @(posedge pixclk) begin
        // Horizontal counter
        if (hcount == 799) begin
            hcount <= 0;

            // Vertical counter
            if (vcount == 524) begin
                vcount <= 0;
            end else begin
                vcount <= vcount + 1;
            end
        end else begin
            hcount <= hcount + 1;
        end

        // Generate H-Sync (active low)
        if (hcount >= (640 + 16) && hcount < (640 + 16 + 96))
            hsync <= 0;
        else
            hsync <= 1;

        // Generate V-Sync (active low)
        if (vcount >= (480 + 10) && vcount < (480 + 10 + 2))
            vsync <= 0;
        else
            vsync <= 1;

        // Active video region
        VDE <= (hcount < 640) && (vcount < 480);

        // Combine syncs into CD
        CD <= {vsync, hsync};
    end

endmodule

