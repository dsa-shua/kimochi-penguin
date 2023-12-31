module sprite_compositor (
    input wire [15:0] i_x,
    input wire [15:0] i_y,
    input wire i_v_sync,
    output wire [7:0] o_red,
    output wire [7:0] o_green,
    output wire [7:0] o_blue,
    output wire o_sprite_hit,
    
    input wire[7:0] SPRITE_STATE,
    output wire AIRBORNE,                       // checked by barrier
    output wire [1:0]   ACTIVE_LANE,            // checked by coin and barrier for collision
    input wire SPRITE_REFRESHER,                // used for blinking feet (?)
    input wire mv_left,
    input wire mv_right,
    input wire mv_jump,
    input wire coin_hit,                        // make sprite yellow when coin hit
    input wire barrier_hit                      // make sprite red when barrier hit
    );
    
//    enum logic [3:0] {START, COIN1, BARRIER1, COIN2, COIN3, BARRIER2, COIN4, BARRIER3, COIN5, BARRIER4, FINISH} STATE;
//    enum logic [1:0] {LEFT, MID, RIGHT} LANE;
    localparam[1:0] LEFT = 2'b01;
    localparam[1:0] MID = 2'b10;
    localparam[1:0] RIGHT = 2'b11;
    localparam[15:0] BASE_LEFT = 16'd262;        // if sprite not in here, gradually move
    localparam[15:0] BASE_MID = 16'd512;         // if sprite not in here, gradually move
    localparam[15:0] BASE_RIGHT = 16'd762;       // if sprite not in here, gradually move
    
    // TODO:
    localparam[15:0] BASE_GROUND = 16'd414;     // drop here
    localparam[15:0] MAX_JUMP = 16'd414;        // jump until here.. FIX
    
    reg [15:0] sprite_x     = 16'd512;
    reg [15:0] sprite_y     = 16'd400;          // somewhere at the bottom of the screen 
    reg sprite_x_direction  = 1;
    reg sprite_y_direction  = 1;
    reg [1:0] CURRENT_LANE = MID;               // 00: LEFT, 10: MID, 11: RIGHT (SPECIFIED BY ENUM LOGIC LANE
    reg FEET_STATE = 0;                         // 0: LEFT, 1: RIGHT
    
    enum logic [3:0] {GROUND, MID_UP, ROOF, MID_DOWN} JUMP_STATE;
    reg[3:0] CURRENT_JUMP_STATE = GROUND;                               // 000: FLOOR, 001: MID JUMP UP, 010: ROOF, 100: MID JUMP DOWN
    wire sprite_hit_x, sprite_hit_y;
    wire [5:0] sprite_render_x;
    wire [5:0] sprite_render_y;
    
    reg[3:0] JUMP_TIMER = 4'b0000;              // CHANGE FRAME IF 1111

// transparent, black?, gray, yellow
    localparam /* verilator lint_off LITENDIAN */[0:4][2:0][7:0] palette_colors =  { /* verilator lint_off LITENDIAN */
        8'h00, 8'h00, 8'h00,
        8'h42, 8'h42, 8'h42, // gray
        8'h21, 8'h21, 8'h21, // black
        8'hFF, 8'hC1, 8'h07, // yellow
        8'h45, 8'h5a, 8'h64 // shadow?
    };
    
    localparam [0:39][0:31][3:0] sprite_data = {/* verilator lint_off LITENDIAN */
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd3,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd1,4'd3,4'd3,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd3,4'd1,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd1,4'd1,4'd1,4'd4,4'd1,4'd2,4'd2,4'd2,4'd1,4'd3,4'd3,4'd1,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd1,4'd2,4'd1,4'd3,4'd3,4'd3,4'd1,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd1,4'd4,4'd1,4'd1,4'd1,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0
    };
    
localparam [0:39][0:31][3:0] sprite_data1 = {/* verilator lint_off LITENDIAN */
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd1,4'd3,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd3,4'd1,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd1,4'd3,4'd3,4'd1,4'd2,4'd2,4'd2,4'd1,4'd3,4'd3,4'd1,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd1,4'd3,4'd3,4'd3,4'd1,4'd2,4'd1,4'd4,4'd1,4'd1,4'd1,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd1,4'd1,4'd1,4'd4,4'd1,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0
    };

