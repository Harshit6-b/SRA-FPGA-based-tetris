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

    // Game state - use regular unsigned for piece position
    reg [5:0] piece_x, piece_y; // current piece position - UNSIGNED
    reg [2:0] current_piece, rotation;
    reg [199:0] grid_r, grid_g, grid_b; // settled blocks per color
    reg [31:0] counter; // gravity counter
    reg [1:0] state; // 0 = spawn, 1 = falling, 2 = game over
    reg [2:0] seq_index; // index for fixed sequence 0..6
    reg piece_active; // flag to indicate if there's an active piece

    // loop / index signals
    reg [7:0] row, col, k;
    reg [8:0] board_piece_col, board_piece_row; // For calculations

    // Button debouncing
    reg [3:0] cmd_prev;
    reg [3:0] cmd_edge;

    // Tetromino definitions
    reg [15:0] tetrominos [0:6][0:3];

    //LFSR for random numbers
    reg [7:0] lfsr;

    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'hAC; // seed
        else if (!game_over) // Only update LFSR when game is running
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    //Piece color assignment - fixed per piece type
    function [2:0] piece_color;
        input [2:0] piece;
        begin
            case (piece)
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
        input [5:0] test_x;
        input [5:0] test_y;
        integer kk;
        integer col_tmp, row_tmp;
        begin
            collision = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[piece_idx][rot_idx][15 - kk]) begin
                    col_tmp = test_x + (kk % 4);
                    row_tmp = test_y + (kk / 4);
                    
                    // Check if piece block is outside board boundaries
                    if (col_tmp < 0 || col_tmp >= COLS || 
                        row_tmp >= ROWS) begin
                        collision = 1;
                    end 
                    // Check if piece block collides with settled blocks
                    else if (row_tmp >= 0 && (grid_r[row_tmp*COLS + col_tmp] ||
                             grid_g[row_tmp*COLS + col_tmp] ||
                             grid_b[row_tmp*COLS + col_tmp])) begin
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
        input [5:0] test_x;
        input [5:0] test_y;
        integer kk;
        integer col_tmp, row_tmp;
        begin
            spawn_collision = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[piece_idx][rot_idx][15 - kk]) begin
                    col_tmp = test_x + (kk % 4);
                    row_tmp = test_y + (kk / 4);
                    
                    // Check collision with settled blocks on the visible board
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

    // Check if position would be valid for left movement
    function can_move_left;
        input [2:0] piece_idx;
        input [1:0] rot_idx;
        input [5:0] curr_x;
        input [5:0] curr_y;
        begin
            // Special check to prevent underflow
            if (curr_x == 0) begin
                // Check if leftmost blocks of piece would go negative
                can_move_left = !collision(piece_idx, rot_idx, 0, curr_y);
                // Additional check: make sure no part goes negative
                begin: check_loop
                    integer kk;
                    for (kk = 0; kk < 16; kk = kk + 1) begin
                        if (tetrominos[piece_idx][rot_idx][15 - kk]) begin
                            if ((kk % 4) == 0) begin // leftmost column of piece shape
                                can_move_left = 0;
                            end
                        end
                    end
                end
            end else begin
                can_move_left = !collision(piece_idx, rot_idx, curr_x - 1, curr_y);
            end
        end
    endfunction

    reg full;
    integer ctmp;

    //Main game logic
    reg [31:0] gravity_threshold;
    integer lines;
    reg [31:0] lines_cleared; // Total lines for scoring

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize tetrominos
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
            lines_cleared <= 0;

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
                state <= 2; // Stay in game over state
                piece_active <= 0;
            end else begin
                // synchronous gravity threshold calculation
                if (level <= 1)
                    gravity_threshold <= 25_000_000;
                else
                    gravity_threshold <= 25_000_000 / level;
                if (gravity_threshold < 2_000_000)
                    gravity_threshold <= 2_000_000;

                counter <= counter + 1;

                case (state)
                    0: begin // spawn new piece
                        // Select next piece from sequence
                        current_piece <= seq_index;
                        rotation <= 0;
                        piece_x <= 3; // spawn in middle
                        piece_y <= 0;
                        
                        // Check if spawn position is clear
                        if (spawn_collision(seq_index, 2'd0, 6'd3, 6'd0)) begin
                            // Game over - cannot spawn piece
                            game_over <= 1;
                            piece_active <= 0;
                            state <= 2; // Go to game over state
                        end else begin
                            // Safe to spawn
                            seq_index <= (seq_index == 6) ? 0 : seq_index + 1;
                            piece_active <= 1;
                            state <= 1;
                            counter <= 0; // Reset counter for new piece
                        end
                    end
                    
                    1: begin // falling state
                        // Left movement with proper boundary check
                        if (cmd_edge[3]) begin
                            if (piece_x > 0) begin
                                if (!collision(current_piece, rotation, piece_x - 1, piece_y))
                                    piece_x <= piece_x - 1;
                            end else begin
                                // Special handling for piece_x == 0
                                // Already at leftmost position, can't move further left
                            end
                        end
                        
                        // Right movement
                        if (cmd_edge[0]) begin
                            if (piece_x < COLS - 1 && !collision(current_piece, rotation, piece_x + 1, piece_y))
                                piece_x <= piece_x + 1;
                        end
                        
                        // Rotation with wall kick attempts
                        if (cmd_edge[2]) begin
                            // Try rotation at current position
                            if (!collision(current_piece, (rotation + 1) & 2'd3, piece_x, piece_y)) begin
                                rotation <= (rotation + 1) & 2'd3;
                            end
                            // Try wall kick right
                            else if (piece_x > 0 && !collision(current_piece, (rotation + 1) & 2'd3, piece_x - 1, piece_y)) begin
                                rotation <= (rotation + 1) & 2'd3;
                                piece_x <= piece_x - 1;
                            end
                            // Try wall kick left
                            else if (piece_x < COLS - 1 && !collision(current_piece, (rotation + 1) & 2'd3, piece_x + 1, piece_y)) begin
                                rotation <= (rotation + 1) & 2'd3;
                                piece_x <= piece_x + 1;
                            end
                        end
                        
                        // Soft drop (hold down)
                        if (cmd[1]) begin
                            if (!collision(current_piece, rotation, piece_x, piece_y + 1)) begin
                                piece_y <= piece_y + 1;
                                score <= score + 1; // 1 point per soft drop
                            end
                        end

                        // Gravity
                        if (counter >= gravity_threshold) begin
                            counter <= 0;
                            if (!collision(current_piece, rotation, piece_x, piece_y + 1)) begin
                                piece_y <= piece_y + 1;
                            end else begin
                                // Lock piece into grid
                                piece_active <= 0;
                                
                                // Place the piece
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

                                // Line clearing logic - process from bottom to top
                                lines = 0;
                                for (row = ROWS - 1; row >= 0; row = row - 1) begin
                                    full = 1;
                                    for (ctmp = 0; ctmp < COLS; ctmp = ctmp + 1) begin
                                        if (!(grid_r[row*COLS+ctmp] | grid_g[row*COLS+ctmp] | grid_b[row*COLS+ctmp]))
                                            full = 0;
                                    end
                                    if (full) begin
                                        lines = lines + 1;
                                        // Shift everything above this row down
                                        for (board_piece_row = row; board_piece_row > 0; board_piece_row = board_piece_row - 1) begin
                                            for (col = 0; col < COLS; col = col + 1) begin
                                                grid_r[board_piece_row*COLS + col] <= grid_r[(board_piece_row-1)*COLS + col];
                                                grid_g[board_piece_row*COLS + col] <= grid_g[(board_piece_row-1)*COLS + col];
                                                grid_b[board_piece_row*COLS + col] <= grid_b[(board_piece_row-1)*COLS + col];
                                            end
                                        end
                                        // Clear top row
                                        for (col = 0; col < COLS; col = col + 1) begin
                                            grid_r[col] <= 0;
                                            grid_g[col] <= 0;
                                            grid_b[col] <= 0;
                                        end
                                        row = row + 1; // Re-check this row since we shifted
                                    end
                                end

                                // Update score based on lines cleared
                                if (lines > 0) begin
                                    lines_cleared <= lines_cleared + lines;
                                    case (lines)
                                        1: score <= score + (40  * level);
                                        2: score <= score + (100 * level);
                                        3: score <= score + (300 * level);
                                        4: score <= score + (1200* level);
                                        default: score <= score + (40 * level);
                                    endcase
                                    
                                    // Level up every 10 lines
                                    if (lines_cleared >= level * 10) begin
                                        if (level < 15) // Cap at level 15
                                            level <= level + 1;
                                    end
                                end

                                state <= 0; // spawn next piece
                            end
                        end
                    end
                    
                    2: begin // Game over state
                        // Do nothing - game is frozen
                        piece_active <= 0;
                        game_over <= 1;
                    end
                    
                    default: state <= 0; // Safety: go back to spawn
                endcase
            end
        end
    end

    //Combinational output board
    integer bk;
    integer out_col, out_row;
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
