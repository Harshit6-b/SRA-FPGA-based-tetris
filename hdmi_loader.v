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
	      hcount <= hcount + 1;  // Increment pixel counter on each new clock cycle

	      // Manage horizontal synchronization signal based on pixel count
	      case (hcount)
		800: begin
			hsync <= 1;  // End of active video region, prepare for horizontal blanking	
			VDE<=0;
		end
		840: begin
			hsync <= 0;  // Horizontal sync pulse start
			VDE<=0;
		end
		968: begin 
			hsync <= 1;  // Horizontal sync pulse end
			VDE<=0;
		end
		1056: begin  // End of horizontal line, reset counter and update frame count
		    VDE<=0;
		    hcount <= 0;  // Reset pixel counter to start a new line
		    vcount <= vcount + 1;  // Increment line count

		    // Manage vertical synchronization signal based on line count
		    case(vcount)
		        601: vsync <= 0;  // Vertical sync pulse start
		        605: vsync <= 1;  // Vertical sync pulse end
		        623: begin  // End of frame (based on line count)
		            if(temp == 5'd10) begin  // After 10 frames, switch frame (used for animations)
		                frame_switch <= ~frame_switch;  // Toggle frame switch signal
		                temp <= 0;  // Reset temporary counter
		            end else begin
		                temp <= temp + 1;  // Increment temporary counter
		            end
		            vcount <= 0;  // Reset line count for new frame
		        end
		    endcase
		end
		default :VDE <= (hcount < 800) && (vcount < 600);
	      endcase
	      
	      CD <= {vsync , hsync};
	  end
endmodule

