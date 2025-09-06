//module simple_tetris(
//    input  wire clk,
//    input  wire reset,
//    input  wire [3:0] cmd, // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down
//    output reg  [199:0] board_r, // Red plane (20x10)
//    output reg  [199:0] board_g, // Green plane
//    output reg  [199:0] board_b, // Blue plane
//    output reg  game_over,
//    output reg [15:0] score,
//    output reg [7:0]  level
//);

//    parameter COLS = 10;
//    parameter ROWS = 20;

//    // Game state
//    reg [4:0] piece_x, piece_y; // current piece position
//    reg [2:0] current_piece, rotation;
//    reg [199:0] grid_r, grid_g, grid_b; // settled blocks per color
//    reg [31:0] counter; // gravity counter
//    reg [1:0] state; // 0 = spawn, 1 = falling
//    reg [2:0] seq_index; // index for fixed sequence 0..6
//    reg [2:0] next_piece; // for safe spawn check

//    // loop / index signals
//    reg [7:0] row, col, k;
//    reg [7:0] board_piece_col, board_piece_row;

//    // Tetromino definitions
//    reg [15:0] tetrominos [0:6][0:3];

//    // --- LFSR for random numbers ---
//    reg [7:0] lfsr;
//    wire [3:0] rand_x;

//    always @(posedge clk or posedge reset) begin
//        if (reset)
//            lfsr <= 8'hAC; // seed
//        else
//            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
//    end

//    assign rand_x = lfsr % COLS;

//    // --- Piece color assignment ---
//    function [2:0] piece_color;
//        input [2:0] piece;
//        begin
//            case (piece)
//                3'd0: piece_color = 3'b011; // I = Cyan
//                3'd1: piece_color = 3'b110; // O = Yellow
//                3'd2: piece_color = 3'b101; // T = Magenta
//                3'd3: piece_color = 3'b100; // L = Red
//                3'd4: piece_color = 3'b001; // J = Blue
//                3'd5: piece_color = 3'b010; // S = Green
//                3'd6: piece_color = 3'b111; // Z = White
//                default: piece_color = 3'b111; // fallback
//            endcase
//        end
//    endfunction

//    // --- collision function ---
//    function collision;
//        input [4:0] test_x, test_y;
//        integer kk;
//        integer col_tmp, row_tmp;
//        begin
//            collision = 0;
//            for (kk = 0; kk < 16; kk = kk + 1) begin
//                if (tetrominos[current_piece][rotation][15 - kk]) begin
//                    col_tmp = test_x + (kk & 3);
//                    row_tmp = test_y + (kk >> 2);
//                    if (col_tmp < 0 || col_tmp >= COLS || row_tmp >= ROWS) begin
//                        collision = 1;
//                    end else if (grid_r[row_tmp*COLS + col_tmp] ||
//                                 grid_g[row_tmp*COLS + col_tmp] ||
//                                 grid_b[row_tmp*COLS + col_tmp]) begin
//                        collision = 1;
//                    end
//                end
//            end
//        end
//    endfunction

//    // --- collision check for rotation ---
//    function collision_rot;
//        input [4:0] test_x, test_y;
//        integer kk;
//        integer col_tmp, row_tmp;
//        reg [1:0] next_rot;
//        begin
//            collision_rot = 0;
//            next_rot = (rotation + 1) & 3;
//            for (kk = 0; kk < 16; kk = kk + 1) begin
//                if (tetrominos[current_piece][next_rot][15 - kk]) begin
//                    col_tmp = test_x + (kk & 3);
//                    row_tmp = test_y + (kk >> 2);
//                    if (col_tmp < 0 || col_tmp >= COLS || row_tmp >= ROWS) begin
//                        collision_rot = 1;
//                    end else if (grid_r[row_tmp*COLS + col_tmp] ||
//                                 grid_g[row_tmp*COLS + col_tmp] ||
//                                 grid_b[row_tmp*COLS + col_tmp]) begin
//                        collision_rot = 1;
//                    end
//                end
//            end
//        end
//    endfunction

//    reg full;
//    integer ctmp;

//    // level & scoring
//    reg [31:0] gravity_threshold;

//    // gravity threshold depends on level
//    always @(*) begin
//        gravity_threshold = 25_000_000 / (level == 0 ? 1 : level);
//        if (gravity_threshold < 2_000_000) // cap minimum delay
//            gravity_threshold = 2_000_000;
//    end
//    integer lines;
//    // --- Main game logic ---
//    always @(posedge clk or posedge reset) begin
//        if (reset) begin
//            // Initialize tetrominos
//            tetrominos[0][0] <= 16'b0000111100000000;
//            tetrominos[0][1] <= 16'b0010001000100010;
//            tetrominos[0][2] <= 16'b0000111100000000;
//            tetrominos[0][3] <= 16'b0010001000100010;

