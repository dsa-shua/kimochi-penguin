`timescale 1ns / 1ps
//`default_nettype wire

module HDMI_TOP(
    input  wire CLK,                // board clock: 100 MHz on Arty/Basys3/Nexys
    input  wire RST_BTN,
    inout  wire hdmi_tx_cec,        // CE control bidirectional
    input  wire hdmi_tx_hpd,        // hot-plug detect
    inout  wire hdmi_tx_rscl,       // DDC bidirectional
    inout  wire hdmi_tx_rsda,
    output wire hdmi_tx_clk_n,      // HDMI clock differential negative
    output wire hdmi_tx_clk_p,      // HDMI clock differential positive
    output wire [2:0] hdmi_tx_n,    // Three HDMI channels differential negative
    output wire [2:0] hdmi_tx_p,     // Three HDMI channels differential positive
    output wire clk_lock,
//    output wire [3:0] led,
//    output wire go_led,
    output wire barrier_led,
    output wire coin_led,
    output wire jump_led,
    output wire [2:0] led5,             // show which is active
    input wire btn1,                    // move penguin left
    input wire btn2,                    // jump penguin
    input wire btn3,                    // move pengiun right
    input wire [1:0] sw,                // only start game when HIGH sw[0] RIGHT
    output wire coin_intr,              // send interrupt on coin hit
    output wire barrier_intr            // send interrupt on barrier hit
    );
   

    wire de;
    wire rst = RST_BTN;
    // Display Clocks
    wire pix_clk;                   // pixel clock
    wire pix_clk_5x;                // 5x clock for 10:1 DDR SerDes
 
 
    display_clocks #(               // 640x480  800x600 1280x720 1920x1080
        .MULT_MASTER(37.125),         //    31.5     10.0   37.125    37.125
        .DIV_MASTER(5),         //       5        1        5         5
       .DIV_5X(2.0),              //     5.0      5.0      2.0       1.0
        .DIV_1X(10),            //      25       25       10         5
        .IN_PERIOD(10.0)            // 100 MHz = 10 ns
    )
    
    display_clocks_inst
    (
       .i_clk(CLK),
       .i_rst(rst),
       .o_clk_1x(pix_clk),
       .o_clk_5x(pix_clk_5x),
       .o_locked(clk_lock)
      
    );

    // Display Timings
    wire signed [15:0] sx;          // horizontal screen position (signed)
    wire signed [15:0] sy;          // vertical screen position (signed)
    wire h_sync;                    // horizontal sync
    wire v_sync;                    // vertical sync
    wire frame;                     // frame start

    display_timings #(              // 640x480  800x600 1280x720 1920x1080
        .H_RES(1280),               //     640      800     1280      1920
        .V_RES(720),                //     480      600      720      1080
        .H_FP(110),                 //      16       40      110        88
        .H_SYNC(40),                //      96      128       40        44
        .H_BP(220),                 //      48       88      220       148
        .V_FP(5),                   //      10        1        5         4
        .V_SYNC(5),                 //       2        4        5         5
        .V_BP(20),                  //      33       23       20        36
        .H_POL(1),                  //       0        1        1         1
        .V_POL(1)                   //       0        1        1         1
    )
    

    display_timings_inst (
        .i_pix_clk(pix_clk),
        .i_rst(rst),
        .o_hs(h_sync),
        .o_vs(v_sync),
        .o_de(de),
        .o_frame(frame),
        .o_sx(sx),
        .o_sy(sy)
    );

    // test card colour output
    wire [7:0]  red;
    wire [7:0]  green;
    wire [7:0]  blue;
    
    wire[11:0]  REMAINING_DISTANCE;
    wire[7:0]   FSM_CURRENT_STATE;
    wire[1:0]   FSM_COIN;
    wire[1:0]   FSM_BARRIER;
    wire        REFRESHER;
    wire        ZERO_LIVES;     // sent from life compositor, set game to finish
    wire        PENGUIN_HIT;
    wire        COIN_HIT;
   
//   assign go_led = sw[0];
   state_machine FSM(
        .GAME_SWITCH            (sw[0]),
        .i_v_sync               (v_sync),
        .DISTANCE_TO_GO         (REMAINING_DISTANCE),
        .O_CURRENT_STATE        (FSM_CURRENT_STATE),
        .RELEASE_COIN           (FSM_COIN),
        .RELEASE_BARRIER        (FSM_BARRIER),
        .SPRITE_REFRESHER       (REFRESHER),
        .PENGUIN_HIT            (PENGUIN_HIT),
        .COIN_HIT               (COIN_HIT),
        .ACTIVE_LED             (led5),
        .ZERO_LIVES             (ZERO_LIVES)            // receive from GFX
   );
   
   
    gfx_inst gfx (
        .i_y(sy),
        .i_x(sx),
        .i_v_sync(v_sync),
        .o_red(red),
        .o_green(green),
        .o_blue(blue),
        .out_barrier_hit        (PENGUIN_HIT),
        .REMAINING_DISTANCE     (REMAINING_DISTANCE),
        .I_CURRENT_STATE        (FSM_CURRENT_STATE),
        .I_ACTIVE_COIN          (FSM_COIN),
        .I_ACTIVE_BARRIER       (FSM_BARRIER),
        .SPRITE_REFRESHER       (REFRESHER),
        .MV_LEFT                (btn3),
        .MV_RIGHT               (btn1),
        .MV_JUMP                (btn2),
        .OUT_AIRBORNE           (jump_led),
        .out_coin_hit           (COIN_HIT),
        .RUNNING                (sw[0]),
        .ZERO_LIVES             (ZERO_LIVES)                // send to FSM
        );
      
      assign barrier_intr = (FSM_CURRENT_STATE == 4'd10) ? 0 : PENGUIN_HIT;   
      assign coin_led = COIN_HIT;
      assign barrier_led = PENGUIN_HIT;
      assign coin_intr = COIN_HIT;
      
    
    wire ledd;               // just dont connect :)
    wire tmds_ch0_serial, tmds_ch1_serial, tmds_ch2_serial, tmds_chc_serial;
    HDMI_generator HDMI_out (
        .i_pix_clk(pix_clk),
        .i_pix_clk_5x(pix_clk_5x),
        .i_rst(rst),
        .i_de(de),
        .i_data_ch0(blue),
        .i_data_ch1(green),
        .i_data_ch2(red),
        .i_ctrl_ch0({v_sync, h_sync}),
        .i_ctrl_ch1(2'b00),
        .i_ctrl_ch2(2'b00),
        .o_tmds_ch0_serial(tmds_ch0_serial),
        .o_tmds_ch1_serial(tmds_ch1_serial),
        .o_tmds_ch2_serial(tmds_ch2_serial),
        .o_tmds_chc_serial(tmds_chc_serial),  // encode pixel clock via same path
        .rst_oserdes(ledd)
    );

    // TMDS Buffered Output
    OBUFDS #(.IOSTANDARD("TMDS_33"))
        tmds_buf_ch0 (.I(tmds_ch0_serial), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS #(.IOSTANDARD("TMDS_33"))
        tmds_buf_ch1 (.I(tmds_ch1_serial), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS #(.IOSTANDARD("TMDS_33"))
        tmds_buf_ch2 (.I(tmds_ch2_serial), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS #(.IOSTANDARD("TMDS_33"))
        tmds_buf_chc (.I(tmds_chc_serial), .O(hdmi_tx_clk_p), .OB(hdmi_tx_clk_n));

    assign hdmi_tx_cec   = 1'bz;
    assign hdmi_tx_rsda  = 1'bz;
    assign hdmi_tx_rscl  = 1'b1;
endmodule