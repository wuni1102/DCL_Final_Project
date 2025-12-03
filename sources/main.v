// 12/3, wunini 理解到 ghost block 前，做了重新排版、變數重命名，並加上一些註解提示某些地方可以優化，另外改了按鈕的key_binding

module main(
    input clk, // 100MHz
    input reset_n, // active low
    input [3:0] usr_btn,
    
    output [3:0] usr_led,
    
    // VGA signal
    output VGA_HSYNC, VGA_VSYNC,
    output [3:0] VGA_RED, VGA_GREEN, VGA_BLUE
);

//==================================================================
// vga part

parameter system_clk = 100_000_000;
reg vga_clk = 0;
always @(posedge clk) vga_clk = !vga_clk;

parameter WIDTH = 640;
parameter HEIGHT = 480;
wire vedio_on, pixel_tick;
wire [9:0] pixel_y;
wire [9:0] pixel_x;
reg [11:0] rgb_reg;
reg [11:0] rgb_next;
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;
vga_sync vga(.clk(vga_clk), .reset(~reset_n), .visible(vedio_on),
             .p_tick(pixel_tick), .pixel_x(pixel_x), .pixel_y(pixel_y),
             .oHS(VGA_HSYNC), .oVS(VGA_VSYNC));

// end of vga
//==================================================================
//==================================================================
// keyboard binding
// 12/3 changed

assign btn_right = usr_btn[0];
assign btn_left = usr_btn[1];
assign btn_soft_drop = usr_btn[2];
assign btn_rot = usr_btn[3];

assign usr_led = ~usr_btn;
    
// end of keyboard binding
//==================================================================
//==================================================================
// necessary parameters

parameter BOARD_EMPTY = 0, BOARD_L = 1, BOARD_J = 2,
          BOARD_I     = 3, BOARD_O = 4, BOARD_Z = 5,
          BOARD_S     = 6, BOARD_T = 7;

parameter ROTATION_0 = 0, ROTATION_1 = 1,
          ROTATION_2 = 2, ROTATION_3 = 3;

parameter Handling_DAS = 10, Handling_ARR = 2,
          Handling_ARE = 6;
    
// end of parameters
//==================================================================
//==================================================================
// frame clock

reg [20:0] cnt_frame = 0;
reg clk_frame_pulse = 0;
always @(negedge clk) begin
    if (cnt_frame == system_clk / 60 - 1) begin // WHS bad
        cnt_frame <= 0;
        clk_frame_pulse <= 1'b1;
    end else begin
        cnt_frame <= cnt_frame + 1;
        clk_frame_pulse <= 1'b0;
    end
end
  
// end of frame clock
//==================================================================
//==================================================================
// two block state machine for game states

reg [5:0] restart_cnt = 0;

parameter S_INIT     = 0, S_MENU     = 1,
          S_GAMEPLAY = 2, S_GAMEOVER = 3;

reg game_over = 0;
reg [1:0] P_main = S_INIT;
reg [1:0] P_next_main = S_INIT;

