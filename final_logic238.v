
module simple_tetris(
    input clk,
    input reset,
    input [3:0] cmd, // 4'b1000=left, 4'b0001=right, 4'b0100=rotate, 4'b0010=down
    output reg [199:0] board, // 20 rows x 10 columns (200 bits total)
    output reg game_over,
    output reg [4:0] bram_addr,  
    output reg [15:0] bram_din,  
    output reg bram_wea
);

    parameter COLS = 10;
    parameter ROWS = 20;

    // Tetromino shapes (7 pieces, 4 rotations each)
    reg [15:0] tetrominos [0:6][0:3];

    initial begin
        // I piece
        tetrominos[0][0] = 16'b0000_1111_0000_0000;
        tetrominos[0][1] = 16'b0010_0010_0010_0010;
        tetrominos[0][2] = 16'b0000_1111_0000_0000;
        tetrominos[0][3] = 16'b0010_0010_0010_0010;

        // J piece
        tetrominos[1][0] = 16'b1000_1110_0000_0000;
        tetrominos[1][1] = 16'b0110_0100_0100_0000;
        tetrominos[1][2] = 16'b0000_1110_0010_0000;
        tetrominos[1][3] = 16'b0100_0100_1100_0000;

        // L piece
        tetrominos[2][0] = 16'b0010_1110_0000_0000;
        tetrominos[2][1] = 16'b0100_0100_0110_0000;
        tetrominos[2][2] = 16'b0000_1110_1000_0000;
        tetrominos[2][3] = 16'b1100_0100_0100_0000;

        // O piece
        tetrominos[3][0] = 16'b0110_0110_0000_0000;
        tetrominos[3][1] = 16'b0110_0110_0000_0000;
        tetrominos[3][2] = 16'b0110_0110_0000_0000;
        tetrominos[3][3] = 16'b0110_0110_0000_0000;

        // S piece
        tetrominos[4][0] = 16'b0110_1100_0000_0000;
        tetrominos[4][1] = 16'b0100_0110_0010_0000;
        tetrominos[4][2] = 16'b0110_1100_0000_0000;
        tetrominos[4][3] = 16'b0100_0110_0010_0000;

        // T piece
        tetrominos[5][0] = 16'b0100_1110_0000_0000;
        tetrominos[5][1] = 16'b0100_0110_0100_0000;
        tetrominos[5][2] = 16'b0000_1110_0100_0000;
        tetrominos[5][3] = 16'b0100_1100_0100_0000;

        // Z piece
        tetrominos[6][0] = 16'b1100_0110_0000_0000;
        tetrominos[6][1] = 16'b0010_0110_0100_0000;
        tetrominos[6][2] = 16'b1100_0110_0000_0000;
        tetrominos[6][3] = 16'b0010_0110_0100_0000;
    end

    // Game grid: 20 rows x 10 columns
    reg [COLS-1:0] grid [0:ROWS-1];

    // Current piece info
    reg [2:0] current_piece; // 0-6
    reg [3:0] piece_x;       // 0-9
    reg [4:0] piece_y;       // 0-19
    reg [1:0] rotation;      // 0-3

    // Game state: 0=spawn, 1=fall, 2=lock, 3=clear
    reg [1:0] state;
    reg [7:0] fall_counter;

    // Collision flags
    reg collision_left, collision_right, collision_down, collision_rotate;
    
    
 reg [9:0] temp_grid [0:ROWS-1];
    // Integer variables for collision detection (declared at module level)
    integer k, col, row;

    // Collision check combinational block
    always @(*) begin
        collision_left = 0;
        collision_right = 0;
        collision_down = 0;
        collision_rotate = 0;

        // Check left collision
        for (k = 0; k < 16; k = k + 1) begin
            if (tetrominos[current_piece][rotation][15 - k]) begin
                col = piece_x + (k & 3) - 1;
                row = piece_y + (k >> 2);
                if (col < 0 || col >= COLS || row >= ROWS || (col >= 0 && row < ROWS && grid[row][col]))
                    collision_left = 1;
            end
        end

        // Check right collision
        for (k = 0; k < 16; k = k + 1) begin
            if (tetrominos[current_piece][rotation][15 - k]) begin
                col = piece_x + (k & 3) + 1;
                row = piece_y + (k >> 2);
                if (col < 0 || col >= COLS || row >= ROWS || (col < COLS && row < ROWS && grid[row][col]))
                    collision_right = 1;
            end
        end

        // Check down collision
        for (k = 0; k < 16; k = k + 1) begin
            if (tetrominos[current_piece][rotation][15 - k]) begin
                col = piece_x + (k & 3);
                row = piece_y + (k >> 2) + 1;
                if (col < 0 || col >= COLS || row >= ROWS || (col < COLS && row < ROWS && grid[row][col]))
                    collision_down = 1;
            end
        end

        // Check rotate collision (next rotation)
        for (k = 0; k < 16; k = k + 1) begin
            if (tetrominos[current_piece][(rotation + 1) % 4][15 - k]) begin
                col = piece_x + (k & 3);
                row = piece_y + (k >> 2);
                if (col < 0 || col >= COLS || row >= ROWS || (col < COLS && row < ROWS && grid[row][col]))
                    collision_rotate = 1;
            end
        end
    end

    // Integer variables for main game logic
    
    integer lines_cleared = 0;
    integer spawn_k, spawn_col, spawn_row;
    integer lock_k, lock_col, lock_row;
    integer clear_row, clear_dest_row;
    integer board_row, board_col, board_k, board_piece_col, board_piece_row;

    // Main game logic
    always @(posedge clk) begin
        if (reset) begin
            game_over <= 0;
            board <= 0;
            state <= 0; // spawn
            fall_counter <= 0;
            current_piece <= 0;
            piece_x <= 4;
            piece_y <= 0;
            rotation <= 0;
            for (clear_row = 0; clear_row < ROWS; clear_row = clear_row + 1)
                grid[clear_row] <= 0;
        end else begin
            case (state)
                2'b00: begin // spawn
                    current_piece <= (current_piece + 1) % 7;
                    piece_x <= 4;
                    piece_y <= 0;
                    rotation <= 0;

                    // Check collision at spawn (game over)
                    game_over <= 0;
                    for (spawn_k = 0; spawn_k < 16; spawn_k = spawn_k + 1) begin
                        if (tetrominos[current_piece][rotation][15 - spawn_k]) begin
                            spawn_col = piece_x + (spawn_k & 3);
                            spawn_row = piece_y + (spawn_k >> 2);
                            if (spawn_col >= COLS || spawn_row >= ROWS || grid[spawn_row][spawn_col]) begin
                                game_over <= 1;
                            end
                        end
                    end

                    if (!game_over)
                        state <= 2'b01; // fall
                    else
                        state <= 2'b00; // stay in spawn (game over)
                end

                2'b01: begin // fall
                    // Handle input commands
                    if (cmd == 4'b1000 && !collision_left) // left
                        piece_x <= piece_x - 1;
                    else if (cmd == 4'b0001 && !collision_right) // right
                        piece_x <= piece_x + 1;
                    else if (cmd == 4'b0100 && !collision_rotate) // rotate
                        rotation <= (rotation + 1) % 4;
                    else if (cmd == 4'b0010 && !collision_down) // down
                        piece_y <= piece_y + 1;

                    // Auto fall
                    fall_counter <= fall_counter + 1;
                    if (fall_counter == 50) begin
                        fall_counter <= 0;
                        if (!collision_down)
                            piece_y <= piece_y + 1;
                        else
                            state <= 2'b10; // lock
                    end
                end

                2'b10: begin // lock piece
                    // Add piece to grid
                    for (lock_k = 0; lock_k < 16; lock_k = lock_k + 1) begin
                        if (tetrominos[current_piece][rotation][15 - lock_k]) begin
                            lock_col = piece_x + (lock_k & 3);
                            lock_row = piece_y + (lock_k >> 2);
                            if (lock_col < COLS && lock_row < ROWS)
                                grid[lock_row][lock_col] <= 1;
                        end
                    end
                    state <= 2'b11; // clear lines
                end

                2'b11: begin // clear lines
                    // Copy grid to temp_grid
                    for (clear_row = 0; clear_row < ROWS; clear_row = clear_row + 1)
                        temp_grid[clear_row] <= grid[clear_row];

                    // Check and clear full lines
                    clear_dest_row = ROWS - 1;
                    for (clear_row = ROWS - 1; clear_row >= 0; clear_row = clear_row - 1) begin
                        if (temp_grid[clear_row] == 10'b1111111111) begin
                            lines_cleared <= lines_cleared + 1;
                        end else begin
                            grid[clear_dest_row] <= temp_grid[clear_row];
                            clear_dest_row <= clear_dest_row - 1;
                        end
                    end

                    // Clear remaining top lines
                    for (clear_row = 0; clear_row <= clear_dest_row; clear_row = clear_row + 1)
                        grid[clear_row] <= 0;

                    state <= 2'b00; // spawn new piece
                end
            endcase
        end
    end

    // Update board output (combinational)
    always @(*) begin
        board = 0;
        // Copy grid to board
        for (board_row = 0; board_row < ROWS; board_row = board_row + 1) begin
            for (board_col = 0; board_col < COLS; board_col = board_col + 1) begin
                board[board_row * COLS + board_col] = grid[board_row][board_col];
            end
        end

        // Add current falling piece to board
        for (board_k = 0; board_k < 16; board_k = board_k + 1) begin
            if (tetrominos[current_piece][rotation][15 - board_k]) begin
                board_piece_col = piece_x + (board_k & 3);
                board_piece_row = piece_y + (board_k >> 2);
                if (board_piece_col < COLS && board_piece_row < ROWS)
                    board[board_piece_row * COLS + board_piece_col] = 1;
            end
        end
    end
	// BRAM Write State Machine
reg [2:0] bram_write_state;
reg bram_write_ready;

// BRAM Write Logic
always @(posedge clk) begin
    if (reset) begin
        // Reset BRAM write signals
        bram_addr <= 0;
        bram_din <= 0;
        bram_wea <= 0;
        bram_write_state <= 0;
        bram_write_ready <= 0;
    end else begin
        // Trigger BRAM write after line clear
        if (state == 2'b11 && !bram_write_ready) begin
            bram_write_ready <= 1;
            bram_write_state <= 0;
        end

        // BRAM Write Sequence - Updated for 16-bit writes
        if (bram_write_ready) begin
            bram_wea <= 1; // Enable write

            case (bram_write_state)
                0: begin // First 16 bits (199:184)
                    bram_addr <= 5'd0;
                    bram_din <= board[199:184];
                    bram_write_state <= bram_write_state + 1;
                end
                1: begin // Next 16 bits (183:168)
                    bram_addr <= 5'd1;
                    bram_din <= board[183:168];
                    bram_write_state <= bram_write_state + 1;
                end
                2: begin // Next 16 bits (167:152)
                    bram_addr <= 5'd2;
                    bram_din <= board[167:152];
                    bram_write_state <= bram_write_state + 1;
                end
                3: begin // Next 16 bits (151:136)
                    bram_addr <= 5'd3;
                    bram_din <= board[151:136];
                    bram_write_state <= bram_write_state + 1;
                end
                4: begin // Next 16 bits (135:120)
                    bram_addr <= 5'd4;
                    bram_din <= board[135:120];
                    bram_write_state <= bram_write_state + 1;
                end
                5: begin // Next 16 bits (119:104)
                    bram_addr <= 5'd5;
                    bram_din <= board[119:104];
                    bram_write_state <= bram_write_state + 1;
                end
                6: begin // Next 16 bits (103:88)
                    bram_addr <= 5'd6;
                    bram_din <= board[103:88];
                    bram_write_state <= bram_write_state + 1;
                end
                7: begin // Next 16 bits (87:72)
                    bram_addr <= 5'd7;
                    bram_din <= board[87:72];
                    bram_write_state <= bram_write_state + 1;
                end
                8: begin // Next 16 bits (71:56)
                    bram_addr <= 5'd8;
                    bram_din <= board[71:56];
                    bram_write_state <= bram_write_state + 1;
                end
                9: begin // Next 16 bits (55:40)
                    bram_addr <= 5'd9;
                    bram_din <= board[55:40];
                    bram_write_state <= bram_write_state + 1;
                end
                10: begin // Next 16 bits (39:24)
                    bram_addr <= 5'd10;
                    bram_din <= board[39:24];
                    bram_write_state <= bram_write_state + 1;
                end
                11: begin // Next 16 bits (23:8)
                    bram_addr <= 5'd11;
                    bram_din <= board[23:8];
                    bram_write_state <= bram_write_state + 1;
                end
                12: begin // Last 8 bits + padding (7:0)
                    bram_addr <= 5'd12;
                    bram_din <= {8'b0, board[7:0]}; // Pad with zeros to make 16 bits
                    bram_write_state <= bram_write_state + 1;
                end
                13: begin // Finish write sequence
                    bram_wea <= 0;
                    bram_write_ready <= 0;
                    bram_write_state <= 0;
                end
            endcase
        end
    end
endmodule
