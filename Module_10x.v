    module clk_div_10x (
    input wire clk_in,       // Input clock
    output reg clk_out = 0   // Output clock 
);

        reg [3:0] count = 0;     // 4-bit counter 0 to 9

    always @(posedge clk_in) begin
        if (count == 4) begin
            count <= 0;
            clk_out <= ~clk_out;  // Toggle output every 5 cycles → full period = 10 cycles
        end else begin
            count <= count + 1;
        end
    end

endmodule
