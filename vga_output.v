`timescale 1ns/1ps

module binary_loader(
    input  clk,         // 25 MHz pixel clock for VGA timing
    input  clk_fast,    // Faster clock for BRAM reading

    output reg h_sync_in,  // Horizontal sync for VGA
    output reg v_sync_in,  // Vertical sync for VGA
    output reg out         // Pixel output (1=white,0=black)

);

    // 1) VGA TIMING — driven by 25 MHz pixel clock
    // VGA 640x480 @60Hz
    localparam H_ACTIVE      = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_WIDTH  = 96;
    localparam H_BACK_PORCH  = 48;
    localparam H_TOTAL       = 800;

    localparam V_ACTIVE      = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_WIDTH  = 2;
    localparam V_BACK_PORCH  = 33;
    localparam V_TOTAL       = 525;

    reg [10:0] h_count = 0;
    reg [9:0]  v_count = 0;

    always @(posedge clk) begin
        // horizontal counter
        if (h_count < H_TOTAL-1)
            h_count <= h_count + 1;
        else begin
            h_count <= 0;
            // vertical counter increments at end of each line
            if (v_count < V_TOTAL-1)
                v_count <= v_count + 1;
            else
                v_count <= 0;
        end
    end

    // sync pulse generation
    always @(posedge clk) begin
        // horiz sync active low
        h_sync_in <= ~((h_count >= H_ACTIVE+H_FRONT_PORCH) &&
                       (h_count <  H_ACTIVE+H_FRONT_PORCH+H_SYNC_WIDTH));

        // vert sync active low
        v_sync_in <= ~((v_count >= V_ACTIVE+V_FRONT_PORCH) &&
                       (v_count <  V_ACTIVE+V_FRONT_PORCH+V_SYNC_WIDTH));
    end

    // 2) BRAM reading using clk_fast
    reg  [7:0]  bram_addr = 0;
    reg         bram_wea = 0;     // read-only
    reg  [31:0] bram_din = 0;
    wire [31:0] bram_dout;

    // local storage of board
    reg [199:0] board = 0;
    reg [3:0]   read_counter = 0;
    reg         reading_active = 0;

    blk_mem_gen_0 bram_inst (
        .clka(clk_fast),
        .wea(bram_wea),
        .addra(bram_addr),
        .dina(bram_din),
        .douta(bram_dout)
    );

    // FSM: fetch board from BRAM at frame start
    always @(posedge clk_fast) begin
        if (h_count==0 && v_count==0) begin
            reading_active <= 1'b1;
            read_counter <= 0;
        end

        if (reading_active) begin
            bram_addr <= read_counter;
            case (read_counter)
                1: board[199:168] <= bram_dout;
                2: board[167:136] <= bram_dout;
                3: board[135:104] <= bram_dout;
                4: board[103:72]  <= bram_dout;
                5: board[71:40]   <= bram_dout;
                6: board[39:8]    <= bram_dout;
                7: begin
                    board[7:0]    <= bram_dout[7:0];
                    reading_active <= 1'b0;  // all done
                end
            endcase
            if (read_counter < 8)
                read_counter <= read_counter + 1;
        end
    end

    // 3) Display logic — driven by pixel clock
    localparam BLOCK_SIZE   = 24;
    localparam BOARD_WIDTH  = 10*BLOCK_SIZE;  // 240
    localparam BOARD_HEIGHT = 20*BLOCK_SIZE;  // 480
    localparam START_X      = (H_ACTIVE-BOARD_WIDTH)/2;  // 200
    localparam START_Y      = 0;

    integer block_col, block_row, block_index;

    always @(posedge clk) begin
        // active screen area
        if (h_count < H_ACTIVE && v_count < V_ACTIVE) begin
            // inside game board region?
            if ((h_count >= START_X) && (h_count < START_X+BOARD_WIDTH) &&
                (v_count >= START_Y) && (v_count < START_Y+BOARD_HEIGHT)) begin

                block_col  = (h_count - START_X) / BLOCK_SIZE; // 0-9
                block_row  = (v_count - START_Y) / BLOCK_SIZE; // 0-19
                block_index = block_row*10 + block_col;

                out <= board[block_index];
            end else
                out <= 0;
        end else begin
            out <= 0;
        end
    end

endmodule
