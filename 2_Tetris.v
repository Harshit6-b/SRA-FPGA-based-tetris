module simple_tetris(
    input  wire        clk,       // 25 MHz
    input  wire        reset,
    input  wire [3:0]  cmd,       // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down
    output reg  [2*200-1:0] board_r, // Red plane (2 bits/cell)
    output reg  [2*200-1:0] board_g, // Green plane
    output reg  [2*200-1:0] board_b, // Blue plane
    output reg        game_over
);

    // Grid parameters
    localparam COLS = 10;
    localparam ROWS = 20;
    localparam GRAVITY_DELAY = 12_500_000; // ~0.5 s at 25 MHz

    // Grid memory: 6 bits per cell (RR GG BB)
    reg [5:0] grid [0:ROWS*COLS-1];

    // Piece state
    reg [2:0] current_piece;
    reg [1:0] rotation;
    reg [4:0] pos_x, pos_y;

    // FSM
    reg [3:0] state;
    localparam S_SPAWN   = 0,
               S_MOVE    = 1,
               S_LOCK    = 2,
               S_CLEAR   = 3,
               S_SHIFT   = 4,
               S_UPDATE  = 5,
               S_GAMEOVER= 6;

    // Gravity counter
    reg [23:0] gravity_cnt;

    // Output update
    reg [8:0] out_idx;

    // Collision check
    reg checking;
    reg [3:0] check_idx;
    reg collision_flag;
    reg [4:0] test_x, test_y;
    reg [1:0] test_rot;

    // Line clear
    reg [4:0] clear_row;
    reg [3:0] clear_col;
    reg row_full;
    reg clearing;

    // Tetromino ROM [piece][rotation]
    reg [15:0] tetrominos [0:6][0:3];
    initial begin
        // I
        tetrominos[0][0] = 16'b0000_1111_0000_0000;
        tetrominos[0][1] = 16'b0010_0010_0010_0010;
        tetrominos[0][2] = 16'b0000_1111_0000_0000;
        tetrominos[0][3] = 16'b0010_0010_0010_0010;
        // O
        tetrominos[1][0] = 16'b0000_0110_0110_0000;
        tetrominos[1][1] = 16'b0000_0110_0110_0000;
        tetrominos[1][2] = 16'b0000_0110_0110_0000;
        tetrominos[1][3] = 16'b0000_0110_0110_0000;
        // T
        tetrominos[2][0] = 16'b0000_1110_0100_0000;
        tetrominos[2][1] = 16'b0100_1100_0100_0000;
        tetrominos[2][2] = 16'b0000_0100_1110_0000;
        tetrominos[2][3] = 16'b0100_0110_0100_0000;
        // L
        tetrominos[3][0] = 16'b0000_1110_0010_0000;
        tetrominos[3][1] = 16'b0100_0100_1100_0000;
        tetrominos[3][2] = 16'b1000_1110_0000_0000;
        tetrominos[3][3] = 16'b0110_0100_0100_0000;
        // J
        tetrominos[4][0] = 16'b0000_1110_1000_0000;
        tetrominos[4][1] = 16'b1100_0100_0100_0000;
        tetrominos[4][2] = 16'b0010_1110_0000_0000;
        tetrominos[4][3] = 16'b0100_0100_0110_0000;
        // S
        tetrominos[5][0] = 16'b0000_0110_1100_0000;
        tetrominos[5][1] = 16'b0100_0110_0010_0000;
        tetrominos[5][2] = 16'b0000_0110_1100_0000;
        tetrominos[5][3] = 16'b0100_0110_0010_0000;
        // Z
        tetrominos[6][0] = 16'b0000_1100_0110_0000;
        tetrominos[6][1] = 16'b0010_0110_0100_0000;
        tetrominos[6][2] = 16'b0000_1100_0110_0000;
        tetrominos[6][3] = 16'b0010_0110_0100_0000;
    end

    // Piece colors (RGB222)
    reg [5:0] tetris_colors [0:6];
    initial begin
        tetris_colors[0] = 6'b110000; // I - Red
        tetris_colors[1] = 6'b001100; // O - Green
        tetris_colors[2] = 6'b000011; // T - Blue
        tetris_colors[3] = 6'b111100; // L - Yellow
        tetris_colors[4] = 6'b110100; // J - Orange
        tetris_colors[5] = 6'b111001; // S - Pink
        tetris_colors[6] = 6'b001111; // Z - Cyan
    end
    reg [4:0] col_tmp, row_tmp;
    integer i;
    
     reg [5:0] cell_color;
     reg [2:0] lx;
                        reg [2:0] ly;
                        reg [3:0] bit_index;
    always @(posedge clk) begin
        if (reset) begin
            for (i=0; i<ROWS*COLS; i=i+1)
                grid[i] <= 6'h00;
            current_piece <= 0;
            rotation <= 0;
            pos_x <= 3; pos_y <= 0;
            state <= S_SPAWN;
            game_over <= 0;
            gravity_cnt <= 0;
            out_idx <= 0;
            checking <= 0;
            clearing <= 0;
        end else begin
            case (state)

                // Spawn a new piece
                S_SPAWN: begin
                    current_piece <= (current_piece + 1) % 7; // cycle through 7 pieces
                    rotation <= 0;
                    pos_x <= 3;
                    pos_y <= 0;

                    // Start collision check for spawn
                    test_x <= 3; test_y <= 0; test_rot <= 0;
                    checking <= 1; check_idx <= 0; collision_flag <= 0;
                    if (!checking) begin
                        if (collision_flag) state <= S_GAMEOVER;
                        else state <= S_MOVE;
                    end
                end

                // Movement & gravity
                S_MOVE: begin
                    test_x <= pos_x;
                    test_y <= pos_y;
                    test_rot <= rotation;

                    // Commands
                    if (cmd == 4'b1000) test_x <= pos_x - 1;  // left
                    else if (cmd == 4'b0001) test_x <= pos_x + 1; // right
                    else if (cmd == 4'b0100) test_rot <= rotation + 1; // rotate

                    // Gravity
                    if (gravity_cnt >= GRAVITY_DELAY || cmd == 4'b0010) begin
                        gravity_cnt <= 0;
                        test_y <= pos_y + 1;
                    end else begin
                        gravity_cnt <= gravity_cnt + 1;
                    end

                    // Start collision check
                    checking <= 1;
                    check_idx <= 0;
                    collision_flag <= 0;

                    if (!checking) begin
                        if (!collision_flag) begin
                            pos_x <= test_x;
                            pos_y <= test_y;
                            rotation <= test_rot;
                        end else begin
                            if (test_y != pos_y) state <= S_LOCK; // block below
                        end
                    end
                end

                // Lock piece into grid
                S_LOCK: begin
                    for (i=0; i<16; i=i+1) begin
                        if (tetrominos[current_piece][rotation][15-i]) begin
                            grid[(pos_y + (i>>2))*COLS + (pos_x + (i&3))] <= 
                                tetris_colors[current_piece];
                        end
                    end
                    clear_row <= ROWS-1;
                    state <= S_CLEAR;
                end

                // Scan for full rows
                S_CLEAR: begin
                    row_full = 1;
                    for (i=0; i<COLS; i=i+1) begin
                        if (grid[clear_row*COLS + i] == 6'h00) row_full = 0;
                    end

                    if (row_full) begin
                        clearing <= 1;
                        clear_col <= 0;
                        state <= S_SHIFT;
                    end else if (clear_row == 0) begin
                        state <= S_UPDATE;
                    end else begin
                        clear_row <= clear_row - 1;
                    end
                end

                // Shift rows down
                S_SHIFT: begin
                    if (clear_row > 0) begin
                        grid[clear_row*COLS + clear_col] <= grid[(clear_row-1)*COLS + clear_col];
                        if (clear_col == COLS-1) begin
                            clear_col <= 0;
                            clear_row <= clear_row - 1;
                        end else begin
                            clear_col <= clear_col + 1;
                        end
                    end else begin
                        grid[clear_col] <= 6'h00; // clear top row
                        if (clear_col == COLS-1) begin
                            clearing <= 0;
                            clear_row <= ROWS-1;
                            state <= S_CLEAR;
                        end else begin
                            clear_col <= clear_col + 1;
                        end
                    end
                end

                // Output update (sequential)
//                S_UPDATE: begin
//                    board_r[2*out_idx +: 2] <= grid[out_idx][5:4];
//                    board_g[2*out_idx +: 2] <= grid[out_idx][3:2];
//                    board_b[2*out_idx +: 2] <= grid[out_idx][1:0];

//                    if (out_idx == ROWS*COLS-1) begin
//                        out_idx <= 0;
//                        state <= S_SPAWN;
//                    end else begin
//                        out_idx <= out_idx + 1;
//                    end
//                end
                                // Output update (sequential) - now overlays active piece
                S_UPDATE: begin
                    // compute row/col for the current out_idx
                    // out_idx ranges 0..ROWS*COLS-1
                    // row_tmp and col_tmp are available regs
                    row_tmp = out_idx / COLS;
                    col_tmp = out_idx % COLS;

                    // default color is the static grid cell
                    cell_color = grid[out_idx];

                    // overlay active piece: check if this cell is inside the 4x4 tetromino bounding box
                    // local coordinates inside the 4x4 piece:
                    // local_x = col_tmp - pos_x, local_y = row_tmp - pos_y
                    if ((col_tmp >= pos_x) && (col_tmp < pos_x + 4) &&
                        (row_tmp >= pos_y) && (row_tmp < pos_y + 4)) begin
                        
                        lx = col_tmp - pos_x;
                        ly = row_tmp - pos_y;
                        bit_index = ly*4 + lx; // 0..15
                        if (tetrominos[current_piece][rotation][15 - bit_index]) begin
                            // overlay with piece color (active piece)
                            cell_color = tetris_colors[current_piece];
                        end
                    end

                    // write outputs from cell_color
                    board_r[2*out_idx +: 2] <= cell_color[5:4];
                    board_g[2*out_idx +: 2] <= cell_color[3:2];
                    board_b[2*out_idx +: 2] <= cell_color[1:0];

                    if (out_idx == ROWS*COLS-1) begin
                        out_idx <= 0;
                        state <= S_SPAWN;
                    end else begin
                        out_idx <= out_idx + 1;
                    end
                end


                S_GAMEOVER: begin
                    game_over <= 1;
                end
            endcase

            // Collision checker
            if (checking) begin
                if (tetrominos[current_piece][test_rot][15-check_idx]) begin
                    
                    col_tmp = test_x + (check_idx & 3);
                    row_tmp = test_y + (check_idx >> 2);
                    if (col_tmp >= COLS || row_tmp >= ROWS)
                        collision_flag <= 1;
                    else if (grid[row_tmp*COLS + col_tmp] != 6'h00)
                        collision_flag <= 1;
                end
                if (check_idx == 15) checking <= 0;
                else check_idx <= check_idx + 1;
            end
        end
    end
endmodule

