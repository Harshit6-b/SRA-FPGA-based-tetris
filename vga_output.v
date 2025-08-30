`timescale 1ns/1ps

module binary_loader(
    input  clk,              // 25 MHz pixel clock for VGA timing

    output reg h_sync_in,    // Horizontal sync (active low)
    output reg v_sync_in,    // Vertical sync (active low)
    output reg out           // Pixel output (1=white, 0=black)
);

    // 1) VGA TIMING — 25 MHz pixel clock
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
        if (h_count < H_TOTAL-1) begin
            h_count <= h_count + 1;
        end else begin
            h_count <= 0;
            if (v_count < V_TOTAL-1)
                v_count <= v_count + 1;
            else
                v_count <= 0;
        end
    end

    // sync pulse generation (active low)
    always @(posedge clk) begin
        h_sync_in <= ~((h_count >= H_ACTIVE+H_FRONT_PORCH) &&
                       (h_count <  H_ACTIVE+H_FRONT_PORCH+H_SYNC_WIDTH));
        v_sync_in <= ~((v_count >= V_ACTIVE+V_FRONT_PORCH) &&
                       (v_count <  V_ACTIVE+V_FRONT_PORCH+V_SYNC_WIDTH));
    end
    // 2) BRAM INTERFACE (READ-ONLY HERE, 32-bit wide)
    reg  [7:0]  bram_addr = 8'd0;
    wire [31:0] bram_dout;
    wire [31:0] bram_dina_unused = 32'd0;
    wire        bram_wea_unused  = 1'b0;

    blk_mem_gen_0 bram_inst (
        .clka (clk),
        .wea  (bram_wea_unused),
        .addra(bram_addr),
        .dina (bram_dina_unused),
        .douta(bram_dout)
    );

    // Local copy of the whole board
    reg [199:0] board = 200'd0;
    // 3) FRAME-START READ FSM (handles 1-cycle BRAM read latency)
    reg       rd_active = 1'b0;
    reg [3:0] rd_state  = 4'd0;   // 0..7 plus idle
    // On cycle N: set bram_addr
    // On cycle N+1: bram_dout is valid for the address set in N

    always @(posedge clk) begin
        // Kick off loads at the very start of each frame
        if (h_count==0 && v_count==0 && !rd_active) begin
            rd_active <= 1'b1;
            rd_state  <= 4'd0;
        end

        if (rd_active) begin
            // Drive next address
            case (rd_state)
                4'd0: bram_addr <= 8'd0;
                4'd1: bram_addr <= 8'd1;
                4'd2: bram_addr <= 8'd2;
                4'd3: bram_addr <= 8'd3;
                4'd4: bram_addr <= 8'd4;
                4'd5: bram_addr <= 8'd5;
                4'd6: bram_addr <= 8'd6;
                default: ;
            endcase

            // Capture the PREVIOUS cycle's data into the right slice
            case (rd_state)
                4'd1: board[199:168] <= bram_dout;           // from addr 0
                4'd2: board[167:136] <= bram_dout;           // from addr 1
                4'd3: board[135:104] <= bram_dout;           // from addr 2
                4'd4: board[103:72]  <= bram_dout;           // from addr 3
                4'd5: board[71:40]   <= bram_dout;           // from addr 4
                4'd6: board[39:8]    <= bram_dout;           // from addr 5
                4'd7: board[7:0]     <= bram_dout[7:0];      // from addr 6
                default: ;
            endcase

            // advance / stop
            if (rd_state == 4'd7) begin
                rd_active <= 1'b0;   // done (we just latched last piece)
            end else begin
                rd_state <= rd_state + 1'b1;
            end
        end
    end
    // 4) DISPLAY: 10x20 grid, 24x24 pixels per cell, centered
    localparam COLS         = 10;
    localparam ROWS         = 20;
    localparam BOARD_WIDTH  = COLS*BLOCK_SIZE;   // 240
    localparam BOARD_HEIGHT = ROWS*BLOCK_SIZE;   // 480
    localparam START_X      = (H_ACTIVE-BOARD_WIDTH)/2;  // 200
    localparam START_Y      = 0;

    wire in_active  = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    wire in_board_x = (h_count >= START_X) && (h_count < START_X + BOARD_WIDTH);
    wire in_board_y = (v_count >= START_Y) && (v_count < START_Y + BOARD_HEIGHT);
    wire in_board   = in_active && in_board_x && in_board_y;

    // Compute block coordinates (registered for timing cleanliness)
    reg [3:0] block_col;   // 0..9
    reg [4:0] block_row;   // 0..19
    reg [8:0] block_index; // 0..199

    always @(posedge clk) begin
        if (in_board) begin
            // Safe to use constant-division at 25 MHz; synthesis will optimize.
            block_col <= (h_count - START_X) / BLOCK_SIZE;
            block_row <= (v_count - START_Y) / BLOCK_SIZE;
        end else begin
            block_col <= 4'd15; // invalid
            block_row <= 5'd31; // invalid
        end
    end

    // index = row*10 + col  => (row<<3) + (row<<1) + col
    always @(posedge clk) begin
        if (block_col < COLS && block_row < ROWS)
            block_index <= (block_row<<3) + (block_row<<1) + block_col;
        else
            block_index <= 9'd511; // invalid
    end

    // Output pixel bit (registered)
    always @(posedge clk) begin
        if (in_board && block_index < 200)
            out <= board[block_index];
        else
            out <= 1'b0;
    end

endmodule
