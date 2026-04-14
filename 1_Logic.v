module simple_tetris(
    input  wire        clk,
    input  wire        reset,
    input  wire [3:0]  cmd, // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down
    output reg  [199:0] board, // 20 rows x 10 columns (200 bits total)
    output reg         game_over
);

    parameter COLS = 10;
    parameter ROWS = 20;

    // Game state
    reg [4:0] piece_x, piece_y;   // current piece position
    reg [2:0] current_piece, rotation;
    reg [199:0] grid;             // settled pieces
    reg [31:0] counter;           // gravity counter
    reg [1:0] state;              // 0 = spawn, 1 = falling

    reg [2:0] seq_index;          // index for fixed sequence 0..6
    reg [2:0] next_piece;         // for safe spawn check

    // loop / index signals (sized to cover 0..199)
    reg [7:0] row, col, k;
    reg [7:0] board_row, board_col, board_k;
    reg [7:0] board_piece_col, board_piece_row;

    // Tetromino definitions: [piece][rotation][16 bits]
    reg [15:0] tetrominos [0:6][0:3];

    // --- LFSR for random numbers ---
    reg [7:0] lfsr;
    wire [3:0] rand_x;

    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'hAC; // seed
        else
            // maximal-length-ish feedback taps
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // simple mapping 0..9
    assign rand_x = lfsr % COLS;

    // --- collision function (checks current_piece & rotation) ---
    function collision;
        input [4:0] test_x, test_y;
        integer kk;
        integer col_tmp, row_tmp;
        begin
            collision = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[current_piece][rotation][15 - kk]) begin
                    col_tmp = test_x + (kk & 3);
                    row_tmp = test_y + (kk >> 2);
                    // out-of-bounds or overlap -> collision
                    if (col_tmp >= COLS || row_tmp >= ROWS) begin
                        collision = 1;
                    end else if (grid[row_tmp * COLS + col_tmp]) begin
                        collision = 1;
                    end
                end
            end
        end
    endfunction

    // --- collision check for next rotation ---
    function collision_rot;
        input [4:0] test_x, test_y;
        integer kk;
        integer col_tmp, row_tmp;
        reg [1:0] next_rot;
        begin
            collision_rot = 0;
            next_rot = (rotation + 1) & 3;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[current_piece][next_rot][15 - kk]) begin
                    col_tmp = test_x + (kk & 3);
                    row_tmp = test_y + (kk >> 2);
                    if (col_tmp >= COLS || row_tmp >= ROWS) begin
                        collision_rot = 1;
                    end else if (grid[row_tmp * COLS + col_tmp]) begin
                        collision_rot = 1;
                    end
                end
            end
        end
    endfunction

    // --- Sequential game logic + tetromino initialization on reset ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // initialize tetrominos in reset so that tools synthesize them correctly
            // I
            tetrominos[0][0] <= 16'b0000111100000000;
            tetrominos[0][1] <= 16'b0010001000100010;
            tetrominos[0][2] <= 16'b0000111100000000;
            tetrominos[0][3] <= 16'b0010001000100010;
            // O
            tetrominos[1][0] <= 16'b0000011001100000;
            tetrominos[1][1] <= 16'b0000011001100000;
            tetrominos[1][2] <= 16'b0000011001100000;
            tetrominos[1][3] <= 16'b0000011001100000;
            // T
            tetrominos[2][0] <= 16'b0000011100100000;
            tetrominos[2][1] <= 16'b0000010001100100;
            tetrominos[2][2] <= 16'b0000001001110000;
            tetrominos[2][3] <= 16'b0000010011000100;
            // L
            tetrominos[3][0] <= 16'b0000011100010000;
            tetrominos[3][1] <= 16'b0000011000100010;
            tetrominos[3][2] <= 16'b0000010001110000;
            tetrominos[3][3] <= 16'b0000100011000100;
            // J
            tetrominos[4][0] <= 16'b0000011101000000;
            tetrominos[4][1] <= 16'b0000010001000110;
            tetrominos[4][2] <= 16'b0000000101110000;
            tetrominos[4][3] <= 16'b0000011000100010;
            // S
            tetrominos[5][0] <= 16'b0000011000110000;
            tetrominos[5][1] <= 16'b0000001001100100;
            tetrominos[5][2] <= 16'b0000011000110000;
            tetrominos[5][3] <= 16'b0000001001100100;
            // Z
            tetrominos[6][0] <= 16'b0000001101100000;
            tetrominos[6][1] <= 16'b0000010011001000;
            tetrominos[6][2] <= 16'b0000001101100000;
            tetrominos[6][3] <= 16'b0000010011001000;

            // other state
            game_over <= 0;
            state <= 0;
            grid <= 0;
            counter <= 0;
            seq_index <= 0;
            current_piece <= 0;
            rotation <= 0;
            piece_x <= 0;
            piece_y <= 0;
        end else begin
            // increment gravity counter
            counter <= counter + 1;

            case (state)
                0: begin
                    // spawn next piece from simple sequence (seq_index)
                    next_piece <= seq_index;
                    seq_index <= (seq_index == 6) ? 0 : seq_index + 1;
                    current_piece <= next_piece;
                    rotation <= 0;

                    // safe clamping for spawn
                    if (next_piece == 0) begin
                        // I piece width 4 -> max x = 6
                        piece_x <= (rand_x > 6) ? 6 : {1'b0, rand_x};
                    end else if (next_piece == 1) begin
                        // O piece width 2 -> max x = 8
                        piece_x <= (rand_x > 8) ? 8 : {1'b0, rand_x};
                    end else begin
                        // others max width 3 -> max x = 7
                        piece_x <= (rand_x > 7) ? 7 : {1'b0, rand_x};
                    end
                    piece_y <= 0;

                    // Game over if spawn collides
                    if (collision(piece_x, piece_y)) begin
                        game_over <= 1;
                        // stay in spawn state (you could freeze or do other behavior)
                    end else begin
                        state <= 1;
                    end
                end

                1: begin
                    // Player commands - left, right, rotate, soft down
                    // Note: collision() handles bounds & overlap
                    if (cmd[3] && !collision(piece_x - 1, piece_y))
                        piece_x <= piece_x - 1;
                    if (cmd[0] && !collision(piece_x + 1, piece_y))
                        piece_x <= piece_x + 1;
                    if (cmd[2] && !collision_rot(piece_x, piece_y))
                        rotation <= (rotation + 1) & 3;
                    if (cmd[1] && !collision(piece_x, piece_y + 1))
                        piece_y <= piece_y + 1;

                    // Gravity (approx 1s at 25 MHz when counter reaches 25,000,000)
                    if (counter >= 25_000_000 - 1) begin
                        counter <= 0;
                        if (!collision(piece_x, piece_y + 1)) begin
                            piece_y <= piece_y + 1;
                        end else begin
                            // Lock current piece into grid
                            for (k = 0; k < 16; k = k + 1) begin
                                if (tetrominos[current_piece][rotation][15 - k]) begin
                                    board_piece_col = piece_x + (k & 3);
                                    board_piece_row = piece_y + (k >> 2);
                                    if (board_piece_col < COLS && board_piece_row < ROWS)
                                        grid[board_piece_row * COLS + board_piece_col] <= 1'b1;
                                end
                            end

                            // Line clearing: scan rows, if full then shift down
                            for (row = 0; row < ROWS; row = row + 1) begin
                                reg full;
                                integer ctmp;
                                full = 1'b1;
                                for (ctmp = 0; ctmp < COLS; ctmp = ctmp + 1) begin
                                    if (!grid[row*COLS + ctmp])
                                        full = 1'b0;
                                end
                                if (full) begin
                                    // shift rows above down by one
                                    for (board_row = row; board_row > 0; board_row = board_row - 1) begin
                                        for (col = 0; col < COLS; col = col + 1) begin
                                            grid[board_row*COLS + col] <= grid[(board_row-1)*COLS + col];
                                        end
                                    end
                                    // clear top row
                                    for (col = 0; col < COLS; col = col + 1) begin
                                        grid[col] <= 1'b0;
                                    end
                                end
                            end

                            // spawn next piece
                            state <= 0;
                        end
                    end
                end

                default: state <= 0;
            endcase
        end
    end

    // --- Combinational board generation (grid + falling piece overlay) ---
    always @(*) begin
        integer bk;
        board = grid; // start with settled grid
        for (bk = 0; bk < 16; bk = bk + 1) begin
            if (tetrominos[current_piece][rotation][15 - bk]) begin
                board_piece_col = piece_x + (bk & 3);
                board_piece_row = piece_y + (bk >> 2);
                if (board_piece_col < COLS && board_piece_row < ROWS)
                    board[board_piece_row * COLS + board_piece_col] = 1'b1;
            end
        end
    end

endmodule
