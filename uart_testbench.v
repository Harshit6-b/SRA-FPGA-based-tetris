module uart_tb;

    // Testbench signals
    reg clk;
    reg [3:0] button;
    wire [3:0] rled, gled, bled;

    // Instantiate the uart module
    uart uut (
        .clk(clk),
        .button(button),
        .rled(rled),
        .gled(gled),
        .bled(bled)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Generate a clock with a period of 10 time units
    end

    // Stimulus (test cases)
    initial begin
        // Initial values
        button = 4'b0000;
        $display("Time: %0t | button: %b | rled: %b | gled: %b | bled: %b", $time, button, rled, gled, bled);
        
        // Monitor output after each step
        $monitor("Time: %0t | button: %b | rled: %b | gled: %b | bled: %b", $time, button, rled, gled, bled);

        // Test case 1: Press button 1 (Shift left)
        #10 button = 4'b0001;
        #10 button = 4'b0000; // Reset button to 0000

        // Test case 2: Press button 8 (Shift right)
        #20 button = 4'b1000;
        #10 button = 4'b0000; // Reset button to 0000

        // Test case 3: Press button 4 (Toggle between bled, rled, gled)
        #20 button = 4'b0100;
        #10 button = 4'b0000; // Reset button to 0000

        // Test case 4: Press button 2 (Another toggle between bled, rled, gled)
        #20 button = 4'b0010;
        #10 button = 4'b0000; // Reset button to 0000

        // Test case 5: Press button 1 again (Shift left again)
        #20 button = 4'b0001;
        #10 button = 4'b0000; // Reset button to 0000

        // End simulation after a few cycles
        #10 $finish;
    end

endmodule
