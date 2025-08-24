module simple_tetris_tb;

    // Testbench signals
    reg clk;
    reg reset;
    reg [3:0] cmd;
    wire [199:0] board;
    wire game_over;

    // Instantiate the Tetris module
    simple_tetris uut (
        .clk(clk),
        .reset(reset),
        .cmd(cmd),
        .board(board),
        .game_over(game_over)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Generate a clock with a period of 10 time units
    end

    // Variables for displaying the board
    integer row, col;
    
    // Task to show the board in a simple grid
    task show_board;
        begin
            $display("\n--- TETRIS BOARD ---");
            for (row = 0; row < 20; row = row + 1) begin
                $write("Row %2d: ", row);
                for (col = 0; col < 10; col = col + 1) begin
                    if (board[row * 10 + col] == 1)
                        $write("X ");
                    else
                        $write(". ");
                end
                $write("\n");
            end
            $display("Game Over: %b", game_over);
            $display("--------------------\n");
        end
    endtask

    // Stimulus (test cases)
    initial begin
        // Initial values
        reset = 1;
        cmd = 4'b0000;
        $display("Starting Tetris Test");
        $display("Time: %0t | Reset: %b | Cmd: %b | Game Over: %b", $time, reset, cmd, game_over);
        
        // Release reset
        #20 reset = 0;
        $display("Time: %0t | Reset released", $time);
        show_board();
        
        // Wait a bit to see the first piece
        #50;
        $display("Time: %0t | First piece appeared", $time);
        show_board();
        
        // Test case 1: Move right
        #10 cmd = 4'b0001;  // Right
        #10 cmd = 4'b0000;  // Release
        $display("Time: %0t | Moved RIGHT", $time);
        show_board();
        
        // Test case 2: Move left
        #20 cmd = 4'b1000;  // Left
        #10 cmd = 4'b0000;  // Release
        $display("Time: %0t | Moved LEFT", $time);
        show_board();
        
        // Test case 3: Rotate piece
        #20 cmd = 4'b0100;  // Rotate
        #10 cmd = 4'b0000;  // Release
        $display("Time: %0t | ROTATED piece", $time);
        show_board();
        
        // Test case 4: Move down
        #20 cmd = 4'b0010;  // Down
        #10 cmd = 4'b0000;  // Release
        $display("Time: %0t | Moved DOWN", $time);
        show_board();
        
        // Test case 5: Move right multiple times
        #20 cmd = 4'b0001;  // Right
        #10 cmd = 4'b0000;
        #10 cmd = 4'b0001;  // Right again
        #10 cmd = 4'b0000;
        #10 cmd = 4'b0001;  // Right again
        #10 cmd = 4'b0000;
        $display("Time: %0t | Moved RIGHT 3 times", $time);
        show_board();
        
        // Test case 6: Let piece fall naturally
        #200;  // Wait for auto-fall
        $display("Time: %0t | Piece falling naturally", $time);
        show_board();
        
        // Test case 7: Drop piece quickly
        #10 cmd = 4'b0010;  // Down
        #10 cmd = 4'b0000;
        #10 cmd = 4'b0010;  // Down
        #10 cmd = 4'b0000;
        #10 cmd = 4'b0010;  // Down
        #10 cmd = 4'b0000;
        $display("Time: %0t | Dropped piece quickly", $time);
        show_board();
        
        // Test case 8: Wait for piece to lock and new piece to spawn
        #500;
        $display("Time: %0t | New piece spawned", $time);
        show_board();
        
        // Test case 9: Play for a while
        #1000;
        $display("Time: %0t | After playing for a while", $time);
        show_board();
        
        // Monitor the game state
        if (game_over == 1) begin
            $display("GAME OVER!");
        end else begin
            $display("Game is still running");
        end
        
        // End simulation
        #100 $display("=== TEST COMPLETE ===");
        $finish;
    end

endmodule