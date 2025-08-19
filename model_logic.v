module game_logic(
    input clk,
    input reset,
    input [3:0] key, // Fixed: was 'bKey' in the main code but 'key' in port declaration
    input game_tick,
    output reg [863:0] field_flat, // Missing comma fixed
    output reg [2:0] current_piece,
    output reg [3:0] current_x,
    output reg [4:0] current_y,
    output reg [1:0] current_rotation,
    output reg [15:0] score,
    output reg game_over,
    output reg [3:0] lines_clearing,
    output wire [63:0] piece_data_out
);

reg [3:0] field [17:0][11:0];
// Function to flatten the field for output
function [863:0] flatten_field;
	integer y, x; 
	begin 
		flatten_field = 864'd0;
		for (y = 0; y < 18; y = y + 1) begin 
			for (x = 0; x < 12; x = x + 1) begin 
				field_flat[((y*12 + x)*4) + 3 : (y*12 + x)*4] = field[y][x];
			end 
		end 
	end 
endfunction
always @(*) begin 
	field_flat = flatten_field(); 
end

reg [15:0] tetromino [6:0];
initial begin
    tetromino[0] = 16'b0010001000100010; // I 
    tetromino[1] = 16'b0010011000100000; // T
    tetromino[2] = 16'b0000011001100000; // O
    tetromino[3] = 16'b0010011001000000; // S
    tetromino[4] = 16'b0100011000100000; // Z
    tetromino[5] = 16'b0100010001100000; // J
    tetromino[6] = 16'b0010001001100000; // L 
end

parameter SPAWN = 3'd0, FALLING = 3'd1, LOCK = 3'd2, CLEAR_CHECK = 3'd3, 
          CLEAR_REMOVE = 3'd5, GAME_OVER_STATE = 3'd6;
reg [2:0] game_state;

reg [5:0] speed;
reg [5:0] speed_counter;
reg force_down;
reg [3:0] clear_timer;
reg [3:0] piece_count;

// Input edge detection - Fixed variable names
reg [3:0] key_prev; // Changed from bKey_prev to match input port
wire [3:0] key_edge = key & ~key_prev; // Changed from bKey to key
reg rotate_hold;

// Random piece generation 
reg [7:0] lfsr;
wire [2:0] next_piece = lfsr[2:0] < 7 ? lfsr[2:0] : 3'd0;

// Line clearing
reg [17:0] lines_full;
reg [3:0] lines_cleared_count;

function [3:0] rotate_coords;
    input [1:0] px, py, rotation;
    begin
        case (rotation)
            2'd0: rotate_coords = py * 4 + px;           // 0 degrees
            2'd1: rotate_coords = 12 + py - (px * 4);    // 90 degrees
            2'd2: rotate_coords = 15 - (py * 4) - px;    // 180 degrees
            2'd3: rotate_coords = 3 - py + (px * 4);     // 270 degrees
        endcase
    end
endfunction

