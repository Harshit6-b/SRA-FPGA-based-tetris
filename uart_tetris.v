module uart(
    input clk,
    input [3:0] button,
    output reg [3:0] rled,      
    output reg [3:0] gled,
    output reg [3:0] bled
);

initial begin
    bled = 4'b1111;   
    rled = 4'b0000;
    gled = 4'b0000;
end

always @(posedge clk) begin
    if (button == 4'b0001) begin
        bled <= {1'b0, bled[3:1]};    
         rled <= {1'b0, rled[3:1]};  
          gled <= {1'b0, gled[3:1]};  
    end
    else if (button == 4'b1000) begin
        bled <= {bled[2:0], 1'b0};   
        rled <= {rled[2:0], 1'b0};     
        gled <= {gled[2:0], 1'b0};   
    end
    else if (button == 4'b0100) begin
        if (bled==4'b1111) begin
            rled<=4'b1111;
            bled<=4'b0000;
        end
        else if(rled==4'b1111) begin
            rled<=4'b0000;
            gled<=4'b1111;
        end
        else begin 
            gled<=4'b0000;
            bled<=4'b1111;
        end     
    end
    else if (button == 4'b0010) begin
        if (bled==4'b1111) begin
            gled<=4'b1111;
            bled<=4'b0000;
        end
        else if(rled==4'b1111) begin
            rled<=4'b0000;
            bled<=4'b1111;
        end
        else begin 
            gled<=4'b0000;
            rled<=4'b1111;
        end              
    end
    else begin
        bled <= bled;
        rled <= rled;
        gled <= gled;
    end
end

endmodule
