module simple_tetris(
    input  wire clk,
    input  wire reset,
    input  wire [3:0] cmd, // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down
    output reg  [199:0] board_r, // Red plane (20x10)
    output reg  [199:0] board_g, // Green plane
    output reg  [199:0] board_b, // Blue plane
    output reg  game_over,
    output reg [15:0] score,
    output reg [3:0]  level
);

    parameter COLS = 10;
    parameter ROWS = 20;

    // Game state
    reg signed [5:0] piece_x, piece_y; // current piece position - SIGNED for proper arithmetic
    reg [2:0] current_piece, rotation;
    reg [199:0] grid_r, grid_g, grid_b; // settled blocks per color
    reg [31:0] counter; // gravity counter
    reg [1:0] state; // 0 = spawn, 1 = falling, 2 = game over
    reg [2:0] seq_index; // index for fixed sequence 0..6
    reg piece_active; // flag to indicate if there's an active piece

    // loop / index signals
    reg [7:0] row, col, k;
    reg signed [8:0] board_piece_col, board_piece_row; // SIGNED for calculation

    // Button debouncing
    reg [3:0] cmd_prev;
    reg [3:0] cmd_edge;

    // Tetromino definitions
    reg [15:0] tetrominos [0:6][0:3];

    //LFSR for random numbers
    reg [7:0] lfsr;
    wire [3:0] rand_x;

    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'hAC; // seed
        else if (!game_over) // Only update LFSR when game is running
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    assign rand_x = lfsr % COLS;

    //Piece color assignment
    function [2:0] piece_color;
        input [2:0] piece;
        begin
            case (piece % 7)  // Changed from lfsr % 7 to piece % 7 for consistent colors
                3'd0: piece_color = 3'b011; // I = Cyan
                3'd1: piece_color = 3'b110; // O = Yellow
                3'd2: piece_color = 3'b101; // T = Magenta
                3'd3: piece_color = 3'b100; // L = Red
                3'd4: piece_color = 3'b001; // J = Blue
                3'd5: piece_color = 3'b010; // S = Green
                3'd6: piece_color = 3'b111; // Z = White
                default: piece_color = 3'b111; // fallback
            endcase
        end
    endfunction

    //Regular collision function for movement/rotation
    function collision;
        input [2:0] piece_idx;
        input [1:0] rot_idx;
        input signed [5:0] test_x;
        input signed [5:0] test_y;
        integer kk;
        reg signed [8:0] col_tmp, row_tmp;
        begin
            collision = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[piece_idx][rot_idx][15 - kk]) begin
                    col_tmp = test_x + (kk % 4);
                    row_tmp = test_y + (kk / 4);
                    
                    // Check if piece block is outside board boundaries
                    if (col_tmp < 0 || col_tmp >= COLS || 
                        row_tmp < 0 || row_tmp >= ROWS) begin
                        collision = 1;
                    end 
                    // Check if piece block collides with settled blocks
                    else if (grid_r[row_tmp*COLS + col_tmp] ||
                             grid_g[row_tmp*COLS + col_tmp] ||
                             grid_b[row_tmp*COLS + col_tmp]) begin
                        collision = 1;
                    end
                end
            end
        end
    endfunction

    //Special collision function for spawn checking
    function spawn_collision;
        input [2:0] piece_idx;
        input [1:0] rot_idx;
        input signed [5:0] test_x;
        input signed [5:0] test_y;
        integer kk;
        reg signed [8:0] col_tmp, row_tmp;
        begin
            spawn_collision = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[piece_idx][rot_idx][15 - kk]) begin
                    col_tmp = test_x + (kk % 4);
                    row_tmp = test_y + (kk / 4);
                    
                    // Check collision with settled blocks anywhere on the board
                    if (col_tmp >= 0 && col_tmp < COLS && 
                        row_tmp >= 0 && row_tmp < ROWS) begin
                        if (grid_r[row_tmp*COLS + col_tmp] ||
                            grid_g[row_tmp*COLS + col_tmp] ||
                            grid_b[row_tmp*COLS + col_tmp]) begin
                            spawn_collision = 1;
                        end
                    end
                end
            end
        end
    endfunction

    reg full;
    integer ctmp;

    //Main game logic
    reg [31:0] gravity_threshold;
    integer lines;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize tetrominos - adjusted for better positioning
            // I-piece
            tetrominos[0][0] <= 16'b0000111100000000;
            tetrominos[0][1] <= 16'b0010001000100010;
            tetrominos[0][2] <= 16'b0000000011110000;
            tetrominos[0][3] <= 16'b0100010001000100;

            // O-piece
            tetrominos[1][0] <= 16'b0110011000000000;
            tetrominos[1][1] <= 16'b0110011000000000;
            tetrominos[1][2] <= 16'b0110011000000000;
            tetrominos[1][3] <= 16'b0110011000000000;

            // T-piece
            tetrominos[2][0] <= 16'b0100111000000000;
            tetrominos[2][1] <= 16'b0100011001000000;
            tetrominos[2][2] <= 16'b0000111001000000;
            tetrominos[2][3] <= 16'b0100110001000000;

            // L-piece
            tetrominos[3][0] <= 16'b0010011101000000;
            tetrominos[3][1] <= 16'b0100010001100000;
            tetrominos[3][2] <= 16'b0000111010000000;
            tetrominos[3][3] <= 16'b1100010001000000;

            // J-piece
            tetrominos[4][0] <= 16'b1000111000000000;
            tetrominos[4][1] <= 16'b0110010001000000;
            tetrominos[4][2] <= 16'b0000111000100000;
            tetrominos[4][3] <= 16'b0100010011000000;

            // S-piece
            tetrominos[5][0] <= 16'b0110110000000000;
            tetrominos[5][1] <= 16'b0100011000100000;
            tetrominos[5][2] <= 16'b0000011011000000;
            tetrominos[5][3] <= 16'b1000110001000000;

            // Z-piece
            tetrominos[6][0] <= 16'b1100011000000000;
            tetrominos[6][1] <= 16'b0010011001000000;
            tetrominos[6][2] <= 16'b0000110001100000;
            tetrominos[6][3] <= 16'b0100110010000000;

            game_over <= 0;
            state <= 0;
            grid_r <= 0;
            grid_g <= 0;
            grid_b <= 0;
            counter <= 0;
            seq_index <= 0;
            current_piece <= 0;
            rotation <= 0;
            piece_x <= 3;
            piece_y <= 0;
            piece_active <= 0;

            score <= 0;
            level <= 1;
            gravity_threshold <= 25_000_000; // initial threshold
            
            // Initialize button debouncing
            cmd_prev <= 4'b0000;
            cmd_edge <= 4'b0000;
        end else begin
            // Button edge detection (always update to prevent glitches)
            cmd_prev <= cmd;
            cmd_edge <= cmd & ~cmd_prev;  // Detect rising edge
            
            // If game over, completely freeze the game
            if (game_over) begin
                // Do nothing - game is frozen
                state <= 2; // Explicitly set to game over state
            end else begin
                // synchronous gravity threshold calculation
                if (level == 0)
                    gravity_threshold <= 25_000_000;
                else
                    gravity_threshold <= 25_000_000 / level;
                if (gravity_threshold < 2_000_000)
                    gravity_threshold <= 2_000_000;

                counter <= counter + 1;

                case (state)
                    0: begin // spawn new piece
                        // First check if spawn position is clear
                        if (spawn_collision(seq_index, 2'd0, 6'd3, -6'd1)) begin
                            // Game over - cannot spawn piece
                            game_over <= 1;
                            piece_active <= 0;
                            state <= 2; // Go to game over state
                        end else begin
                            // Safe to spawn - update piece variables and proceed
                            current_piece <= seq_index;
                            seq_index <= (seq_index == 6) ? 0 : seq_index + 1;
                            rotation <= 0;
                            piece_x <= 3; // spawn in middle
                            piece_y <= -1; // Start slightly above to check for immediate collision
                            piece_active <= 1;
                            
                            // Check if piece can move to row 0
                            if (!collision(current_piece, 2'd0, 6'd3, 6'd0)) begin
                                piece_y <= 0;
                                state <= 1;
                            end else begin
                                // Can't even move to row 0 - game over
                                game_over <= 1;
                                piece_active <= 0;
                                state <= 2;
                            end
                        end
                    end
                    
                    1: begin // falling state
                        // Movement with proper collision checking
                        if (cmd_edge[3] && !collision(current_piece, rotation, piece_x - 1, piece_y)) 
                            piece_x <= piece_x - 1;
                        
                        if (cmd_edge[0] && !collision(current_piece, rotation, piece_x + 1, piece_y)) 
                            piece_x <= piece_x + 1;
                        
                        // rotation: check next rotation for this piece
                        if (cmd_edge[2] && !collision(current_piece, (rotation + 1) & 2'd3, piece_x, piece_y)) 
                            rotation <= (rotation + 1) & 2'd3;
                        
                        // Continuous down movement (hold)
                        if (cmd[1] && !collision(current_piece, rotation, piece_x, piece_y + 1)) 
                            piece_y <= piece_y + 1;

                        // Gravity
                        if (counter >= gravity_threshold - 1) begin
                            counter <= 0;
                            if (!collision(current_piece, rotation, piece_x, piece_y + 1)) begin
                                piece_y <= piece_y + 1;
                            end else begin
                                // Lock piece into grid
                                piece_active <= 0;
                                
                                for (k = 0; k < 16; k = k + 1) begin
                                    if (tetrominos[current_piece][rotation][15 - k]) begin
                                        board_piece_col = piece_x + (k % 4);
                                        board_piece_row = piece_y + (k / 4);
                                        if (board_piece_col >= 0 && board_piece_col < COLS && 
                                            board_piece_row >= 0 && board_piece_row < ROWS) begin
                                            case (piece_color(current_piece))
                                                3'b100: grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                3'b010: grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                3'b001: grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                3'b110: begin
                                                    grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                    grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                end
                                                3'b101: begin
                                                    grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                    grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                end
                                                3'b011: begin
                                                    grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                    grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                end
                                                3'b111: begin
                                                    grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                    grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                    grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
                                                end
                                            endcase
                                        end
                                    end
                                end

                                // Line clearing logic
                                lines = 0;
                                for (row = 0; row < ROWS; row = row + 1) begin
                                    full = 1;
                                    for (ctmp = 0; ctmp < COLS; ctmp = ctmp + 1) begin
                                        if (!(grid_r[row*COLS+ctmp] | grid_g[row*COLS+ctmp] | grid_b[row*COLS+ctmp]))
                                            full = 0;
                                    end
                                    if (full) begin
                                        lines = lines + 1;
                                        for (board_piece_row = row; board_piece_row > 0; board_piece_row = board_piece_row - 1) begin
                                            for (col = 0; col < COLS; col = col + 1) begin
                                                grid_r[board_piece_row*COLS + col] <= grid_r[(board_piece_row-1)*COLS + col];
                                                grid_g[board_piece_row*COLS + col] <= grid_g[(board_piece_row-1)*COLS + col];
                                                grid_b[board_piece_row*COLS + col] <= grid_b[(board_piece_row-1)*COLS + col];
                                            end
                                        end
                                        for (col = 0; col < COLS; col = col + 1) begin
                                            grid_r[col] <= 0;
                                            grid_g[col] <= 0;
                                            grid_b[col] <= 0;
                                        end
                                    end
                                end

                                // Update score & level
                                if (lines > 0) begin
                                    case (lines)
                                        1: score <= score + (40  * level);
                                        2: score <= score + (100 * level);
                                        3: score <= score + (300 * level);
                                        4: score <= score + (1200* level);
                                    endcase
                                    level <= level + 1;
                                end

                                state <= 0; // spawn next piece
                            end
                        end
                    end
                    
                    2: begin // Game over state
                        // Do nothing - game is frozen
                        piece_active <= 0;
                    end
                    
                    default: state <= 2; // Safety: go to game over state
                endcase
            end
        end
    end

    //Combinational output board
    integer bk;
    reg signed [8:0] out_col, out_row;
    always @(*) begin
        // Start with the settled blocks
        board_r = grid_r;
        board_g = grid_g;
        board_b = grid_b;
        
        // Only render active piece if game is not over and piece is active
        if (!game_over && piece_active && state == 1) begin
            for (bk = 0; bk < 16; bk = bk + 1) begin
                if (tetrominos[current_piece][rotation][15 - bk]) begin
                    out_col = piece_x + (bk % 4);
                    out_row = piece_y + (bk / 4);
                    if (out_col >= 0 && out_col < COLS && 
                        out_row >= 0 && out_row < ROWS) begin
                        case (piece_color(current_piece))
                            3'b100: board_r[out_row*COLS + out_col] = 1'b1;
                            3'b010: board_g[out_row*COLS + out_col] = 1'b1;
                            3'b001: board_b[out_row*COLS + out_col] = 1'b1;
                            3'b110: begin
                                board_r[out_row*COLS + out_col] = 1'b1;
                                board_g[out_row*COLS + out_col] = 1'b1;
                            end
                            3'b101: begin
                                board_r[out_row*COLS + out_col] = 1'b1;
                                board_b[out_row*COLS + out_col] = 1'b1;
                            end
                            3'b011: begin
                                board_g[out_row*COLS + out_col] = 1'b1;
                                board_b[out_row*COLS + out_col] = 1'b1;
                            end
                            3'b111: begin
                                board_r[out_row*COLS + out_col] = 1'b1;
                                board_g[out_row*COLS + out_col] = 1'b1;
                                board_b[out_row*COLS + out_col] = 1'b1;
                            end
                        endcase
                    end
                end
            end
        end
    end

endmodule
