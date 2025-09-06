`timescale 1ns/1ps
module receiver_RxD(
    input clk,
    input reset,
    input RxD,
    output [7:0] RxData
);
reg shift;
reg state, nextstate;
reg [3:0] sample_counter;
reg [3:0] bit_counter;
reg [13:0] baudrate_counter;
reg [9:0] rxshift_reg;
reg clear_b, inc_b, clear_s, inc_s;

// Parameters for 25 MHz clock
parameter clk_freq = 25000000;      // Changed to 25 MHz
parameter baud_rate = 9600;
parameter div_sample = 4;
parameter div_counter = clk_freq/(baud_rate*div_sample);  // = 651 for 25MHz
parameter mid_sample = div_sample/2;
parameter div_bit = 10;

assign RxData = rxshift_reg[8:1];

// COMBINED ALWAYS BLOCK - This fixes the multiple driver issue
always @(posedge clk) begin
    if(reset) begin
        state <= 0;
        bit_counter <= 0;
        baudrate_counter <= 0;
        sample_counter <= 0;
        rxshift_reg <= 10'h3FF;  // Initialize shift register
    end
    else begin
        // Default values for control signals
        shift <= 0;
        clear_s <= 0;
        inc_s <= 0;
        clear_b <= 0;
        inc_b <= 0;
        nextstate <= 0;
        
        // Next state logic
        case(state)
            0: begin
                if(RxD) begin
                    nextstate <= 0;
                end
                else begin 
                    nextstate <= 1;
                    clear_b <= 1;
                    clear_s <= 1;
                end
            end
             
            1: begin
                nextstate <= 1;
                
                if (sample_counter == mid_sample - 1)
                    shift <= 1;
                    
                if(sample_counter == div_sample - 1) begin
                    if(bit_counter == div_bit - 1) begin
                        nextstate <= 0;
                    end
                    inc_b <= 1;
                    clear_s <= 1;
                end
                else begin 
                    inc_s <= 1;
                end
            end
             
            default: nextstate <= 0;
        endcase
        
        // Baudrate counter and state updates
        baudrate_counter <= baudrate_counter + 1;
        if (baudrate_counter >= div_counter - 1) begin
            baudrate_counter <= 0;
            state <= nextstate;
            
            if(shift)
                rxshift_reg <= {RxD, rxshift_reg[9:1]};
                
            if (clear_s)
                sample_counter <= 0;
                
            if (inc_s)
                sample_counter <= sample_counter + 1;
                
            if (clear_b) 
                bit_counter <= 0;
               
            if (inc_b)
                bit_counter <= bit_counter + 1;
        end
    end
end
endmodule



`timescale 1ns/1ps
module uart_led_top(
    input  wire clk,      // 25 MHz clock
    input  wire reset,    // active-high reset
    input  wire RxD,      // UART RX pin
    output reg [15:0] led // Arty A7 onboard LEDs
);

    // UART receiver instance
    wire [7:0] uart_data;
    receiver_RxD uart_inst (
        .clk(clk),
        .reset(reset),
        .RxD(RxD),
        .RxData(uart_data)
    );

    // Example: Map received UART data directly to LEDs
    always @(posedge clk or posedge reset) begin
        if (reset)
            led <= 16'h0000;
        else begin
            // Simple mapping: lower 8 bits of LED follow UART data
            led[7:0] <= uart_data;
            // Optional: upper 8 LEDs mirror lower 8
            led[15:8] <= uart_data;
        end
    end

endmodule