//            tetrominos[1][0] <= 16'b0000011001100000;
//            tetrominos[1][1] <= 16'b0000011001100000;
//            tetrominos[1][2] <= 16'b0000011001100000;
//            tetrominos[1][3] <= 16'b0000011001100000;

//            tetrominos[2][0] <= 16'b0000011100100000;
//            tetrominos[2][1] <= 16'b0000010001100100;
//            tetrominos[2][2] <= 16'b0000001001110000;
//            tetrominos[2][3] <= 16'b0000010011000100;

//            tetrominos[3][0] <= 16'b0000011100010000;
//            tetrominos[3][1] <= 16'b0000011000100010;
//            tetrominos[3][2] <= 16'b0000010001110000;
//            tetrominos[3][3] <= 16'b0000100011000100;

//            tetrominos[4][0] <= 16'b0000011101000000;
//            tetrominos[4][1] <= 16'b0000010001000110;
//            tetrominos[4][2] <= 16'b0000000101110000;
//            tetrominos[4][3] <= 16'b0000011000100010;

//            tetrominos[5][0] <= 16'b0000011000110000;
//            tetrominos[5][1] <= 16'b0000001001100100;
//            tetrominos[5][2] <= 16'b0000011000110000;
//            tetrominos[5][3] <= 16'b0000001001100100;

//            tetrominos[6][0] <= 16'b0000001101100000;
//            tetrominos[6][1] <= 16'b0000010011001000;
//            tetrominos[6][2] <= 16'b0000001101100000;
//            tetrominos[6][3] <= 16'b0000010011001000;

//            game_over <= 0;
//            state <= 0;
//            grid_r <= 0;
//            grid_g <= 0;
//            grid_b <= 0;
//            counter <= 0;
//            seq_index <= 0;
//            current_piece <= 0;
//            rotation <= 0;
//            piece_x <= 0;
//            piece_y <= 0;

//            score <= 0;
//            level <= 1;
//        end else begin
//            counter <= counter + 1;
//            case (state)
//                0: begin // spawn new piece
//                    next_piece <= seq_index;
//                    seq_index <= (seq_index == 6) ? 0 : seq_index + 1;
//                    current_piece <= next_piece;
//                    rotation <= 0;
//                    piece_x <= 3; // fixed safe spawn
//                    piece_y <= 0;
//                    if (collision(piece_x, piece_y)) game_over <= 1;
//                    else state <= 1;
//                end
//                1: begin
//                    if (cmd[3] && !collision(piece_x - 1, piece_y)) piece_x <= piece_x - 1;
//                    if (cmd[0] && !collision(piece_x + 1, piece_y)) piece_x <= piece_x + 1;
//                    if (cmd[2] && !collision_rot(piece_x, piece_y)) rotation <= (rotation + 1) & 3;
//                    if (cmd[1] && !collision(piece_x, piece_y + 1)) piece_y <= piece_y + 1;

//                    if (counter >= gravity_threshold - 1) begin
//                        counter <= 0;
//                        if (!collision(piece_x, piece_y + 1)) begin
//                            piece_y <= piece_y + 1;
//                        end else begin
//                            // lock piece into grid with its color
//                            for (k = 0; k < 16; k = k + 1) begin
//                                if (tetrominos[current_piece][rotation][15 - k]) begin
//                                    board_piece_col = piece_x + (k & 3);
//                                    board_piece_row = piece_y + (k >> 2);
//                                    if (board_piece_col < COLS && board_piece_row < ROWS) begin
//                                        case (piece_color(current_piece))
//                                            3'b100: grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            3'b010: grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            3'b001: grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            3'b110: begin
//                                                grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                                grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            end
//                                            3'b101: begin
//                                                grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                                grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            end
//                                            3'b011: begin
//                                                grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                                grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            end
//                                            3'b111: begin
//                                                grid_r[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                                grid_g[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                                grid_b[board_piece_row*COLS + board_piece_col] <= 1'b1;
//                                            end
//                                        endcase
//                                    end
//                                end
//                            end

//                            // line clear
                            
