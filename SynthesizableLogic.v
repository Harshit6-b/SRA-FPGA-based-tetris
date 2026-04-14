`timescale 1ns/1ps

module simple_tetris (
    input  wire        clk,       // board clock (e.g. 100 MHz on Arty A7)
    input  wire        reset,     // synchronous reset (active high)
    input  wire [3:0]  cmd,       // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down (one-shot pulses preferred)
    output reg  [199:0] board,    // 20 rows x 10 cols -> 200 bits
    output reg         game_over
);

    // ===== PARAMETERS =====
    parameter COLS = 10;
    parameter ROWS = 20;

    // Clock/fall tuning (set according to your board clock)
    parameter integer CLOCK_FREQ = 100_000_000; // Hz (e.g. 100 MHz)
    parameter integer FALL_HZ   = 4;            // pieces fall times per second
    localparam integer FALL_TICKS = CLOCK_FREQ / FALL_HZ; // clock ticks between automatic falls

    // ===== Tetromino definitions (16-bit 4x4 masks) =====
    reg [15:0] tetrominos [0:6][0:3];
    initial begin
        // I
        tetrominos[0][0] = 16'b0000_1111_0000_0000;
        tetrominos[0][1] = 16'b0010_0010_0010_0010;
        tetrominos[0][2] = tetrominos[0][0];
        tetrominos[0][3] = tetrominos[0][1];
        // J
        tetrominos[1][0] = 16'b1000_1110_0000_0000;
        tetrominos[1][1] = 16'b0110_0100_0100_0000;
        tetrominos[1][2] = 16'b0000_1110_0010_0000;
        tetrominos[1][3] = 16'b0100_0100_1100_0000;
        // L
        tetrominos[2][0] = 16'b0010_1110_0000_0000;
        tetrominos[2][1] = 16'b0100_0100_0110_0000;
        tetrominos[2][2] = 16'b0000_1110_1000_0000;
        tetrominos[2][3] = 16'b1100_0100_0100_0000;
        // O
        tetrominos[3][0] = 16'b0110_0110_0000_0000;
        tetrominos[3][1] = tetrominos[3][0];
        tetrominos[3][2] = tetrominos[3][0];
        tetrominos[3][3] = tetrominos[3][0];
        // S
        tetrominos[4][0] = 16'b0110_1100_0000_0000;
        tetrominos[4][1] = 16'b0100_0110_0010_0000;
        tetrominos[4][2] = tetrominos[4][0];
        tetrominos[4][3] = tetrominos[4][1];
        // T
        tetrominos[5][0] = 16'b0100_1110_0000_0000;
        tetrominos[5][1] = 16'b0100_0110_0100_0000;
        tetrominos[5][2] = 16'b0000_1110_0100_0000;
        tetrominos[5][3] = 16'b0100_1100_0100_0000;
        // Z
        tetrominos[6][0] = 16'b1100_0110_0000_0000;
        tetrominos[6][1] = 16'b0010_0110_0100_0000;
        tetrominos[6][2] = tetrominos[6][0];
        tetrominos[6][3] = tetrominos[6][1];
    end

    // ===== Game grid =====
    reg [COLS-1:0] grid [0:ROWS-1];
    integer r;
    initial begin
        for (r = 0; r < ROWS; r = r + 1)
            grid[r] = {COLS{1'b0}};
    end

    // ===== Current piece state =====
    reg [2:0] current_piece; // 0..6
    reg [3:0] piece_x;       // 0..9 allowed range (we keep 4 bits)
    reg [4:0] piece_y;       // 0..19 allowed range
    reg [1:0] rotation;      // 0..3

    // ===== FSM states =====
    localparam S_SPAWN  = 2'd0;
    localparam S_FALL   = 2'd1;
    localparam S_LOCK   = 2'd2;
    localparam S_CLEAR  = 2'd3;
    reg [1:0] state;

    // ===== Timing and randomness =====
    reg [31:0] tick_counter;
    reg fall_tick;
    reg [15:0] lfsr; // simple 16-bit LFSR for pseudo-random pieces

    // ===== Helpers =====
    integer i, j, k;
    reg coll; // temp collision flag

    // Function: test if tetromino at (px,py,rot) collides with grid or out-of-bounds
    function automatic bit collides_at;
        input [2:0] piece;
        input [1:0] rot;
        input integer px;
        input integer py;
        integer kk;
        integer cc;
        integer rr;
        begin
            collides_at = 0;
            for (kk = 0; kk < 16; kk = kk + 1) begin
                if (tetrominos[piece][rot][15-kk]) begin
                    cc = px + (kk & 2'b11);   // column within 0..3
                    rr = py + (kk >> 2);      // row within 0..3
                    // check bounds and grid occupancy
                    if (cc < 0 || cc >= COLS || rr < 0 || rr >= ROWS) begin
                        collides_at = 1;
                    end else begin
                        if (grid[rr][cc])
                            collides_at = 1;
                    end
                end
            end
        end
    endfunction

    // Synchronous clock divider + LFSR
    always @(posedge clk) begin
        if (reset) begin
            tick_counter <= 0;
            fall_tick <= 0;
            lfsr <= 16'hACE1; // seed
        end else begin
            if (tick_counter >= (FALL_TICKS - 1)) begin
                tick_counter <= 0;
                fall_tick <= 1;
            end else begin
                tick_counter <= tick_counter + 1;
                fall_tick <= 0;
            end
            // advance LFSR (simple)
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        end
    end

    // Main synchronous FSM: spawn, fall (move), lock, clear
    reg [4:0] clear_dest_row;
    reg [4:0] clear_row;
    reg [COLS-1:0] temp_grid [0:ROWS-1];
    reg [3:0] next_x;
    reg [4:0] next_y;
    reg [1:0] next_rot;
    reg [2:0] next_piece;

    always @(posedge clk) begin
        if (reset) begin
            // reset full game
            game_over <= 0;
            for (r = 0; r < ROWS; r = r + 1) grid[r] <= {COLS{1'b0}};
            state <= S_SPAWN;
            current_piece <= 0;
            piece_x <= 4;
            piece_y <= 0;
            rotation <= 0;
        end else begin
            // default no-op
            case (state)
                S_SPAWN: begin
                    // spawn a new piece from LFSR
                    current_piece <= lfsr[2:0]; // simple mapping
                    rotation <= 0;
                    piece_x <= 4; // spawn near center
                    piece_y <= 0;
                    // if spawn immediately collides -> game over (freeze)
                    if (collides_at(lfsr[2:0], 0, 4, 0)) begin
                        game_over <= 1;
                        state <= S_SPAWN; // stay but frozen; we won't change pieces while game_over
                    end else begin
                        state <= S_FALL;
                        game_over <= 0;
                    end
                end

                S_FALL: begin
                    // If game over, stay here
                    if (game_over) begin
                        state <= S_SPAWN;
                    end else begin
                        // Handle user commands (single-cycle pulses expected)
                        // Evaluate potential moves + collisions synchronously
                        next_x = piece_x;
                        next_y = piece_y;
                        next_rot = rotation;

                        // Left
                        if (cmd == 4'b1000) begin
                            if (!collides_at(current_piece, rotation, piece_x - 1, piece_y))
                                next_x = piece_x - 1;
                        end
                        // Right
                        else if (cmd == 4'b0001) begin
                            if (!collides_at(current_piece, rotation, piece_x + 1, piece_y))
                                next_x = piece_x + 1;
                        end
                        // Rotate (with small wall kicks)
                        else if (cmd == 4'b0100) begin
                            // try a set of horizontal offsets for simple wall-kicks
                            integer offsets [0:4];
                            offsets[0] = 0; offsets[1] = -1; offsets[2] = 1; offsets[3] = -2; offsets[4] = 2;
                            bit rotated_ok;
                            rotated_ok = 0;
                            for (i = 0; i < 5; i = i + 1) begin
                                if (!collides_at(current_piece, (rotation + 1) % 4, piece_x + offsets[i], piece_y)) begin
                                    next_rot = (rotation + 1) % 4;
                                    next_x = piece_x + offsets[i];
                                    rotated_ok = 1;
                                    disable i; // exit loop
                                end
                            end
                            // if none ok, keep rotation unchanged
                        end
                        // Soft drop
                        else if (cmd == 4'b0010) begin
                            if (!collides_at(current_piece, rotation, piece_x, piece_y + 1))
                                next_y = piece_y + 1;
                            else begin
                                // if immediate soft-drop collides, lock next cycle
                                next_y = piece_y;
                                state <= S_LOCK;
                            end
                        end

                        // Apply user-move results synchronously
                        piece_x <= next_x;
                        piece_y <= next_y;
                        rotation <= next_rot;

                        // handle automatic fall
                        if (fall_tick) begin
                            if (!collides_at(current_piece, rotation, piece_x, piece_y + 1)) begin
                                piece_y <= piece_y + 1;
                            end else begin
                                state <= S_LOCK;
                            end
                        end
                    end
                end

                S_LOCK: begin
                    // Commit current piece blocks into grid
                    for (k = 0; k < 16; k = k + 1) begin
                        if (tetrominos[current_piece][rotation][15-k]) begin
                            integer ccol, rrow;
                            ccol = piece_x + (k & 2'b11);
                            rrow = piece_y + (k >> 2);
                            if (ccol >= 0 && ccol < COLS && rrow >= 0 && rrow < ROWS)
                                grid[rrow][ccol] <= 1'b1;
                        end
                    end
                    // go check for clear
                    state <= S_CLEAR;
                end

                S_CLEAR: begin
                    // copy grid to temp
                    for (r = 0; r < ROWS; r = r + 1)
                        temp_grid[r] <= grid[r];

                    clear_dest_row = ROWS - 1;
                    for (r = ROWS - 1; r >= 0; r = r - 1) begin
                        if (temp_grid[r] == {COLS{1'b1}}) begin
                            // full row: just drop it (do not copy)
                        end else begin
                            grid[clear_dest_row] <= temp_grid[r];
                            clear_dest_row = clear_dest_row - 1;
                        end
                        if (r == 0) break; // safe exit for unsigned loop
                    end
                    // clear remaining top rows
                    for (r = 0; r <= clear_dest_row; r = r + 1)
                        grid[r] <= {COLS{1'b0}};

                    // spawn next piece
                    state <= S_SPAWN;
                end

                default: state <= S_SPAWN;
            endcase
        end
    end

    // Board output (combinational overlay of grid + current piece)
    always @(*) begin
        // clear board
        board = {200{1'b0}};
        // write grid
        for (r = 0; r < ROWS; r = r + 1) begin
            for (j = 0; j < COLS; j = j + 1) begin
                board[r * COLS + j] = grid[r][j];
            end
        end
        // overlay current falling piece (if not game_over)
        if (!game_over) begin
            for (k = 0; k < 16; k = k + 1) begin
                if (tetrominos[current_piece][rotation][15-k]) begin
                    integer bc, br;
                    bc = piece_x + (k & 2'b11);
                    br = piece_y + (k >> 2);
                    if (bc >= 0 && bc < COLS && br >= 0 && br < ROWS)
                        board[br * COLS + bc] = 1'b1;
                end
            end
        end
    end

endmodule
