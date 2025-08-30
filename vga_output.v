`timescale 1ns/1ps

module binary_loader(
    input  clk,         // 25 MHz pixel clock for VGA timing
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

   	    // 2) BRAM reading using the same clk (no clk_fast)
    reg  [7:0]  bram_addr = 0;
    reg         bram_wea  = 0;     // read-only
    reg  [31:0] bram_din  = 0;
    wire [31:0] bram_dout;

    // local storage of board
    reg [199:0] board = 0;

    blk_mem_gen_0 bram_inst (
        .clka(clk),       // << use pixel clock now
        .wea(bram_wea),
        .addra(bram_addr),
        .dina(bram_din),
        .douta(bram_dout)
    );

    // FSM for sequential reads
    reg [3:0] rd_state   = 0;
    reg       rd_active  = 0;

    always @(posedge clk) begin
        // Start reading at beginning of frame
        if (h_count==0 && v_count==0 && !rd_active) begin
            rd_active <= 1;
            rd_state  <= 0;
        end

        if (rd_active) begin
            // set next BRAM address
            case (rd_state)
                0: bram_addr <= 0;
                1: bram_addr <= 1;
                2: bram_addr <= 2;
                3: bram_addr <= 3;
                4: bram_addr <= 4;
                5: bram_addr <= 5;
                6: bram_addr <= 6;
            endcase

            // latch previous cycle’s data
            case (rd_state)
                1: board[199:168] <= bram_dout;      // addr 0 data
                2: board[167:136] <= bram_dout;      // addr 1
                3: board[135:104] <= bram_dout;      // addr 2
                4: board[103:72]  <= bram_dout;      // addr 3
                5: board[71:40]   <= bram_dout;      // addr 4
                6: board[39:8]    <= bram_dout;      // addr 5
                7: board[7:0]     <= bram_dout[7:0]; // addr 6
            endcase

            if (rd_state == 7)
                rd_active <= 0;
            else
                rd_state <= rd_state + 1;
        end
    end

   	
   	
	localparam BLOCK_SIZE   = 24;
	localparam BOARD_WIDTH  = 10*BLOCK_SIZE;  // 240
	localparam BOARD_HEIGHT = 20*BLOCK_SIZE;  // 480
	localparam START_X      = (H_ACTIVE-BOARD_WIDTH)/2;  // 200
	localparam START_Y      = 0;

	reg [3:0] block_col;   // 0–9
	reg [4:0] block_row;   // 0–19
	reg [8:0] block_index; // 0–199

	always @(posedge clk) begin
	    block_col <= 4'd15; // invalid default
	    block_row <= 5'd31;

	    if ((h_count >= START_X) && (h_count < START_X+BOARD_WIDTH) &&
		(v_count >= START_Y) && (v_count < START_Y+BOARD_HEIGHT)) begin

		// ---------------- Column calculation ----------------
		case (h_count - START_X)
		    0  ,1  ,2  ,3  ,4  ,5  ,6  ,7  ,8  ,9  ,
		    10 ,11 ,12 ,13 ,14 ,15 ,16 ,17 ,18 ,19 ,
		    20 ,21 ,22 ,23 : block_col <= 0;

		    24 ,25 ,26 ,27 ,28 ,29 ,30 ,31 ,32 ,33 ,
		    34 ,35 ,36 ,37 ,38 ,39 ,40 ,41 ,42 ,43 ,
		    44 ,45 ,46 ,47 : block_col <= 1;

		    48 ,49 ,50 ,51 ,52 ,53 ,54 ,55 ,56 ,57 ,
		    58 ,59 ,60 ,61 ,62 ,63 ,64 ,65 ,66 ,67 ,
		    68 ,69 ,70 ,71 : block_col <= 2;

		    72 ,73 ,74 ,75 ,76 ,77 ,78 ,79 ,80 ,81 ,
		    82 ,83 ,84 ,85 ,86 ,87 ,88 ,89 ,90 ,91 ,
		    92 ,93 ,94 ,95 : block_col <= 3;

		    96 ,97 ,98 ,99 ,100,101,102,103,104,105,
		    106,107,108,109,110,111,112,113,114,115,
		    116,117,118,119: block_col <= 4;

		    120,121,122,123,124,125,126,127,128,129,
		    130,131,132,133,134,135,136,137,138,139,
		    140,141,142,143: block_col <= 5;

		    144,145,146,147,148,149,150,151,152,153,
		    154,155,156,157,158,159,160,161,162,163,
		    164,165,166,167: block_col <= 6;

		    168,169,170,171,172,173,174,175,176,177,
		    178,179,180,181,182,183,184,185,186,187,
		    188,189,190,191: block_col <= 7;

		    192,193,194,195,196,197,198,199,200,201,
		    202,203,204,205,206,207,208,209,210,211,
		    212,213,214,215: block_col <= 8;

		    216,217,218,219,220,221,222,223,224,225,
		    226,227,228,229,230,231,232,233,234,235,
		    236,237,238,239: block_col <= 9;
		endcase

		// ---------------- Row calculation ----------------
		case (v_count - START_Y)
		    0  ,1  ,2  ,3  ,4  ,5  ,6  ,7  ,8  ,9  ,
		    10 ,11 ,12 ,13 ,14 ,15 ,16 ,17 ,18 ,19 ,
		    20 ,21 ,22 ,23 : block_row <= 0;

		    24 ,25 ,26 ,27 ,28 ,29 ,30 ,31 ,32 ,33 ,
		    34 ,35 ,36 ,37 ,38 ,39 ,40 ,41 ,42 ,43 ,
		    44 ,45 ,46 ,47 : block_row <= 1;

		    48 ,49 ,50 ,51 ,52 ,53 ,54 ,55 ,56 ,57 ,
		    58 ,59 ,60 ,61 ,62 ,63 ,64 ,65 ,66 ,67 ,
		    68 ,69 ,70 ,71 : block_row <= 2;

		    72 ,73 ,74 ,75 ,76 ,77 ,78 ,79 ,80 ,81 ,
		    82 ,83 ,84 ,85 ,86 ,87 ,88 ,89 ,90 ,91 ,
		    92 ,93 ,94 ,95 : block_row <= 3;

		    96 ,97 ,98 ,99 ,100,101,102,103,104,105,
		    106,107,108,109,110,111,112,113,114,115,
		    116,117,118,119: block_row <= 4;

		    120,121,122,123,124,125,126,127,128,129,
		    130,131,132,133,134,135,136,137,138,139,
		    140,141,142,143: block_row <= 5;

		    144,145,146,147,148,149,150,151,152,153,
		    154,155,156,157,158,159,160,161,162,163,
		    164,165,166,167: block_row <= 6;

		    168,169,170,171,172,173,174,175,176,177,
		    178,179,180,181,182,183,184,185,186,187,
		    188,189,190,191: block_row <= 7;

		    192,193,194,195,196,197,198,199,200,201,
		    202,203,204,205,206,207,208,209,210,211,
		    212,213,214,215: block_row <= 8;

		    216,217,218,219,220,221,222,223,224,225,
		    226,227,228,229,230,231,232,233,234,235,
		    236,237,238,239: block_row <= 9;

		    240,241,242,243,244,245,246,247,248,249,
		    250,251,252,253,254,255,256,257,258,259,
		    260,261,262,263: block_row <= 10;

		    264,265,266,267,268,269,270,271,272,273,
		    274,275,276,277,278,279,280,281,282,283,
		    284,285,286,287: block_row <= 11;

		    288,289,290,291,292,293,294,295,296,297,
		    298,299,300,301,302,303,304,305,306,307,
		    308,309,310,311: block_row <= 12;

		    312,313,314,315,316,317,318,319,320,321,
		    322,323,324,325,326,327,328,329,330,331,
		    332,333,334,335: block_row <= 13;

		    336,337,338,339,340,341,342,343,344,345,
		    346,347,348,349,350,351,352,353,354,355,
		    356,357,358,359: block_row <= 14;

		    360,361,362,363,364,365,366,367,368,369,
		    370,371,372,373,374,375,376,377,378,379,
		    380,381,382,383: block_row <= 15;

		    384,385,386,387,388,389,390,391,392,393,
		    394,395,396,397,398,399,400,401,402,403,
		    404,405,406,407: block_row <= 16;

		    408,409,410,411,412,413,414,415,416,417,
		    418,419,420,421,422,423,424,425,426,427,
		    428,429,430,431: block_row <= 17;

		    432,433,434,435,436,437,438,439,440,441,
		    442,443,444,445,446,447,448,449,450,451,
		    452,453,454,455: block_row <= 18;

		    456,457,458,459,460,461,462,463,464,465,
		    466,467,468,469,470,471,472,473,474,475,
		    476,477,478,479: block_row <= 19;
		endcase
	    end
	end

	// Flattened index, also clocked
	always @(posedge clk) begin
	    if (block_col <= 9 && block_row <= 19)
		block_index <= block_row*10 + block_col;
	    else
		block_index <= 9'd511; // invalid
	end
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