//                            lines = 0;
//                            for (row = 0; row < ROWS; row = row + 1) begin
//                                full = 1;
//                                for (ctmp = 0; ctmp < COLS; ctmp = ctmp + 1) begin
//                                    if (!(grid_r[row*COLS+ctmp] | grid_g[row*COLS+ctmp] | grid_b[row*COLS+ctmp]))
//                                        full = 0;
//                                end
//                                if (full) begin
//                                    lines = lines + 1;
//                                    for (board_piece_row = row; board_piece_row > 0; board_piece_row = board_piece_row - 1) begin
//                                        for (col = 0; col < COLS; col = col + 1) begin
//                                            grid_r[board_piece_row*COLS + col] <= grid_r[(board_piece_row-1)*COLS + col];
//                                            grid_g[board_piece_row*COLS + col] <= grid_g[(board_piece_row-1)*COLS + col];
//                                            grid_b[board_piece_row*COLS + col] <= grid_b[(board_piece_row-1)*COLS + col];
//                                        end
//                                    end
//                                    for (col = 0; col < COLS; col = col + 1) begin
//                                        grid_r[col] <= 0;
//                                        grid_g[col] <= 0;
//                                        grid_b[col] <= 0;
//                                    end
//                                end
//                            end

//                            // update score & level
//                            if (lines > 0) begin
//                                case (lines)
//                                    1: score <= score + (40  * level);
//                                    2: score <= score + (100 * level);
//                                    3: score <= score + (300 * level);
//                                    4: score <= score + (1200* level);
//                                endcase
//                                // increment level by number of cleared lines (1 level per cleared line)
//                                level <= level + lines;
//                            end

//                            state <= 0;
//                        end
//                    end
//                end
//            endcase
//        end
//    end

//    // --- Combinational output board (grid + falling piece overlay) ---
//    integer bk;
//    always @(*) begin
//        board_r = grid_r;
//        board_g = grid_g;
//        board_b = grid_b;
//        for (bk = 0; bk < 16; bk = bk + 1) begin
//            if (tetrominos[current_piece][rotation][15 - bk]) begin
//                board_piece_col = piece_x + (bk & 3);
//                board_piece_row = piece_y + (bk >> 2);
//                if (board_piece_col < COLS && board_piece_row < ROWS) begin
//                    case (piece_color(current_piece))
//                        3'b100: board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        3'b010: board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        3'b001: board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        3'b110: begin
//                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
//                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        end
//                        3'b101: begin
//                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
//                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        end
//                        3'b011: begin
//                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
//                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        end
//                        3'b111: begin
//                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
//                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
//                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
//                        end
//                    endcase
//                end
//            end
//        end
//    end

