module hdmi_loader(
input pixclk,
output reg VDE,
output reg [1:0]CD
);
	
reg [10:0] hcount;
reg [9:0] vcount;
reg hsync, vsync;
reg frame_switch;
reg [4:0] temp ;

// Initial block to set default values for the registers
  initial begin
      hcount <= 0;  
      vcount <= 0;  
      hsync <= 1;  
      vsync <= 1; 
      frame_switch <= 0;  
      temp <= 0; 
      VDE <= 0;
      CD <= 2'b11;
  end 
// Main logic block to handle pixel counting and synchronization signals
 always @(posedge pixclk) begin
    // Manage horizontal synchronization signal based on pixel count
    case (hcount)
        800: begin
            hsync <= 1;  
            VDE   <= 0;
        end
        840: begin
            hsync <= 0;  
            VDE   <= 0;
        end
        968: begin 
            hsync <= 1;  
            VDE   <= 0;
        end
        1056: begin  
            VDE    <= 0;
            hcount <= 0;
            vcount <= vcount + 1;

            // Vertical sync
            case(vcount)
                601: vsync <= 0;
                605: vsync <= 1;
                623: vcount <= 0;
            endcase
        end
        default: VDE <= (hcount < 800) && (vcount < 600);
    endcase

    CD <= {vsync, hsync};

    // Increment at the end
    if (hcount != 1056)
        hcount <= hcount + 1;
end

	
endmodule