always @(negedge clk) begin
    if (reset_n == 1'b0) begin
        P_main <= S_INIT;
    end else begin
        P_main <= P_next_main;
    end
end

always @(posedge clk) begin // 應該更新為組合邏輯，但因為restart_cnt不可直接改變
    if (reset_n == 1'b0) begin
        P_next_main <= S_INIT;
    end else begin
        case (P_main)
            S_INIT:
                P_next_main <= S_MENU;
            S_MENU:
                P_next_main <= S_GAMEPLAY;
            S_GAMEPLAY: begin
                if (game_over) begin
                    P_next_main <= S_GAMEOVER;
                end
                restart_cnt <= 60; // FSM should not 處理除P以外的事
            end
            S_GAMEOVER: begin
                if (clk_frame_pulse) begin
                    restart_cnt <= restart_cnt - 1;
                end

                if (restart_cnt == 0) begin
                    P_next_main <= S_GAMEPLAY; // should go back to menu
                end
            end
        endcase
    end
end

// end of game state machine
//==================================================================
//==================================================================
// board memory manager

reg [2:0] board[0:9][0:39];
reg [2:0] piece = 0;
reg block_write = 0;
reg [3:0] block_x = 0;
reg [5:0] block_y = 0;
reg [2:0] block_data = 0;
always @(negedge clk) begin
    if (block_write) begin
        board[block_x][block_y] <= block_data;
    end
end
    
// end of board memory manager
//==================================================================
//==================================================================
// collision tester

reg test_start = 0; // give this a pulse to start the test
reg test_busy = 0; // wait for this to become 0


// fill in these data to test if block placement is valid
wire [2:0] test_piece; // 方塊種類
assign test_piece = piece;
reg [3:0] test_x = 0; // pivot_x
reg [5:0] test_y = 0; // pivot_y
reg [1:0] test_rotation = 0;

reg [2:0] test_state = 0;
reg test_result = 0; // only valid when test_busy = 0
reg [3:0] test_x_off = 0;
reg [5:0] test_y_off = 0;

wire test_collide;
assign test_collide = board[test_x_off][test_y_off] == BOARD_EMPTY;

wire [3:0] test_x_off_0;
wire [5:0] test_y_off_0;
wire [3:0] test_x_off_1;
wire [5:0] test_y_off_1;
wire [3:0] test_x_off_2;
wire [5:0] test_y_off_2;

Tetromino tetromino_test(test_piece, test_x, test_y, test_rotation,
                         test_x_off_0, test_y_off_0,
                         test_x_off_1, test_y_off_1,
                         test_x_off_2, test_y_off_2);
// 回傳四個方塊的x,y

// took 5 clk to operate // better to use FSM like game state, 現在可能有latch
always @(negedge clk) begin
    if (reset_n == 1'b0) begin
        test_state <= 0; // Idle state
        test_busy <= 1'b0;
        test_result <= 1'b1;
    end else if (test_start) begin
        test_state <= 1;
        test_busy <= 1'b1;
        test_result <= 1'b1;
    end

    case (test_state)
        1: begin
            test_state <= 2;
            // test the pivot
            test_x_off <= test_x;
            test_y_off <= test_y;
            // test for border collision
            // Note: upper bound are included to prevent underflow
            case (test_piece)
                BOARD_I: begin
                    case (test_rotation) // should減少魔法數字
                        ROTATION_0: test_result <= test_x < 1 || test_x > 7               || test_y > 39;
                        ROTATION_1: test_result <=               test_x > 9 || test_y < 2 || test_y > 39;
                        ROTATION_2: test_result <= test_x < 2 || test_x > 8               || test_y > 39;
                        ROTATION_3: test_result <=               test_x > 9 || test_y < 1 || test_y > 39;
                    endcase
                end
                BOARD_O: begin
                    case (test_rotation)
                        ROTATION_0: test_result <=               test_x > 8               || test_y > 39;
                        ROTATION_1: test_result <=               test_x > 8 || test_y < 1 || test_y > 39;
                        ROTATION_2: test_result <= test_x < 1 || test_x > 9 || test_y < 1 || test_y > 39;
                        ROTATION_3: test_result <= test_x < 1 || test_x > 9               || test_y > 39;
                    endcase
                end
                default: begin
                    case (test_rotation)
                        ROTATION_0: test_result <= test_x < 1 || test_x > 8               || test_y > 39;
                        ROTATION_1: test_result <=               test_x > 8 || test_y < 1 || test_y > 39;
                        ROTATION_2: test_result <= test_x < 1 || test_x > 8 || test_y < 1 || test_y > 39;
                        ROTATION_3: test_result <= test_x < 1 || test_x > 9 || test_y < 1 || test_y > 39;
                    endcase
                end
            endcase
        end
        2: begin
            test_state <= 3;
            // save test result
            // Note the previous test result is inverted
            test_result <= !test_result && test_collide;
            // second test point
            test_x_off <= test_x_off_0;
            test_y_off <= test_y_off_0;
        end
        3: begin
            test_state <= 4;
            // save test result
            test_result <= test_result && test_collide;
            // third test point
            test_x_off <= test_x_off_1;
            test_y_off <= test_y_off_1;
        end
        4: begin
            test_state <= 5;
            // save test result
            test_result <= test_result && test_collide;
            // forth test point
            test_x_off <= test_x_off_2;
            test_y_off <= test_y_off_2;
        end
        5: begin
            test_state <= 0;
            test_busy <= 1'b0; // done
            // save test result
            test_result <= test_result && test_collide;
        end
    endcase
end
    
// end of collsion test 
//==================================================================
//==================================================================
// top out detecter

reg [3:0] piece_x = 0;
reg [5:0] piece_y = 0;
reg top_out_detect = 0;
always @(posedge clk) begin
    case (test_piece)
        BOARD_I: begin
            case (test_rotation)
                ROTATION_0: top_out_detect <= piece_y > 19;
                ROTATION_1: top_out_detect <= piece_y > 21;
                ROTATION_2: top_out_detect <= piece_y > 19;
                ROTATION_3: top_out_detect <= piece_y > 20;
            endcase
        end
        BOARD_O: begin
            case (test_rotation)
                ROTATION_0: top_out_detect <= piece_y > 19;
                ROTATION_1: top_out_detect <= piece_y > 20;
                ROTATION_2: top_out_detect <= piece_y > 20;
                ROTATION_3: top_out_detect <= piece_y > 19;
            endcase
        end
        default: begin
            case (test_rotation)
                ROTATION_0: top_out_detect <= piece_y > 19;
                ROTATION_1: top_out_detect <= piece_y > 20;
                ROTATION_2: top_out_detect <= piece_y > 20;
                ROTATION_3: top_out_detect <= piece_y > 20;
            endcase
        end
    endcase
end

// end of top out detect
//==================================================================
//==================================================================
// game update
    
parameter ACTION_NONE = 0;
parameter ACTION_MOVE_L = 1;
parameter ACTION_MOVE_R = 2;
parameter ACTION_ROT_CW = 3;
// parameter ACTION_ROT_CCW = 4;
// parameter ACTION_ROT_180 = 5;
parameter ACTION_HARD_DROP = 6;
reg [2:0] action = 0;
reg [1:0] rotation = 0;

reg DAS_active = 0;
reg [4:0] DAS_cnt = 0;

reg [3:0] ARE_cnt = 0;

reg [3:0] hold_piece = 0;
reg hold_able = 0;

reg btn_rot_debounce = 0; // key input

// line clear gravity
reg line_full = 0;
reg line_empty = 0;
reg [3:0] line_x = 0;
reg [5:0] line_y_scan = 0;
reg [5:0] line_y_write = 0;
wire [3:0] line_scan;
wire line_scan_is_empty;

assign line_scan = board[line_x][line_y_scan];
assign line_scan_is_empty = (line_scan == BOARD_EMPTY);

reg [2:0] line_cleared = 0;

// drop gravity
parameter GRAVITY_FRAMES = 14;
reg [3:0] gravity_cnt = 0;
reg gravity_trig = 0;

// soft drop lock delay
parameter LOCK_FRAMES = 30;
parameter MOVE_RESET_LIMIT = 15;
reg [4:0] lock_cnt = 0;
reg [3:0] move_reset = 0;
reg on_ground = 0;
reg on_ground_trig_test = 0; // trigger test every frame

// queue
reg permute_latch = 0;
reg [2:0] queue_cnt = 0;
wire [2:0] permute_in;
wire [2:0] permute_out;

assign permute_in = queue_cnt;

seven_permute UUT(clk, reset_n, permute_latch, permute_in, permute_out);
// 亂數抽方塊

integer kdx;
reg [3:0] queue[15:0];
reg [3:0] queue_length = 0;
reg [3:0] queue_data = 0;
reg queue_pop = 0;
reg queue_add = 0;
reg queue_clear = 0;

always @(negedge clk) begin
    if (reset_n == 1'b0 || queue_clear) begin
        queue_length <= 0;
    end else if (queue_pop) begin
        for (kdx = 0; kdx < 15; kdx = kdx + 1) begin
            queue[kdx] <= queue[kdx + 1];
        end
        queue[15] <= BOARD_EMPTY;
        queue_length <= queue_length - 1;
    end else if (queue_add) begin
        queue[queue_length] <= queue_data;
        queue_length <= queue_length + 1;
    end
end

// ghost block
reg ghost_calc = 0;
reg [5:0] ghost_piece_y = 0;

// rotation test datum
reg [2:0] datum_index = 0;
wire signed [3:0] datum_x_off;
wire signed [5:0] datum_y_off;
wire signed [3:0] datum_x_off_test;
wire signed [5:0] datum_y_off_test;
wire signed [3:0] datum_x;
wire signed [5:0] datum_y;

tetromino_rotate_datum datum1(piece, rotation, datum_index, datum_x_off, datum_y_off);
tetromino_rotate_datum datum2(piece, test_rotation, datum_index, datum_x_off_test, datum_y_off_test);

assign datum_x = (datum_x_off - datum_x_off_test);
assign datum_y = (datum_y_off - datum_y_off_test);

parameter S_PIECE_COUNTDOWN       = 0, S_PIECE_BOARD_CLEARUP   = 1,
          S_PIECE_PREPARE_QUEUE_0 = 2, S_PIECE_PREPARE_QUEUE_1 = 3,
          S_PIECE_PREPARE_QUEUE_2 = 4, S_PIECE_SETUP           = 5,
          S_PIECE_SPAWN_DETECT    = 6, S_PIECE_DROP            = 7;

parameter S_PIECE_PLACE   =  8, S_PIECE_PLACE_0 =  9, S_PIECE_PLACE_1 = 10,
          S_PIECE_PLACE_2 = 11, S_PIECE_PLACE_3 = 12;

parameter S_PIECE_LINE_CLEAR_GRAVITY = 13;
parameter S_PIECE_LINE_CLEAR_GRAVITY_WIPE = 14;
parameter S_PIECE_ARE = 15;

reg [3:0] P_piece;
reg [3:0] P_next_piece;

wire [3:0] piece_x_off[0:2];
wire [5:0] piece_y_off[0:2];

reg [2:0] P_test;
reg [2:0] P_next_test;
reg [2:0] nP_next_test;

always @(negedge clk) begin
    if (reset_n == 1'b0) begin
        P_piece <= S_PIECE_COUNTDOWN;
        P_test <= 0;
    end else begin
        P_piece <= P_next_piece;
        P_test <= P_next_test;
    end
end

always @(posedge clk) begin
    if (P_next_main != S_GAMEPLAY) begin
        P_next_piece <= S_PIECE_COUNTDOWN;
        game_over <= 1'b0;
    end
    else begin
        case (P_piece)
            S_PIECE_COUNTDOWN: begin
                P_next_piece <= S_PIECE_BOARD_CLEARUP;
                DAS_cnt <= 0;
                hold_piece <= BOARD_EMPTY;
                hold_able <= 1'b1;
                game_over <= 1'b0;
                queue_pop <= 1'b0;
                queue_add <= 1'b0;
                queue_cnt <= 0;
                queue_clear <= 1'b1;
                line_x <= 0;
                line_y_write <= 0;
            end
            S_PIECE_BOARD_CLEARUP: begin
                block_x <= line_x;
                block_y <= line_y_write;
                block_data <= BOARD_EMPTY;
                if (line_y_write == 40) begin
                    block_write <= 1'b0;
                    P_next_piece <= S_PIECE_PREPARE_QUEUE_0;
                end
                else begin
                    block_write <= 1'b1;
                end
                if (line_x == 9) begin
                    line_x <= 0;
                    line_y_write <= line_y_write + 1;
                end
                else begin
                    line_x <= line_x + 1;
                end
            end
            S_PIECE_PREPARE_QUEUE_0: begin
                queue_clear <= 1'b0;
                if (queue_length < 7) begin
                    P_next_piece <= S_PIECE_PREPARE_QUEUE_1;
                end
                else begin
                    P_next_piece <= S_PIECE_SETUP;
                end
                queue_add <= 1'b0;
                queue_cnt <= 6;
                permute_latch <= 1'b1;
            end
            S_PIECE_PREPARE_QUEUE_1: begin
                permute_latch <= 1'b0;
                queue_data <= permute_out;
                queue_cnt <= queue_cnt - 1;
                queue_add <= 1'b1;
                if (queue_cnt == 0) begin
                    P_next_piece <= S_PIECE_PREPARE_QUEUE_2;
                end
            end
            S_PIECE_PREPARE_QUEUE_2: begin
                queue_add <= 1'b0;
                P_next_piece <= S_PIECE_SETUP;
            end
            S_PIECE_SETUP: begin
                if (hold_able || piece == BOARD_EMPTY) begin
                    // !hold_able => player just hold a piece
                    // piece == BOARD_EMPTY => no hold piece to swap with

                    // Pull a piece from the queue
                    piece <= queue[0];
                    queue_pop <= 1'b1;
                end
                piece_x <= 4;
                piece_y <= 21;
                test_x <= 4;
                test_y <= 21;
                // IRS
                if (btn_rot) begin
                    rotation <= ROTATION_1;
                    test_rotation <= ROTATION_1;
                    btn_rot_debounce <= 1'b1; // prevent double rotation
                end
                else begin
                    rotation <= ROTATION_0;
                    test_rotation <= ROTATION_0;
                end

                P_next_piece <= S_PIECE_SPAWN_DETECT;
                ARE_cnt <= Handling_ARE;
                gravity_cnt <= 0;
                test_start <= 1'b1;

                lock_cnt <= 0;
                move_reset <= 0;
            end
            S_PIECE_SPAWN_DETECT: begin
                queue_pop <= 1'b0;
                test_start <= 1'b0;
                if (!test_busy) begin
                    if (test_result) begin
                        P_next_piece <= S_PIECE_DROP;
                    end
                    else begin
                        game_over <= 1'b1;
                    end
                end
            end
            S_PIECE_DROP: begin
                if (clk_frame_pulse) begin
                    // This happeP_next only per frame

                    // DAS
                    if (btn_left ^ btn_right) begin
                        DAS_active <= 1'b1;
                        if (!DAS_active) begin // just active
                            DAS_cnt <= Handling_DAS;
                        end
                        else if (DAS_cnt == 0) begin
                            DAS_cnt <= Handling_ARR;
                        end
                        else begin
                            DAS_cnt <= DAS_cnt - 1;
                        end
                    end
                    else begin
                        DAS_active <= 1'b0;
                    end

                    // gravity
                    if (gravity_cnt >= GRAVITY_FRAMES - 1 || btn_soft_drop && gravity_cnt >= GRAVITY_FRAMES / 6 - 1) begin
                        gravity_cnt <= 0;
                        gravity_trig = 1'b1;
                    end
                    else begin
                        gravity_cnt <= gravity_cnt + 1;
                    end

                    if (btn_left && !btn_right) begin
                        if (!DAS_active || DAS_cnt == 0) begin
                            action <= ACTION_MOVE_L;
                        end
                    end
                    else if (!btn_left && btn_right) begin
                        if (!DAS_active || DAS_cnt == 0) begin
                            action <= ACTION_MOVE_R;
                        end
                    end
                    if (!btn_rot_debounce && btn_rot) begin
                        action <= ACTION_ROT_CW;
                    end
                    btn_rot_debounce <= btn_rot;
                    P_next_test <= 0;
                    // lock delay
                    if (on_ground) begin
                        lock_cnt <= lock_cnt + 1;
                    end
                    if (lock_cnt == 30 - 1 || move_reset == 15) begin
                        action <= ACTION_HARD_DROP;
                    end
                    on_ground_trig_test <= 1'b1; // trigger on ground test
                    ghost_calc <= 1'b1;
                end
                else begin
                    // Handle action (movement test)
                    case (P_test)
                        0: begin // Idle state
                            if (action == ACTION_MOVE_L || action == ACTION_MOVE_R) begin
                                if (action == ACTION_MOVE_L) begin
                                    test_x <= piece_x - 1;
                                end
                                else begin
                                    test_x <= piece_x + 1;
                                end
                                test_y <= piece_y;
                                test_rotation <= rotation;
                                P_next_test <= 1;
                                nP_next_test <= 3;
                            end
                            else if (action == ACTION_ROT_CW ) begin
                                test_rotation <= rotation + 1;
                                P_next_test <= 1;
                                nP_next_test <= 2;
                                datum_index <= 0;
                            end
                            else if (action == ACTION_HARD_DROP) begin
                                test_x <= piece_x;
                                test_y <= piece_y - 1;
                                test_rotation <= rotation;
                                action <= ACTION_NONE;
                                P_next_test <= 1;
                                nP_next_test <= 5;
                            end
                            else if (gravity_trig) begin
                                // handle gravity
                                gravity_trig <= 1'b0;
                                test_x <= piece_x;
                                test_y <= piece_y - 1;
                                test_rotation <= rotation;
                                P_next_test <= 1;
                                nP_next_test <= 4;
                            end
                            else if (on_ground_trig_test) begin
                                on_ground_trig_test <= 1'b0;
                                // on ground test
                                test_x <= piece_x;
                                test_y <= piece_y - 1;
                                test_rotation <= rotation;
                                P_next_test <= 1;
                                nP_next_test <= 6;
                            end
                            else if (ghost_calc) begin
                                // calculate ghost block
                                ghost_calc <= 1'b0;
                                test_x <= piece_x;
                                test_y <= piece_y;
                                test_rotation <= rotation;
                                P_next_test <= 1;
                                nP_next_test <= 7;
                            end
                            else begin
                                P_next_test <= 0;
                                nP_next_test <= 0;
                            end
                            test_start <= 1'b0;
                        end
                        1: begin // start test (delay 1 clk)
                            test_start <= 1'b1;
                            P_next_test <= nP_next_test;
                            if (nP_next_test == 2) begin
                                test_x <= piece_x + datum_x;
                                test_y <= piece_y + datum_y;
                            end
                        end
                        2: begin // rotate test (except O piece)
                            test_start <= 1'b0;
                            if (!test_busy) begin
                                if (test_result) begin
                                    P_next_test <= 4;
                                end
                                else if (datum_index == 4) begin
                                    // test failed
                                    P_next_test <= 0;
                                    action <= ACTION_NONE;
                                end
                                else begin
                                    // run next test datum
                                    datum_index <= datum_index + 1;
                                    P_next_test <= 1;
                                    nP_next_test <= 2;
                                end
                            end
                        end
                        3: begin // oneshot test
                            test_start <= 1'b0;
                            if (!test_busy) begin
                                P_next_test <= 4;
                            end
                        end
                        4: begin // ending state
                            if (!test_busy) begin
                                P_next_test <= 0;
                                action <= ACTION_NONE;
                                if (test_result) begin
                                    piece_x <= test_x;
                                    piece_y <= test_y;
                                    rotation <= test_rotation;
                                    if (lock_cnt != 0) begin
                                        lock_cnt <= 0;
                                        move_reset <= move_reset + 1;
                                    end
                                end
                            end
                        end
                        5: begin // hard drop loop
                            test_start <= 1'b0;
                            if (!test_busy) begin
                                if (test_result) begin
                                    // move down and test again
                                    test_y <= test_y - 1;
                                    test_start <= 1'b1;
                                end
                                else begin
                                    piece_y <= test_y + 1;
                                    P_next_test <= 0;
                                    P_next_piece <= S_PIECE_PLACE;
                                end
                            end
                        end
                        6: begin // on ground test
                            if (!test_busy) begin
                                P_next_test <= 0;
                                on_ground <= !test_result;
                            end
                        end
                        7: begin // ghost block (simulate hard drop loop)
                            test_start <= 1'b0;
                            if (!test_busy) begin
                                if (test_result) begin
                                    // move down and test again
                                    test_y <= test_y - 1;
                                    test_start <= 1'b1;
                                end
                                else begin
                                    ghost_piece_y <= test_y + 1;
                                    P_next_test <= 0;
                                end
                            end
                        end
                    endcase
                end
            end
            S_PIECE_PLACE: begin
                block_data <= piece;
                block_write <= 1'b0;
                P_next_piece <= S_PIECE_PLACE_0;
            end
            S_PIECE_PLACE_0: begin
                block_x <= piece_x;
                block_y <= piece_y;
                block_write <= 1'b1;
                P_next_piece <= S_PIECE_PLACE_1;
            end
            S_PIECE_PLACE_1: begin
                block_x <= piece_x_off[0];
                block_y <= piece_y_off[0];
                P_next_piece <= S_PIECE_PLACE_2;
            end
            S_PIECE_PLACE_2: begin
                block_x <= piece_x_off[1];
                block_y <= piece_y_off[1];
                P_next_piece <= S_PIECE_PLACE_3;
            end
            S_PIECE_PLACE_3: begin
                block_x <= piece_x_off[2];
                block_y <= piece_y_off[2];
                P_next_piece <= S_PIECE_LINE_CLEAR_GRAVITY;
                line_x = 0;
                line_y_scan = 0;
                line_y_write = 0;
                line_empty = 1'b1;
                line_full = 1'b1;
                if (top_out_detect) begin
                    game_over <= 1'b1;
                end
            end
            S_PIECE_LINE_CLEAR_GRAVITY: begin
                block_x <= line_x;
                block_y <= line_y_write;
                block_data <= line_scan;
                if (line_x == 9) begin
                    line_x <= 0;
                    // Note: the 9th column is not detected by line_empty and line_full
                    //       so extra condition is added to mitigate that
                    if (line_empty && line_scan_is_empty) begin
                        line_cleared <= line_y_scan - line_y_write;
                        P_next_piece <= S_PIECE_LINE_CLEAR_GRAVITY_WIPE;
                    end
                    if (!(line_full && !line_scan_is_empty)) begin
                        line_y_write <= line_y_write + 1;
                    end
                    line_y_scan <= line_y_scan + 1;
                    line_empty = 1'b1;
                    line_full = 1'b1;
                end
                else begin
                    line_x <= line_x + 1;
                    line_empty <= line_empty && line_scan_is_empty;
                    line_full <= line_full && !line_scan_is_empty;
                end
            end
            S_PIECE_LINE_CLEAR_GRAVITY_WIPE: begin
                block_x <= line_x;
                block_y <= line_y_write;
                block_data <= BOARD_EMPTY;
                if (line_y_write == line_y_scan) begin
                    P_next_piece <= S_PIECE_ARE;
                end
                if (line_x == 9) begin
                    line_x <= 0;
                    line_y_write <= line_y_write + 1;
                end
                else begin
                    line_x <= line_x + 1;
                end
            end
            S_PIECE_ARE: begin
                block_write <= 1'b0;
                hold_able <= 1'b1;
                if (clk_frame_pulse) begin
                    // This happeP_next only per frame
                    ARE_cnt <= ARE_cnt - 1;
                    if (ARE_cnt == 0) begin
                        P_next_piece <= S_PIECE_PREPARE_QUEUE_0;
                    end
                end
            end
        endcase
    end
end
    
// end of game updater 
//==================================================================
//==================================================================
// rgb controller for vga

    parameter CENTER_W = WIDTH / 2;
    parameter CENTER_H = HEIGHT / 2;
    parameter BLOCK_SIZE = 16;
    parameter LINE_WIDTH = 5;
    parameter LEFT_BOUND = CENTER_W - BLOCK_SIZE * 5;
    parameter RIGHT_BOUND = CENTER_W + BLOCK_SIZE * 5;
    parameter TOP_BOUND = CENTER_H - BLOCK_SIZE * 10;
    parameter BOTTOM_BOUND = CENTER_H + BLOCK_SIZE * 10;

    wire [4:0] index_W;
    wire [3:0] index_neg_W;
    wire index_sign_W;
    wire [5:0] index_H;
    wire [3:0] index_item;
    assign index_W = (pixel_x - LEFT_BOUND) / BLOCK_SIZE;
    assign index_neg_W = 15 - (LEFT_BOUND - pixel_x) / BLOCK_SIZE;
    assign index_sign_W = LEFT_BOUND > pixel_x; // 1 == negative
    assign index_H = (BOTTOM_BOUND - pixel_y) / BLOCK_SIZE;
    assign index_item = board[index_W][index_H];

    Tetromino tetromino1(piece, piece_x, piece_y, rotation
                        , piece_x_off[0], piece_y_off[0]
                        , piece_x_off[1], piece_y_off[1]
                        , piece_x_off[2], piece_y_off[2]);
    wire index_is_piece;
    assign index_is_piece = ((index_W == piece_x && index_H == piece_y)
                          || (index_W == piece_x_off[0] && index_H == piece_y_off[0])
                          || (index_W == piece_x_off[1] && index_H == piece_y_off[1])
                          || (index_W == piece_x_off[2] && index_H == piece_y_off[2]))
                          && (P_piece == S_PIECE_DROP);
                         
    wire [3:0] hold_piece_x_off[0:2];
    wire [5:0] hold_piece_y_off[0:2];
    Tetromino tetromino_hold(hold_piece, 12, 17, ROTATION_0
                            , hold_piece_x_off[0], hold_piece_y_off[0]
                            , hold_piece_x_off[1], hold_piece_y_off[1]
                            , hold_piece_x_off[2], hold_piece_y_off[2]);
    wire hold_piece_render;
    assign hold_piece_render = ((index_neg_W == 12 && index_H == 17)
                             || (index_neg_W == hold_piece_x_off[0] && index_H == hold_piece_y_off[0])
                             || (index_neg_W == hold_piece_x_off[1] && index_H == hold_piece_y_off[1])
                             || (index_neg_W == hold_piece_x_off[2] && index_H == hold_piece_y_off[2]))
                             && hold_piece != BOARD_EMPTY && index_sign_W;

    wire [3:0] queue_piece_x_off[0:4][0:2];
    wire [5:0] queue_piece_y_off[0:4][0:2];
    wire queue_piece_render[0:4];
    Tetromino tetromino_queue0(queue[0], 12, 17, ROTATION_0
                             , queue_piece_x_off[0][0], queue_piece_y_off[0][0]
                             , queue_piece_x_off[0][1], queue_piece_y_off[0][1]
                             , queue_piece_x_off[0][2], queue_piece_y_off[0][2]);
    Tetromino tetromino_queue1(queue[1], 12, 14, ROTATION_0
                             , queue_piece_x_off[1][0], queue_piece_y_off[1][0]
                             , queue_piece_x_off[1][1], queue_piece_y_off[1][1]
                             , queue_piece_x_off[1][2], queue_piece_y_off[1][2]);
    Tetromino tetromino_queue2(queue[2], 12, 11, ROTATION_0
                             , queue_piece_x_off[2][0], queue_piece_y_off[2][0]
                             , queue_piece_x_off[2][1], queue_piece_y_off[2][1]
                             , queue_piece_x_off[2][2], queue_piece_y_off[2][2]);
    Tetromino tetromino_queue3(queue[3], 12, 8, ROTATION_0
                             , queue_piece_x_off[3][0], queue_piece_y_off[3][0]
                             , queue_piece_x_off[3][1], queue_piece_y_off[3][1]
                             , queue_piece_x_off[3][2], queue_piece_y_off[3][2]);
    Tetromino tetromino_queue4(queue[4], 12, 5, ROTATION_0
                             , queue_piece_x_off[4][0], queue_piece_y_off[4][0]
                             , queue_piece_x_off[4][1], queue_piece_y_off[4][1]
                             , queue_piece_x_off[4][2], queue_piece_y_off[4][2]);
    assign queue_piece_render[0] = ((index_W == 12 && index_H == 17)
                                 || (index_W == queue_piece_x_off[0][0] && index_H == queue_piece_y_off[0][0])
                                 || (index_W == queue_piece_x_off[0][1] && index_H == queue_piece_y_off[0][1])
                                 || (index_W == queue_piece_x_off[0][2] && index_H == queue_piece_y_off[0][2]))
                                 && !index_sign_W;
    assign queue_piece_render[1] = ((index_W == 12 && index_H == 14)
                                 || (index_W == queue_piece_x_off[1][0] && index_H == queue_piece_y_off[1][0])
                                 || (index_W == queue_piece_x_off[1][1] && index_H == queue_piece_y_off[1][1])
                                 || (index_W == queue_piece_x_off[1][2] && index_H == queue_piece_y_off[1][2]))
                                 && !index_sign_W;
    assign queue_piece_render[2] = ((index_W == 12 && index_H == 11)
                                 || (index_W == queue_piece_x_off[2][0] && index_H == queue_piece_y_off[2][0])
                                 || (index_W == queue_piece_x_off[2][1] && index_H == queue_piece_y_off[2][1])
                                 || (index_W == queue_piece_x_off[2][2] && index_H == queue_piece_y_off[2][2]))
                                 && !index_sign_W;
    assign queue_piece_render[3] = ((index_W == 12 && index_H == 8)
                                 || (index_W == queue_piece_x_off[3][0] && index_H == queue_piece_y_off[3][0])
                                 || (index_W == queue_piece_x_off[3][1] && index_H == queue_piece_y_off[3][1])
                                 || (index_W == queue_piece_x_off[3][2] && index_H == queue_piece_y_off[3][2]))
                                 && !index_sign_W;
    assign queue_piece_render[4] = ((index_W == 12 && index_H == 5)
                                 || (index_W == queue_piece_x_off[4][0] && index_H == queue_piece_y_off[4][0])
                                 || (index_W == queue_piece_x_off[4][1] && index_H == queue_piece_y_off[4][1])
                                 || (index_W == queue_piece_x_off[4][2] && index_H == queue_piece_y_off[4][2]))
                                 && !index_sign_W;
    assign queue_piece_render_all = (queue_piece_render[0] || queue_piece_render[1] || queue_piece_render[2]
                                  || queue_piece_render[3] || queue_piece_render[4]);

    wire [3:0] ghost_piece_x_off[0:2];
    wire [5:0] ghost_piece_y_off[0:2];
    Tetromino tetromino_ghost(piece, piece_x, ghost_piece_y, rotation
                            , ghost_piece_x_off[0], ghost_piece_y_off[0]
                            , ghost_piece_x_off[1], ghost_piece_y_off[1]
                            , ghost_piece_x_off[2], ghost_piece_y_off[2]);
    wire ghost_piece_render;
    assign ghost_piece_render = ((index_W == piece_x && index_H == ghost_piece_y)
                              || (index_W == piece_x_off[0] && index_H == ghost_piece_y_off[0])
                              || (index_W == piece_x_off[1] && index_H == ghost_piece_y_off[1])
                              || (index_W == piece_x_off[2] && index_H == ghost_piece_y_off[2]))
                              && (P_piece == S_PIECE_DROP) && !index_sign_W;
    
    always@(posedge clk) begin
        if(pixel_tick) rgb_reg <= rgb_next;
    end
    
    always @(*) begin
        if (vedio_on) begin
            if ((
                    (pixel_x >= LEFT_BOUND - LINE_WIDTH && pixel_x < LEFT_BOUND
                    || pixel_x >= RIGHT_BOUND && pixel_x < RIGHT_BOUND + LINE_WIDTH)
                    && (pixel_y > TOP_BOUND && pixel_y < BOTTOM_BOUND + LINE_WIDTH)
                )||(
                    pixel_x >= LEFT_BOUND && pixel_x <= RIGHT_BOUND
                    && pixel_y >= BOTTOM_BOUND && pixel_y < BOTTOM_BOUND + LINE_WIDTH
                )) begin
                rgb_next <= 12'ha_a_a;
            end
            else if (ghost_piece_render && !index_is_piece) begin
                // ghost block
                rgb_next <= 12'h6_6_6;
            end
            else if (pixel_x >= LEFT_BOUND && pixel_x < RIGHT_BOUND && pixel_y < BOTTOM_BOUND
                     && (!(index_H >= 20 && index_item == BOARD_EMPTY) || index_is_piece)
                     || hold_piece_render || queue_piece_render_all) begin
                case (index_is_piece        ? piece      : (
                      hold_piece_render     ? hold_piece : (
                      queue_piece_render[0] ? queue[0]   : (
                      queue_piece_render[1] ? queue[1]   : (
                      queue_piece_render[2] ? queue[2]   : (
                      queue_piece_render[3] ? queue[3]   : (
                      queue_piece_render[4] ? queue[4]   : (
                                              index_item
                      ))))))))
                    BOARD_L: begin rgb_next <= 12'hf_8_0; end
                    BOARD_J: begin rgb_next <= 12'h0_0_f; end
                    BOARD_I: begin rgb_next <= 12'h0_f_f; end
                    BOARD_O: begin rgb_next <= 12'hf_f_0; end
                    BOARD_Z: begin rgb_next <= 12'hf_0_0; end
                    BOARD_S: begin rgb_next <= 12'h0_f_0; end
                    BOARD_T: begin rgb_next <= 12'h8_0_8; end
                    //BOARD_GARBAGE: begin rgb_next <= 12'h8_8_8; end
                    default: begin rgb_next <= 12'h0_0_0; end
                endcase
            end
            else begin
                // background
                rgb_next <= 12'h2_2_2;
            end
        end
        else begin
            // out of range
            rgb_next <= 12'h2_2_2;
        end
    end

// end of rgb controller for vga
//==================================================================
endmodule