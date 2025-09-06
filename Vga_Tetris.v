//module binary_loader(
//    input  wire clk,          // 25 MHz pixel clock
//    input  wire clk_f,
//    input  wire [15:0] score,
//    input  wire [3:0]  level,
//    input  wire reset,        // Active-high synchronous reset
//    input  wire [1*200-1:0] board_r,
//    input  wire [1*200-1:0] board_g,
//    input  wire [1*200-1:0] board_b,
//    output reg  h_sync_in,    // Horizontal sync
//    output reg  v_sync_in,    // Vertical sync
//    output reg  [7:0] output_r,
//    output reg  [7:0] output_g,
//    output reg  [7:0] output_b
//);

//    // VGA 640x480@60Hz timing
//    localparam H_ACTIVE      = 640;
//    localparam H_FRONT_PORCH = 16;
//    localparam H_SYNC_WIDTH  = 96;
//    localparam H_BACK_PORCH  = 48;
//    localparam H_TOTAL       = 800;

//    localparam V_ACTIVE      = 480;
//    localparam V_FRONT_PORCH = 10;
//    localparam V_SYNC_WIDTH  = 2;
//    localparam V_BACK_PORCH  = 33;
//    localparam V_TOTAL       = 525;

//    // Board config
//    localparam BLOCK_SIZE   = 24;
//    localparam BOARD_WIDTH  = 10*BLOCK_SIZE;  // 240
//    localparam BOARD_HEIGHT = 20*BLOCK_SIZE;  // 480
//    localparam START_X      = (H_ACTIVE-BOARD_WIDTH)/2;  // 200
//    localparam START_Y      = 0;

//    // bits required inside a block
//    localparam PX_BITS = $clog2(BLOCK_SIZE); // for 24 -> 5 bits

//    reg [10:0] h_count = 0;
//    reg [9:0]  v_count = 0;

//    // Horizontal + Vertical counters
//    always @(posedge clk) begin
//        if (reset) begin
//            h_count <= 0;
//            v_count <= 0;
//        end else if (h_count < H_TOTAL-1) begin
//            h_count <= h_count + 1;
//        end else begin
//            h_count <= 0;
//            if (v_count < V_TOTAL-1)
//                v_count <= v_count + 1;
//            else
//                v_count <= 0;
//        end
//    end

//    // Sync pulse generation (active low)
//    always @(posedge clk) begin
//        if (reset) begin
//            h_sync_in <= 1'b1;
//            v_sync_in <= 1'b1;
//        end else begin
//            h_sync_in <= ~((h_count >= H_ACTIVE+H_FRONT_PORCH) &&
//                           (h_count <  H_ACTIVE+H_FRONT_PORCH+H_SYNC_WIDTH));

//            v_sync_in <= ~((v_count >= V_ACTIVE+V_FRONT_PORCH) &&
//                           (v_count <  V_ACTIVE+V_FRONT_PORCH+V_SYNC_WIDTH));
//        end
//    end

//    // Combinational block/px calculation (wide enough px fields)
//    wire inside_board_comb = (h_count >= START_X) && (h_count < START_X+BOARD_WIDTH) &&
//                             (v_count >= START_Y) && (v_count < START_Y+BOARD_HEIGHT);

//    wire [3:0] block_col_comb = inside_board_comb ? (h_count - START_X)/BLOCK_SIZE : 4'd0;
//    wire [4:0] block_row_comb = inside_board_comb ? (v_count - START_Y)/BLOCK_SIZE : 5'd0;
//    wire [PX_BITS-1:0] px_x_in_block_comb = inside_board_comb ? (h_count - START_X) % BLOCK_SIZE : {PX_BITS{1'b0}};
//    wire [PX_BITS-1:0] px_y_in_block_comb = inside_board_comb ? (v_count - START_Y) % BLOCK_SIZE : {PX_BITS{1'b0}};

