module terrain_right (
    input wire [15:0] i_x,
    input wire [15:0] i_y,
    input wire i_v_sync,
    output wire [7:0] o_red,
    output wire [7:0] o_green,
    output wire [7:0] o_blue,
    output wire o_sprite_hit,
    
    input wire STATE_CHECK,
    input wire ACTIVE
    );
    
    reg [15:0] sprite_x     = 16'd880;
    reg [15:0] sprite_y     = 16'd360; // somewhere at the bottom of the screen 
    reg sprite_x_direction  = 1;
    reg sprite_y_direction  = 1;
    reg sprite_x_flip       = 0;
    reg sprite_y_flip       = 0;
    wire sprite_hit_x, sprite_hit_y;
    wire [4:0] sprite_render_x;
    wire [4:0] sprite_render_y;

    
    localparam /* verilator lint_off LITENDIAN */[0:3][2:0][7:0] palette_colors =  { /* verilator lint_off LITENDIAN */
        8'h00, 8'h00, 8'h00,
        8'hA0, 8'hA0, 8'hA0,
        8'ha0, 8'hA0, 8'hA0,
        8'hA0, 8'hA0, 8'hA0
    };
   
    localparam [0:15][0:15][3:0] sprite_data = {/* verilator lint_off LITENDIAN */
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd1,4'd1,4'd1,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd1,4'd1,4'd1,4'd0,4'd0,
    4'd1,4'd2,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd1,4'd0,
    4'd1,4'd2,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd3,4'd1,
    4'd0,4'd1,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd2,4'd1,
    4'd0,4'd0,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd1,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,
    4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0,4'd0
    };





    assign sprite_hit_x = (i_x >= sprite_x) && (i_x < sprite_x + 256);
    assign sprite_hit_y = (i_y >= sprite_y) && (i_y < sprite_y + 32);
    assign sprite_render_x = (i_x - sprite_x)>>4;
    assign sprite_render_y = (i_y - sprite_y)>>1;
    

    wire [1:0] selected_palette;

    assign selected_palette = sprite_data[sprite_render_y][sprite_render_x];
                                                                         
    assign o_red    = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][2] : 8'hXX;
    assign o_green  = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][1] : 8'hXX;
    assign o_blue   = (sprite_hit_x && sprite_hit_y) ? palette_colors[selected_palette][0] : 8'hXX;
    assign o_sprite_hit = (sprite_hit_y & sprite_hit_x) && (selected_palette != 2'd0);

    always@(posedge i_v_sync) begin
        if(ACTIVE && STATE_CHECK == 0) begin
            sprite_x <= sprite_x + 1;
            sprite_y <= sprite_y + 1;
            
            if(sprite_x >= 1280 || sprite_y >= 720) begin
                sprite_x <= 880;
                sprite_y <= 360;
            end
        end
    end
endmodule