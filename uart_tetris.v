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
   	4'b0001:state<={1'b0,state[11:1]};
   	4'b1000:state<={state[10:0],1'b0};
   	4'b0100:state<={state[7:0],4'b0000};
   	4'b0010:state<={4'b0000,state[11:4]};
endcase
 bled = state[11:8];   
    rled = state[7:4];
    gled = state[3:0];
end

endmodule