// still in shadow
    localparam [0:39][0:31][3:0] sprite_data_jump1 = {/* verilator lint_off LITENDIAN */
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd3,4'd1,4'd2,4'd2,4'd2,4'd1,4'd3,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd3,4'd3,4'd1,4'd2,4'd1,4'd3,4'd3,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd0,4'd1,4'd0,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0
    };

    // beyond shadow, max jump? 
    localparam [0:39][0:31][3:0] sprite_data_jump0 = {/* verilator lint_off LITENDIAN */
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd3,4'd1,4'd2,4'd2,4'd2,4'd1,4'd3,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd1,4'd3,4'd3,4'd3,4'd1,4'd2,4'd1,4'd3,4'd3,4'd3,4'd1,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd1,4'd1,4'd1,4'd4,4'd1,4'd4,4'd1,4'd1,4'd1,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd4,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0
    };
    
    assign sprite_hit_x = (i_x >= sprite_x) && (i_x < sprite_x + 256);
    assign sprite_hit_y = (i_y >= sprite_y) && (i_y < sprite_y + 512);
    assign sprite_render_x = (i_x - sprite_x)>>3;
    assign sprite_render_y = (i_y - sprite_y)>>3;
    
    wire [3:0] selected_palette;

    assign selected_palette = (CURRENT_JUMP_STATE == GROUND) ? (FEET_STATE ? sprite_data[sprite_render_y][sprite_render_x] : sprite_data1[sprite_render_y][sprite_render_x])
                                :((CURRENT_JUMP_STATE == MID_UP || CURRENT_JUMP_STATE == MID_DOWN) ? sprite_data_jump0[sprite_render_y][sprite_render_x]
                                : sprite_data_jump1[sprite_render_y][sprite_render_x]);
    
    assign o_red    = (sprite_hit_x && sprite_hit_y) ? (barrier_hit ? 8'hFF : ((coin_hit) ? 8'hFF :  palette_colors[selected_palette][2])) : 8'hXX;                                                              
    assign o_green  = (sprite_hit_x && sprite_hit_y) ? (barrier_hit ? 8'h00 : ((coin_hit) ? 8'hFF :  palette_colors[selected_palette][1])) : 8'hXX;
    assign o_blue   = (sprite_hit_x && sprite_hit_y) ? (barrier_hit ? 8'h00 : ((coin_hit) ? 8'h00 :  palette_colors[selected_palette][0])) : 8'hXX;
    assign o_sprite_hit = (sprite_hit_y & sprite_hit_x) && (selected_palette != 2'd0);
    


    reg CONTROL = 0;
//    reg JUMP_REQUEST = 0;
    always@(posedge i_v_sync) begin
        if(mv_left || mv_right || mv_jump) begin
            CONTROL <= 1;
        end
        else begin
            CONTROL <= 0;
        end
        
        // adjust x-coords only when not in air, cannot jump while moving left or right
        if(CURRENT_JUMP_STATE == GROUND && mv_jump == 0) begin
            JUMP_TIMER <= 4'b0000;                    // Always reset jump timer at ground
//            JUMP_REQUEST <= 0;                       // ALWAYS reset jump request
            if(CURRENT_LANE == LEFT) begin
                if (sprite_x != BASE_LEFT) begin
                    sprite_x <= sprite_x - 16'd2;
                end
            end
            if(CURRENT_LANE == RIGHT) begin
                if(sprite_x != BASE_RIGHT) begin
                    sprite_x <= sprite_x + 16'd2;
                end
            end
            
            if(CURRENT_LANE == MID) begin
                if(sprite_x < BASE_MID) begin
                    sprite_x <= sprite_x + 16'd2;
                end
                if(sprite_x > BASE_MID) begin
                    sprite_x <= sprite_x - 16'd2;
                end
            end
        end
        
        // only when in ground, start jump 
        else if (mv_jump == 1 && CURRENT_JUMP_STATE == GROUND && SPRITE_STATE != 4'ha) begin
            CURRENT_JUMP_STATE <= MID_UP;
        end
        
        // Only executes if in air
        else if (CURRENT_JUMP_STATE != GROUND && SPRITE_STATE != 4'ha) begin
            JUMP_TIMER <= JUMP_TIMER + 1; // slowly count to 1111
            if(JUMP_TIMER == 4'b1111) begin
                    if (CURRENT_JUMP_STATE == MID_UP) begin
                        CURRENT_JUMP_STATE <= ROOF;
                    end
                    else if (CURRENT_JUMP_STATE == ROOF) begin
                        CURRENT_JUMP_STATE <= MID_DOWN;
                    end
                    else if (CURRENT_JUMP_STATE == MID_DOWN) begin
                        CURRENT_JUMP_STATE <= GROUND;
                    end
            end
        end        
        
    end

    always@(posedge CONTROL) begin
        // accept horizontal movement only when at ground
        if (SPRITE_STATE != 4'ha) begin
            if(CURRENT_JUMP_STATE == GROUND) begin   
                if(mv_left == 1) begin
                    if(CURRENT_LANE == LEFT) begin
                    end
                    else if(CURRENT_LANE == MID) begin
                        CURRENT_LANE <= LEFT;             
                    end
                    else if(CURRENT_LANE == RIGHT) begin
                        CURRENT_LANE <= MID;
                    end
                end
                
                if(mv_right == 1) begin
                    if (CURRENT_LANE == LEFT) begin
                        CURRENT_LANE <= MID;
                    end
                    else if (CURRENT_LANE == MID) begin
                        CURRENT_LANE <= RIGHT;
                    end
                end
            end
        end
    end 
    
    logic isAIRBORNE = (CURRENT_JUMP_STATE == GROUND) ? 0 : 1; 
    assign ACTIVE_LANE = isAIRBORNE ? 2'b00 : CURRENT_LANE;         // tell coin and barrier where penguin is
    assign AIRBORNE = isAIRBORNE;                                   // tell barrier we high
    // walking animation 
    always@(posedge SPRITE_REFRESHER) begin
        FEET_STATE = ~FEET_STATE;
    end
endmodule