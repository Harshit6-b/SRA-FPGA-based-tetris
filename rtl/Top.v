module tetris_top (
    input  CLK100MHZ,        // 25 MHz VGA pixel clock
    input  reset,
    input  [3:0] cmd,        // user controls
    output hsync,            // VGA horizontal sync
    output vsync,            // VGA vertical sync            
    output game_over_led,
    output clk_100mhz,
    output locked,
    output [7:0]output_r,     // Red channel
    output [7:0]output_g,     // Green channel
    output [7:0]output_b      // Blue channel
);
    assign clk_100mhz = CLK100MHZ ;
    
    // 200-bit board wire
    wire clk_25mhz;
    wire clk_75mhz;
    
    wire [1*200-1:0] board_r;
    wire [1*200-1:0] board_g;
    wire [1*200-1:0] board_b;
    wire [15:0] score;
    wire [3:0]  level;
      
    // Clocking Wizard
      clk_wiz_0 instance_name
   (
    // Clock out ports
    .clk_out1(clk_25mhz),
    .clk_out2(clk_75mhz),
    
   // .clk_out2(clk_50mhz),
    // Status and control signals
    .reset(reset), // input reset
    .locked(locked),       // output locked
   // Clock in ports
    .clk_in1(CLK100MHZ)      // input clk_in1
);
    
    // Game logic instance
    simple_tetris game_inst (
        .clk(clk_25mhz),
        .reset(reset),
        .cmd(cmd),
        .board_r(board_r),
        .board_g(board_g),
        .board_b(board_b),
        .game_over(game_over_led),
        .score(score),
        .level(level)
    );

    // VGA display instance
    binary_loader vga_inst (
        .clk(clk_25mhz),
        .clk_f(clk_75mhz),
        .score(score),
        .level(level),
        .reset(reset),
        .board_r(board_r),
        .board_g(board_g),
        .board_b(board_b),
        .h_sync_in(hsync),
        .v_sync_in(vsync),
        .output_r(output_r),
        .output_g(output_g),
        .output_b(output_b)        
    );

endmodule