// Main collision detection function
function does_piece_fit;
    input [2:0] test_piece_type;
    input [3:0] test_x;
    input [4:0] test_y;
    input [1:0] test_rotation;
    
    integer px, py, fx, fy, pi;
    begin
        does_piece_fit = 1'b1;  // Assume it fits initially
        
        for (px = 0; px < 4; px = px + 1) begin
            for (py = 0; py < 4; py = py + 1) begin
                pi = rotate_coords(px, py, test_rotation);
                
                // Check if this piece bit is set
                if (tetromino[test_piece_type][pi]) begin
                    fx = test_x + px;
                    fy = test_y + py;
                    
                    // Check boundaries
                    if (fx < 0 || fx >= 12 || fy < 0 || fy >= 18) begin
                        does_piece_fit = 1'b0;
                    end 
                    // Check collision with existing pieces
                    else if (field[fy][fx] != 4'd0) begin
                        does_piece_fit = 1'b0;
                    end
                end
            end
        end
    end
endfunction

wire collision_left = !does_piece_fit(current_piece, current_x - 1, current_y, current_rotation);
wire collision_right = !does_piece_fit(current_piece, current_x + 1, current_y, current_rotation);
wire collision_down = !does_piece_fit(current_piece, current_x, current_y + 1, current_rotation);
wire collision_rotate = !does_piece_fit(current_piece, current_x, current_y, current_rotation + 1);

assign piece_data_out = {tetromino[current_piece], current_x, current_y, current_rotation, current_piece};

task lock_piece_to_field;
    integer px, py, fx, fy, pi;
    begin
        for (px = 0; px < 4; px = px + 1) begin
            for (py = 0; py < 4; py = py + 1) begin
                pi = rotate_coords(px, py, current_rotation);
                if (tetromino[current_piece][pi]) begin
                    fx = current_x + px;
                    fy = current_y + py;
                    if (fy >= 0 && fy < 18 && fx >= 0 && fx < 12) begin
                        field[fy][fx] <= current_piece + 1;
                    end
                end
            end
        end
    end
endtask

task check_completed_lines;
    integer y, x;
    reg line_complete;
    begin
        lines_cleared_count <= 4'd0;
        lines_full <= 18'd0;
        
        for (y = 0; y < 17; y = y + 1) begin // Don't check bottom border
            line_complete = 1'b1;
            for (x = 1; x < 11; x = x + 1) begin // Don't check side borders
                if (field[y][x] == 4'd0) begin
                    line_complete = 1'b0;
                end
            end
            
            if (line_complete) begin
                lines_full[y] <= 1'b1;
                lines_cleared_count <= lines_cleared_count + 1;
                
                // Mark line for flashing
                for (x = 1; x < 11; x = x + 1) begin
                    field[y][x] <= 4'd8; // Flash marker
                end
            end
        end
    end
endtask

// Task to remove completed lines - CORRECTED VERSION
task remove_completed_lines;
    integer src_y, dst_y, x, clear_line;
    begin
        dst_y = 16; // Start from bottom (excluding border)
        
        for (src_y = 16; src_y >= 0; src_y = src_y - 1) begin
            if (!lines_full[src_y]) begin
                // Copy this line down
                for (x = 1; x < 11; x = x + 1) begin
                    field[dst_y][x] <= field[src_y][x];
                end
                dst_y = dst_y - 1;
            end
        end
        
        // Clear remaining top lines - Fixed logic
        for (clear_line = 0; clear_line <= 16; clear_line = clear_line + 1) begin
            if (clear_line < dst_y) begin
                for (x = 1; x < 11; x = x + 1) begin
                    field[clear_line][x] <= 4'd0;
                end
            end
        end
        
        lines_full <= 18'd0;
    end
endtask

always @(posedge clk) begin
    if (reset) begin
        // Initialize game
        game_state <= SPAWN;
        current_piece <= 3'd0;
        current_x <= 4'd6;  // Center of 12-wide field
        current_y <= 5'd0;
        current_rotation <= 2'd0;
        score <= 16'
        game_over <= 1'b0;
        speed <= 6'd20;
        speed_counter <= 6'd0;
        force_down <= 1'b0;
        clear_timer <= 4'd0;
        piece_count <= 4'd0;
        lines_clearing <= 4'd0;
        lines_cleared_count <= 4'd0;
        rotate_hold <= 1'b1;
        lfsr <= 8'hA5;
        key_prev <= 4'd0; // Fixed variable name
        
        // Initialize field with borders
        integer x, y;
        for (y = 0; y < 18; y = y + 1) begin
            for (x = 0; x < 12; x = x + 1) begin
                if (x == 0 || x == 11 || y == 17)
                    field[y][x] <= 4'd9; // Border
                else
                    field[y][x] <= 4'd0; // Empty
            end
        end
    end else begin
        key_prev <= key; // Fixed variable name
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        
        // Speed control
        speed_counter <= speed_counter + 1;
        if (speed_counter >= speed) begin
            speed_counter <= 6'd0;
            force_down <= 1'b1;
        end else begin
            force_down <= 1'b0;
        end
        
        case (game_state)
            SPAWN: begin
                // Spawn new piece
                current_piece <= next_piece;
                current_x <= 4'd6;
                current_y <= 5'd0;
                current_rotation <= 2'd0;
                
                // Check for game over - Fixed collision check
                if (!does_piece_fit(next_piece, 4'd6, 5'd0, 2'd0)) begin
                    game_over <= 1'b1;
                    game_state <= GAME_OVER_STATE;
                end else begin
                    game_state <= FALLING;
                end
            end
            
            FALLING: begin
                // Handle input - Fixed variable names
                if (key_edge[0] && !collision_right) begin // Right
                    current_x <= current_x + 1;
                end
                if (key_edge[1] && !collision_left) begin // Left
                    current_x <= current_x - 1;
                end
                if (key_edge[2] && !collision_down) begin // Down
                    current_y <= current_y + 1;
                end
                
                // Rotation with hold mechanism
                if (key[3]) begin
                    if (rotate_hold && !collision_rotate) begin
                        current_rotation <= current_rotation + 1;
                    end
                    rotate_hold <= 1'b0;
                end else begin
                    rotate_hold <= 1'b1;
                end
                
                // Natural falling
                if (force_down) begin
                    if (!collision_down) begin
                        current_y <= current_y + 1;
                    end else begin
                        game_state <= LOCK;
                    end
                end
            end
            
            LOCK: begin
                // Lock piece to field
                lock_piece_to_field();
                piece_count <= piece_count + 1;
                
                // Increase speed every 50 pieces
                if (piece_count[5:0] == 6'd0 && speed > 6'd10) begin
                    speed <= speed - 1;
                end
                
                game_state <= CLEAR_CHECK;
            end
            
            CLEAR_CHECK: begin
                // Check for completed lines
                check_completed_lines();
                
                if (lines_cleared_count > 0) begin
                    // Add score for piece placement
                    score <= score + 16'd25;
                    clear_timer <= 4'd0;
                    game_state <= CLEAR_REMOVE;
                end else begin
                    score <= score + 16'd25;
                    game_state <= SPAWN;
                end
            end
            
            CLEAR_REMOVE: begin
                // Remove cleared lines and add score
                remove_completed_lines();
                
                // Calculate score bonus
                case (lines_cleared_count)
                    4'd1: score <= score + 16'd100;  // Single
                    4'd2: score <= score + 16'd400;  // Double  
                    4'd3: score <= score + 16'd800;  // Triple
                    4'd4: score <= score + 16'd1600; // Tetris
                endcase
                
                lines_cleared_count <= 4'd0;
                game_state <= SPAWN;
            end
            
            GAME_OVER_STATE: begin
                // Stay in game over until reset
            end
        endcase
    end
end

endmodule
