module uart(
    input clk,
    input [3:0] button,
    output reg [3:0] rled,      
    output reg [3:0] gled,
    output reg [3:0] bled
);

initial begin
    bled = 4'b0000;   
    rled = 4'b0001;
    gled = 4'b0000;
end

always @(posedge clk) begin
    if (button == 4'b0001) begin
        if (bled==4'b0000&&gled==4'b0000) begin
        	if (rled==4'b0001) begin
        		rled=4'b1000;
        	end
        	else begin
        		rled={1'b0,rled[3:1]};
        	end
        end
        else if (rled==4'b0000&&gled==4'b0000) begin
        	if (bled==4'b0001) begin
        		bled=4'b1000;
        	end
        	else begin
        		bled={1'b0,gled[3:1]};
        	end
        end
        else if (bled==4'b0000&&rled==4'b0000) begin
        	if (gled==4'b0001) begin
        		gled=4'b1000;
        	end
        	else begin
        		gled={1'b0,gled[3:1]};
        	end
        end
    end
    else if (button == 4'b1000) begin
        if (bled==4'b0000&&gled==4'b0000) begin
        	if (rled==4'b1000) begin
        		rled=4'b0001;
        	end
        	else begin
        		rled={rled[2:0],1'b0};
        	end
        end
        else if (rled==4'b0000&&gled==4'b0000) begin
        	if (bled==4'b1000) begin
        		bled=4'b0001;
        	end
        	else begin
        		bled={gled[2:0],1'b0};
        	end
        end
        else if (bled==4'b0000&&rled==4'b0000) begin
        	if (gled==4'b1000) begin
        		gled=4'b0001;
        	end
        	else begin
        		gled={gled[2:0],1'b0};
        	end
        end
    end
    else if (button == 4'b0100) begin
       if((~(rled==4'b0000))&&(gled==4'b0000)&&(bled==4'b0000)) begin
       		gled<=rled;
       		rled<=4'b0000;
       	end
       	else if((~(gled==4'b0000))&&(rled==4'b0000)&&(bled==4'b0000)) begin
       		bled<=gled;
       		gled<=4'b0000;
       	end
       	else if((~(bled==4'b0000))&&(gled==4'b0000)&&(rled==4'b0000)) begin
       		rled<=bled;
       		bled<=4'b0000;
       	end
    end
    else if (button == 4'b0010) begin
        if((~(bled==4'b0000))&&(gled==4'b0000)&&(rled==4'b0000)) begin
       		gled<=bled;
       		bled<=4'b0000;
       	end
       	else if((~(rled==4'b0000))&&(gled==4'b0000)&&(bled==4'b0000)) begin
       		bled<=rled;
       		rled<=4'b0000;
       	end
       	else if((~(gled==4'b0000))&&(bled==4'b0000)&&(rled==4'b0000)) begin
       		rled<=gled;
       		gled<=4'b0000;
       	end              
    end
    else begin
        bled <= bled;
        rled <= rled;
        gled <= gled;
    end
end

endmodule