//    wire gridline_x_comb = inside_board_comb && (px_x_in_block_comb == 0);
//    wire gridline_y_comb = inside_board_comb && (px_y_in_block_comb == 0);

//    wire [8:0] block_index_comb = (block_col_comb < 10 && block_row_comb < 20) ? block_row_comb*10 + block_col_comb : 9'd511;

//    // Optional pipeline/register to align combinational results with pixel generation
//    reg inside_board_reg;
//    reg [3:0] block_col_reg;
//    reg [4:0] block_row_reg;
//    reg [PX_BITS-1:0] px_x_in_block_reg;
//    reg [PX_BITS-1:0] px_y_in_block_reg;
//    reg gridline_x_reg;
//    reg gridline_y_reg;
//    reg [8:0] block_index_reg;

//    always @(posedge clk) begin
//        if (reset) begin
//            inside_board_reg    <= 1'b0;
//            block_col_reg       <= 4'd0;
//            block_row_reg       <= 5'd0;
//            px_x_in_block_reg   <= {PX_BITS{1'b0}};
//            px_y_in_block_reg   <= {PX_BITS{1'b0}};
//            gridline_x_reg      <= 1'b0;
//            gridline_y_reg      <= 1'b0;
//            block_index_reg     <= 9'd511;
//        end else begin
//            inside_board_reg    <= inside_board_comb;
//            block_col_reg       <= block_col_comb;
//            block_row_reg       <= block_row_comb;
//            px_x_in_block_reg   <= px_x_in_block_comb;
//            px_y_in_block_reg   <= px_y_in_block_comb;
//            gridline_x_reg      <= gridline_x_comb;
//            gridline_y_reg      <= gridline_y_comb;
//            block_index_reg     <= block_index_comb;
//        end
//    end
  
//        // BRAM for background image
//    wire [7:0] bg_pixel;
//    wire [16:0] bg_addr;

//    assign bg_addr = (v_count >> 1) * 320 + (h_count >> 1);

//    blk_mem_gen_0 bg_bram (
//  .clka(clk_f),    // input wire clka
//  .ena(1'b1),      // input wire ena
//  .addra(bg_addr),  // input wire [16 : 0] addra
//  .douta(bg_pixel)  // output wire [7 : 0] douta
//   );

////    // Expand RGB332 -> 8-bit VGA
//      wire [7:0] bg_r = {bg_pixel[6:5], bg_pixel[7:5], bg_pixel[7:5]}; // stretch 3->8 bits
//      wire [7:0] bg_g = {bg_pixel[3:2], bg_pixel[4:2],  bg_pixel[4:2]};
//      wire [7:0] bg_b = {bg_pixel[1:0], bg_pixel[1:0],bg_pixel[1:0], bg_pixel[1:0]};
      


//    // Pixel color generation (uses registered signals)
//    always @(posedge clk) begin
//        if (reset) begin
//            output_r <= 2'b00;
//            output_g <= 2'b00;
//            output_b <= 2'b00;
//          end else if (h_count < H_ACTIVE && v_count < V_ACTIVE) begin
//            if (inside_board_reg) begin
//                if (gridline_x_reg || gridline_y_reg) begin
//                    output_r <= 8'hFF;
//                    output_g <= 8'hFF;
//                    output_b <= 8'hFF;
//                end else if (block_index_reg < 200) begin
//                    output_r <= {8{board_r[block_index_reg*1 +: 1]}};
//                    output_g <= {8{board_g[block_index_reg*1 +: 1]}};
//                    output_b <= {8{board_b[block_index_reg*1 +: 1]}};
//                end else begin
//                    output_r <= bg_r;
//                    output_g <= bg_g;
//                    output_b <= bg_b;
//                end
//            end else begin
//                output_r <=  bg_r;
//                output_g <=  bg_g;
//                output_b <=  bg_b;
//            end
//        end
//    end
// endmodule

module binary_loader(
    input  wire clk,          // 25 MHz pixel clock
    input  wire clk_f,
    input  wire [15:0] score,
    input  wire [3:0]  level,
    input  wire reset,        // Active-high synchronous reset
    input  wire [1*200-1:0] board_r,
    input  wire [1*200-1:0] board_g,
    input  wire [1*200-1:0] board_b,
    output reg  h_sync_in,    // Horizontal sync
    output reg  v_sync_in,    // Vertical sync
    output reg  [7:0] output_r,
    output reg  [7:0] output_g,
    output reg  [7:0] output_b
);

    // VGA 640x480@60Hz timing
    localparam H_ACTIVE      = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_WIDTH  = 96;
    localparam H_BACK_PORCH  = 48;
    localparam H_TOTAL       = 800;

    localparam V_ACTIVE      = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_WIDTH  = 2;
    localparam V_BACK_PORCH  = 33;
    localparam V_TOTAL       = 525;

    // Board config
    localparam BLOCK_SIZE   = 24;
    localparam BOARD_WIDTH  = 10*BLOCK_SIZE;  // 240
    localparam BOARD_HEIGHT = 20*BLOCK_SIZE;  // 480
    localparam START_X      = (H_ACTIVE-BOARD_WIDTH)/2;  // 200
    localparam START_Y      = 0;

    // Score/Level display area (144x88 starting at 475,95)
    localparam INFO_START_X = 475;
    localparam INFO_START_Y = 95;
    localparam INFO_WIDTH   = 144;
    localparam INFO_HEIGHT  = 88;
    
    // Digit display parameters (5x7 font with 2x scaling = 10x14 pixels per digit)
    localparam DIGIT_WIDTH  = 10;
    localparam DIGIT_HEIGHT = 14;
    localparam DIGIT_SPACING = 2;

    // bits required inside a block
    localparam PX_BITS = $clog2(BLOCK_SIZE); // for 24 -> 5 bits

    reg [10:0] h_count = 0;
    reg [9:0]  v_count = 0;

    // Horizontal + Vertical counters
    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else if (h_count < H_TOTAL-1) begin
            h_count <= h_count + 1;
        end else begin
            h_count <= 0;
            if (v_count < V_TOTAL-1)
                v_count <= v_count + 1;
            else
                v_count <= 0;
        end
    end

    // Sync pulse generation (active low)
    always @(posedge clk) begin
        if (reset) begin
            h_sync_in <= 1'b1;
            v_sync_in <= 1'b1;
        end else begin
            h_sync_in <= ~((h_count >= H_ACTIVE+H_FRONT_PORCH) &&
                           (h_count <  H_ACTIVE+H_FRONT_PORCH+H_SYNC_WIDTH));

            v_sync_in <= ~((v_count >= V_ACTIVE+V_FRONT_PORCH) &&
                           (v_count <  V_ACTIVE+V_FRONT_PORCH+V_SYNC_WIDTH));
        end
    end

    // Combinational block/px calculation (wide enough px fields)
    wire inside_board_comb = (h_count >= START_X) && (h_count < START_X+BOARD_WIDTH) &&
                             (v_count >= START_Y) && (v_count < START_Y+BOARD_HEIGHT);

    wire [3:0] block_col_comb = inside_board_comb ? (h_count - START_X)/BLOCK_SIZE : 4'd0;
    wire [4:0] block_row_comb = inside_board_comb ? (v_count - START_Y)/BLOCK_SIZE : 5'd0;
    wire [PX_BITS-1:0] px_x_in_block_comb = inside_board_comb ? (h_count - START_X) % BLOCK_SIZE : {PX_BITS{1'b0}};
    wire [PX_BITS-1:0] px_y_in_block_comb = inside_board_comb ? (v_count - START_Y) % BLOCK_SIZE : {PX_BITS{1'b0}};

    wire gridline_x_comb = inside_board_comb && (px_x_in_block_comb == 0);
    wire gridline_y_comb = inside_board_comb && (px_y_in_block_comb == 0);

    wire [8:0] block_index_comb = (block_col_comb < 10 && block_row_comb < 20) ? block_row_comb*10 + block_col_comb : 9'd511;

    // Optional pipeline/register to align combinational results with pixel generation
    reg inside_board_reg;
    reg [3:0] block_col_reg;
    reg [4:0] block_row_reg;
    reg [PX_BITS-1:0] px_x_in_block_reg;
    reg [PX_BITS-1:0] px_y_in_block_reg;
    reg gridline_x_reg;
    reg gridline_y_reg;
    reg [8:0] block_index_reg;

    always @(posedge clk) begin
        if (reset) begin
            inside_board_reg    <= 1'b0;
            block_col_reg       <= 4'd0;
            block_row_reg       <= 5'd0;
            px_x_in_block_reg   <= {PX_BITS{1'b0}};
            px_y_in_block_reg   <= {PX_BITS{1'b0}};
            gridline_x_reg      <= 1'b0;
            gridline_y_reg      <= 1'b0;
            block_index_reg     <= 9'd511;
        end else begin
            inside_board_reg    <= inside_board_comb;
            block_col_reg       <= block_col_comb;
            block_row_reg       <= block_row_comb;
            px_x_in_block_reg   <= px_x_in_block_comb;
            px_y_in_block_reg   <= px_y_in_block_comb;
            gridline_x_reg      <= gridline_x_comb;
            gridline_y_reg      <= gridline_y_comb;
            block_index_reg     <= block_index_comb;
        end
    end
  
    // BRAM for background image
    wire [7:0] bg_pixel;
    wire [16:0] bg_addr;

    assign bg_addr = (v_count >> 1) * 320 + (h_count >> 1);

    blk_mem_gen_0 bg_bram (
        .clka(clk_f),    // input wire clka
        .ena(1'b1),      // input wire ena
        .addra(bg_addr),  // input wire [16 : 0] addra
        .douta(bg_pixel)  // output wire [7 : 0] douta
    );

    // Expand RGB332 -> 8-bit VGA
    wire [7:0] bg_r = {bg_pixel[6:5], bg_pixel[7:5], bg_pixel[7:5]}; // stretch 3->8 bits
    wire [7:0] bg_g = {bg_pixel[3:2], bg_pixel[4:2],  bg_pixel[4:2]};
    wire [7:0] bg_b = {bg_pixel[1:0], bg_pixel[1:0],bg_pixel[1:0], bg_pixel[1:0]};
    
    // ========== SCORE AND LEVEL DISPLAY LOGIC ==========
    
    // Convert binary to BCD for score (5 digits max: 65535)
    wire [3:0] score_digit0, score_digit1, score_digit2, score_digit3, score_digit4;
    wire [3:0] level_digit0, level_digit1;
    
    // Simple BCD converter for score
    assign score_digit0 = score % 10;
    assign score_digit1 = (score / 10) % 10;
    assign score_digit2 = (score / 100) % 10;
    assign score_digit3 = (score / 1000) % 10;
    assign score_digit4 = (score / 10000) % 10;
    
    // BCD for level (2 digits max)
    assign level_digit0 = level % 10;
    assign level_digit1 = (level / 10) % 10;
    
    // Check if we're in the info display area
    wire inside_info = (h_count >= INFO_START_X) && (h_count < INFO_START_X + INFO_WIDTH) &&
                       (v_count >= INFO_START_Y) && (v_count < INFO_START_Y + INFO_HEIGHT);
    
    // Relative position within info area
    wire [7:0] info_x = inside_info ? (h_count - INFO_START_X) : 8'd0;
    wire [6:0] info_y = inside_info ? (v_count - INFO_START_Y) : 7'd0;
    
    // Determine which text/digit we're displaying
    wire in_score_text = (info_y >= 10) && (info_y < 10 + DIGIT_HEIGHT);
    wire in_score_digits = (info_y >= 30) && (info_y < 30 + DIGIT_HEIGHT);
    wire in_level_text = (info_y >= 50) && (info_y < 50 + DIGIT_HEIGHT);
    wire in_level_digits = (info_y >= 70) && (info_y < 70 + DIGIT_HEIGHT);
    
    // Function to get digit pixel (simplified 5x7 font)
    function get_digit_pixel;
        input [3:0] digit;
        input [2:0] px_x;  // 0-4 (5 pixels wide)
        input [2:0] px_y;  // 0-6 (7 pixels tall)
        reg [34:0] font_data;
        begin
            case (digit)
                4'd0: font_data = 35'b01110_10001_10011_10101_11001_10001_01110; // 0
                4'd1: font_data = 35'b00100_01100_00100_00100_00100_00100_01110; // 1
                4'd2: font_data = 35'b01110_10001_00001_00010_00100_01000_11111; // 2
                4'd3: font_data = 35'b11111_00010_00100_00010_00001_10001_01110; // 3
                4'd4: font_data = 35'b00010_00110_01010_10010_11111_00010_00010; // 4
                4'd5: font_data = 35'b11111_10000_11110_00001_00001_10001_01110; // 5
                4'd6: font_data = 35'b00110_01000_10000_11110_10001_10001_01110; // 6
                4'd7: font_data = 35'b11111_00001_00010_00100_01000_01000_01000; // 7
                4'd8: font_data = 35'b01110_10001_10001_01110_10001_10001_01110; // 8
                4'd9: font_data = 35'b01110_10001_10001_01111_00001_00010_01100; // 9
                default: font_data = 35'b00000_00000_00000_00000_00000_00000_00000;
            endcase
            get_digit_pixel = font_data[px_y * 5 + px_x];
        end
    endfunction
    
    // Simple letter patterns for S,C,O,R,E,L,V
    function get_letter_pixel;
        input [2:0] letter_id;  // 0=S, 1=C, 2=O, 3=R, 4=E, 5=L, 6=V
        input [2:0] px_x;
        input [2:0] px_y;
        reg [34:0] font_data;
        begin
            case (letter_id)
                3'd0: font_data = 35'b01111_10000_10000_01110_00001_00001_11110; // S
                3'd1: font_data = 35'b01110_10001_10000_10000_10000_10001_01110; // C
                3'd2: font_data = 35'b01110_10001_10001_10001_10001_10001_01110; // O
                3'd3: font_data = 35'b11110_10001_10001_11110_10100_10010_10001; // R
                3'd4: font_data = 35'b11111_10000_10000_11110_10000_10000_11111; // E
                3'd5: font_data = 35'b10000_10000_10000_10000_10000_10000_11111; // L
                3'd6: font_data = 35'b10001_10001_10001_10001_10001_01010_00100; // V
                default: font_data = 35'b00000_00000_00000_00000_00000_00000_00000;
            endcase
            get_letter_pixel = font_data[px_y * 5 + px_x];
        end
    endfunction
    
    // Pixel generation for info area
    reg info_pixel;
    reg [3:0] current_digit;
    reg [2:0] current_letter;
    reg [3:0] px_x_in_char;
    reg [3:0] px_y_in_char;
    
    always @(*) begin
        info_pixel = 1'b0;
        
        if (inside_info) begin
            // SCORE text (starting at x=10)
            if (in_score_text && info_x >= 10 && info_x < 70) begin
                px_x_in_char = ((info_x - 10) % 12) >> 1;  // Divide by 2 for scaling
                px_y_in_char = (info_y - 10) >> 1;
                
                if (px_x_in_char < 5 && px_y_in_char < 7) begin
                    case ((info_x - 10) / 12)
                        0: info_pixel = get_letter_pixel(0, px_x_in_char, px_y_in_char); // S
                        1: info_pixel = get_letter_pixel(1, px_x_in_char, px_y_in_char); // C
                        2: info_pixel = get_letter_pixel(2, px_x_in_char, px_y_in_char); // O
                        3: info_pixel = get_letter_pixel(3, px_x_in_char, px_y_in_char); // R
                        4: info_pixel = get_letter_pixel(4, px_x_in_char, px_y_in_char); // E
                    endcase
                end
            end
            
            // Score digits (5 digits starting at x=10)
            if (in_score_digits && info_x >= 10 && info_x < 70) begin
                px_x_in_char = ((info_x - 10) % 12) >> 1;
                px_y_in_char = (info_y - 30) >> 1;
                
                if (px_x_in_char < 5 && px_y_in_char < 7) begin
                    case ((info_x - 10) / 12)
                        0: current_digit = score_digit4;
                        1: current_digit = score_digit3;
                        2: current_digit = score_digit2;
                        3: current_digit = score_digit1;
                        4: current_digit = score_digit0;
                        default: current_digit = 4'd0;
                    endcase
                    info_pixel = get_digit_pixel(current_digit, px_x_in_char, px_y_in_char);
                end
            end
            
            // LEVEL text (starting at x=10)
            if (in_level_text && info_x >= 10 && info_x < 70) begin
                px_x_in_char = ((info_x - 10) % 12) >> 1;
                px_y_in_char = (info_y - 50) >> 1;
                
                if (px_x_in_char < 5 && px_y_in_char < 7) begin
                    case ((info_x - 10) / 12)
                        0: info_pixel = get_letter_pixel(5, px_x_in_char, px_y_in_char); // L
                        1: info_pixel = get_letter_pixel(4, px_x_in_char, px_y_in_char); // E
                        2: info_pixel = get_letter_pixel(6, px_x_in_char, px_y_in_char); // V
                        3: info_pixel = get_letter_pixel(4, px_x_in_char, px_y_in_char); // E
                        4: info_pixel = get_letter_pixel(5, px_x_in_char, px_y_in_char); // L
                    endcase
                end
            end
            
            // Level digits (2 digits starting at x=10)
            if (in_level_digits && info_x >= 10 && info_x < 34) begin
                px_x_in_char = ((info_x - 10) % 12) >> 1;
                px_y_in_char = (info_y - 70) >> 1;
                
                if (px_x_in_char < 5 && px_y_in_char < 7) begin
                    case ((info_x - 10) / 12)
                        0: current_digit = level_digit1;
                        1: current_digit = level_digit0;
                        default: current_digit = 4'd0;
                    endcase
                    info_pixel = get_digit_pixel(current_digit, px_x_in_char, px_y_in_char);
                end
            end
        end
    end

    // Pixel color generation (uses registered signals)
    always @(posedge clk) begin
        if (reset) begin
            output_r <= 8'b00;
            output_g <= 8'b00;
            output_b <= 8'b00;
        end else if (h_count < H_ACTIVE && v_count < V_ACTIVE) begin
            if (inside_board_reg) begin
                if (gridline_x_reg || gridline_y_reg) begin
                    output_r <= 8'hFF;
                    output_g <= 8'hFF;
                    output_b <= 8'hFF;
                end else if (block_index_reg < 200) begin
                    output_r <= {8{board_r[block_index_reg*1 +: 1]}};
                    output_g <= {8{board_g[block_index_reg*1 +: 1]}};
                    output_b <= {8{board_b[block_index_reg*1 +: 1]}};
                end else begin
                    output_r <= bg_r;
                    output_g <= bg_g;
                    output_b <= bg_b;
                end
            end else if (inside_info && info_pixel) begin
                // Display score/level info in white text
                output_r <= 8'hFF;
                output_g <= 8'hFF;
                output_b <= 8'hFF;
            end else begin
                output_r <= bg_r;
                output_g <= bg_g;
                output_b <= bg_b;
            end
        end else begin
            output_r <= 8'h00;
            output_g <= 8'h00;
            output_b <= 8'h00;
        end
    end
    
endmodule
