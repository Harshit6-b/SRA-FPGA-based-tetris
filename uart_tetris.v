module uart(
    input clk,
    input [3:0] button,
    output reg [3:0] rled,      
    output reg [3:0] gled,
    output reg [3:0] bled
);
reg state=12'b000000000001;


always @(posedge clk) begin
   case (button)
   	4'b0001:state<=state>>1;
   	4'b1000:state<=state<<1;
   	4'b0100:state<=state<<4;
   	4'b0010:state<=state>>4;
endcase
 bled = state[11:8];   
    gled = state[7:4];
    rled = state[3:0];
end

endmodule