//endmodule

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
    reg [4:0] piece_x, piece_y; // current piece position
    reg [2:0] current_piece, rotation;
    reg [199:0] grid_r, grid_g, grid_b; // settled blocks per color
    reg [31:0] counter; // gravity counter
    reg [1:0] state; // 0 = spawn, 1 = falling
    reg [2:0] seq_index; // index for fixed sequence 0..6
    reg [2:0] next_piece; // for safe spawn check

    // loop / index signals
    reg [7:0] row, col, k;
    reg [7:0] board_piece_col, board_piece_row;

    // Tetromino definitions
    reg [15:0] tetrominos [0:6][0:3];

    // --- LFSR for random numbers ---
    reg [7:0] lfsr;
    wire [3:0] rand_x;

    always @(posedge clk or posedge reset) begin
        if (reset)
            lfsr <= 8'hAC; // seed
        else
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    assign rand_x = lfsr % COLS;

    // --- Piece color assignment ---
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

    // --- collision function ---
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
                    if (col_tmp < 0 || col_tmp >= COLS || row_tmp >= ROWS) begin
                        collision = 1;
                    end else if (grid_r[row_tmp*COLS + col_tmp] ||
                                 grid_g[row_tmp*COLS + col_tmp] ||
                                 grid_b[row_tmp*COLS + col_tmp]) begin
                        collision = 1;
                    end
                end
            end
        end
    endfunction

    // --- collision check for rotation ---
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
                    if (col_tmp < 0 || col_tmp >= COLS || row_tmp >= ROWS) begin
                        collision_rot = 1;
                    end else if (grid_r[row_tmp*COLS + col_tmp] ||
                                 grid_g[row_tmp*COLS + col_tmp] ||
                                 grid_b[row_tmp*COLS + col_tmp]) begin
                        collision_rot = 1;
                    end
                end
            end
        end
    endfunction

    reg full;
    integer ctmp;

    // --- Main game logic ---
    reg [31:0] gravity_threshold;
    integer lines;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Initialize tetrominos
            tetrominos[0][0] <= 16'b0000111100000000;
            tetrominos[0][1] <= 16'b0010001000100010;
            tetrominos[0][2] <= 16'b0000111100000000;
            tetrominos[0][3] <= 16'b0010001000100010;

            tetrominos[1][0] <= 16'b0000011001100000;
            tetrominos[1][1] <= 16'b0000011001100000;
            tetrominos[1][2] <= 16'b0000011001100000;
            tetrominos[1][3] <= 16'b0000011001100000;

            tetrominos[2][0] <= 16'b0000011100100000;
            tetrominos[2][1] <= 16'b0000010001100100;
            tetrominos[2][2] <= 16'b0000001001110000;
            tetrominos[2][3] <= 16'b0000010011000100;

            tetrominos[3][0] <= 16'b0000011100010000;
            tetrominos[3][1] <= 16'b0000011000100010;
            tetrominos[3][2] <= 16'b0000010001110000;
            tetrominos[3][3] <= 16'b0000100011000100;

            tetrominos[4][0] <= 16'b0000011101000000;
            tetrominos[4][1] <= 16'b0000010001000110;
            tetrominos[4][2] <= 16'b0000000101110000;
            tetrominos[4][3] <= 16'b0000011000100010;

            tetrominos[5][0] <= 16'b0000011000110000;
            tetrominos[5][1] <= 16'b0000001001100100;
            tetrominos[5][2] <= 16'b0000011000110000;
            tetrominos[5][3] <= 16'b0000001001100100;

            tetrominos[6][0] <= 16'b0000001101100000;
            tetrominos[6][1] <= 16'b0000010011001000;
            tetrominos[6][2] <= 16'b0000001101100000;
            tetrominos[6][3] <= 16'b0000010011001000;

            game_over <= 0;
            state <= 0;
            grid_r <= 0;
            grid_g <= 0;
            grid_b <= 0;
            counter <= 0;
            seq_index <= 0;
            current_piece <= 0;
            rotation <= 0;
            piece_x <= 0;
            piece_y <= 0;

            score <= 0;
            level <= 1;
            gravity_threshold <= 25_000_000; // initial threshold
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
                    next_piece <= seq_index;
                    seq_index <= (seq_index == 6) ? 0 : seq_index + 1;
                    current_piece <= next_piece;
                    rotation <= 0;
                    piece_x <= 3; // fixed safe spawn
                    piece_y <= 0;
                    if (collision(piece_x, piece_y)) game_over <= 1;
                    else state <= 1;
                end
                1: begin
                    if (cmd[3] && !collision(piece_x - 1, piece_y)) piece_x <= piece_x - 1;
                    if (cmd[0] && !collision(piece_x + 1, piece_y)) piece_x <= piece_x + 1;
                    if (cmd[2] && !collision_rot(piece_x, piece_y)) rotation <= (rotation + 1) & 3;
                    if (cmd[1] && !collision(piece_x, piece_y + 1)) piece_y <= piece_y + 1;

                    if (counter >= gravity_threshold - 1) begin
                        counter <= 0;
                        if (!collision(piece_x, piece_y + 1)) begin
                            piece_y <= piece_y + 1;
                        end else begin
                            // lock piece into grid with its color
                            for (k = 0; k < 16; k = k + 1) begin
                                if (tetrominos[current_piece][rotation][15 - k]) begin
                                    board_piece_col = piece_x + (k & 3);
                                    board_piece_row = piece_y + (k >> 2);
                                    if (board_piece_col < COLS && board_piece_row < ROWS) begin
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

                            // line clear
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

                            // update score & level
                            if (lines > 0) begin
                                case (lines)
                                    1: score <= score + (40  * level);
                                    2: score <= score + (100 * level);
                                    3: score <= score + (300 * level);
                                    4: score <= score + (1200* level);
                                endcase
                                // increment level by number of cleared lines (1 level per cleared line)
                                level <= level + 1;
                            end

                            state <= 0; // back to spawn new piece
                        end
                    end
                end
            endcase
        end
    end

    // --- Combinational output board (grid + falling piece overlay) ---
    integer bk;
    always @(*) begin
        board_r = grid_r;
        board_g = grid_g;
        board_b = grid_b;
        for (bk = 0; bk < 16; bk = bk + 1) begin
            if (tetrominos[current_piece][rotation][15 - bk]) begin
                board_piece_col = piece_x + (bk & 3);
                board_piece_row = piece_y + (bk >> 2);
                if (board_piece_col < COLS && board_piece_row < ROWS) begin
                    case (piece_color(current_piece))
                        3'b100: board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
                        3'b010: board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
                        3'b001: board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
                        3'b110: begin
                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
                        end
                        3'b101: begin
                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
                        end
                        3'b011: begin
                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
                        end
                        3'b111: begin
                            board_r[board_piece_row*COLS + board_piece_col] = 1'b1;
                            board_g[board_piece_row*COLS + board_piece_col] = 1'b1;
                            board_b[board_piece_row*COLS + board_piece_col] = 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule
