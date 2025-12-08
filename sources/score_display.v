`timescale 1ns / 1ps

module score_display(
    input [9:0] pixel_x,
    input [9:0] pixel_y,
    input [15:0] score,
    input [9:0] display_x_start,
    input [9:0] display_y_start,
    output reg is_score_pixel,
    output reg [11:0] score_color
);

    // 數字字型定義 (5x7 點陣) - 修正為由上到下的順序
    reg [4:0] digit_pattern[0:9][0:6];
    
    initial begin
        // 0 (從上到下)
        digit_pattern[0][0] = 5'b01110;
        digit_pattern[0][1] = 5'b10001;
        digit_pattern[0][2] = 5'b10011;
        digit_pattern[0][3] = 5'b10101;
        digit_pattern[0][4] = 5'b11001;
        digit_pattern[0][5] = 5'b10001;
        digit_pattern[0][6] = 5'b01110;
        
        // 1
        digit_pattern[1][0] = 5'b00100;
        digit_pattern[1][1] = 5'b01100;
        digit_pattern[1][2] = 5'b00100;
        digit_pattern[1][3] = 5'b00100;
        digit_pattern[1][4] = 5'b00100;
        digit_pattern[1][5] = 5'b00100;
        digit_pattern[1][6] = 5'b01110;
        
        // 2
        digit_pattern[2][0] = 5'b01110;
        digit_pattern[2][1] = 5'b10001;
        digit_pattern[2][2] = 5'b00001;
        digit_pattern[2][3] = 5'b00010;
        digit_pattern[2][4] = 5'b00100;
        digit_pattern[2][5] = 5'b01000;
        digit_pattern[2][6] = 5'b11111;
        
        // 3
        digit_pattern[3][0] = 5'b01110;
        digit_pattern[3][1] = 5'b10001;
        digit_pattern[3][2] = 5'b00001;
        digit_pattern[3][3] = 5'b00110;
        digit_pattern[3][4] = 5'b00001;
        digit_pattern[3][5] = 5'b10001;
        digit_pattern[3][6] = 5'b01110;
        
        // 4
        digit_pattern[4][0] = 5'b00010;
        digit_pattern[4][1] = 5'b00110;
        digit_pattern[4][2] = 5'b01010;
        digit_pattern[4][3] = 5'b10010;
        digit_pattern[4][4] = 5'b11111;
        digit_pattern[4][5] = 5'b00010;
        digit_pattern[4][6] = 5'b00010;
        
        // 5
        digit_pattern[5][0] = 5'b11111;
        digit_pattern[5][1] = 5'b10000;
        digit_pattern[5][2] = 5'b11110;
        digit_pattern[5][3] = 5'b00001;
        digit_pattern[5][4] = 5'b00001;
        digit_pattern[5][5] = 5'b10001;
        digit_pattern[5][6] = 5'b01110;
        
        // 6
        digit_pattern[6][0] = 5'b01110;
        digit_pattern[6][1] = 5'b10000;
        digit_pattern[6][2] = 5'b10000;
        digit_pattern[6][3] = 5'b11110;
        digit_pattern[6][4] = 5'b10001;
        digit_pattern[6][5] = 5'b10001;
        digit_pattern[6][6] = 5'b01110;
        
        // 7
        digit_pattern[7][0] = 5'b11111;
        digit_pattern[7][1] = 5'b00001;
        digit_pattern[7][2] = 5'b00010;
        digit_pattern[7][3] = 5'b00100;
        digit_pattern[7][4] = 5'b01000;
        digit_pattern[7][5] = 5'b01000;
        digit_pattern[7][6] = 5'b01000;
        
        // 8
        digit_pattern[8][0] = 5'b01110;
        digit_pattern[8][1] = 5'b10001;
        digit_pattern[8][2] = 5'b10001;
        digit_pattern[8][3] = 5'b01110;
        digit_pattern[8][4] = 5'b10001;
        digit_pattern[8][5] = 5'b10001;
        digit_pattern[8][6] = 5'b01110;
        
        // 9
        digit_pattern[9][0] = 5'b01110;
        digit_pattern[9][1] = 5'b10001;
        digit_pattern[9][2] = 5'b10001;
        digit_pattern[9][3] = 5'b01111;
        digit_pattern[9][4] = 5'b00001;
        digit_pattern[9][5] = 5'b00001;
        digit_pattern[9][6] = 5'b01110;
    end

    // 放大倍數
    parameter SCALE = 2;
    parameter DIGIT_WIDTH = 5 * SCALE;
    parameter DIGIT_HEIGHT = 7 * SCALE;
    parameter DIGIT_SPACING = 2 * SCALE;
    
    // 計算相對位置
    wire [9:0] rel_x = pixel_x - display_x_start;
    wire [9:0] rel_y = pixel_y - display_y_start;
    
    // 分數各位數
    wire [3:0] digit_10000 = score / 10000;
    wire [3:0] digit_1000 = (score / 1000) % 10;
    wire [3:0] digit_100 = (score / 100) % 10;
    wire [3:0] digit_10 = (score / 10) % 10;
    wire [3:0] digit_1 = score % 10;
    
    // 判斷當前像素是否在某個數字範圍內
    wire in_digit_0 = (rel_x >= 0) && (rel_x < DIGIT_WIDTH) && 
                      (rel_y >= 8) && (rel_y < 8 + DIGIT_HEIGHT);
    wire in_digit_1 = (rel_x >= DIGIT_WIDTH + DIGIT_SPACING) && 
                      (rel_x < 2*DIGIT_WIDTH + DIGIT_SPACING) && 
                      (rel_y >= 8) && (rel_y < 8 + DIGIT_HEIGHT);
    wire in_digit_2 = (rel_x >= 2*(DIGIT_WIDTH + DIGIT_SPACING)) && 
                      (rel_x < 3*DIGIT_WIDTH + 2*DIGIT_SPACING) && 
                      (rel_y >= 8) && (rel_y < 8 + DIGIT_HEIGHT);
    wire in_digit_3 = (rel_x >= 3*(DIGIT_WIDTH + DIGIT_SPACING)) && 
                      (rel_x < 4*DIGIT_WIDTH + 3*DIGIT_SPACING) && 
                      (rel_y >= 8) && (rel_y < 8 + DIGIT_HEIGHT);
    wire in_digit_4 = (rel_x >= 4*(DIGIT_WIDTH + DIGIT_SPACING)) && 
                      (rel_x < 5*DIGIT_WIDTH + 4*DIGIT_SPACING) && 
                      (rel_y >= 8) && (rel_y < 8 + DIGIT_HEIGHT);
    
    // 獲取當前數字的點陣位置
    reg [2:0] pattern_x;
    reg [2:0] pattern_y;
    reg [3:0] current_digit;
    reg pixel_on;
    
    always @(*) begin
        is_score_pixel = 0;
        score_color = 12'h0_0_0;
        pixel_on = 0;
        
        if (in_digit_0) begin
            pattern_x = (rel_x) / SCALE;
            pattern_y = (rel_y - 8) / SCALE;
            current_digit = digit_10000;
            pixel_on = digit_pattern[current_digit][pattern_y][4 - pattern_x];
            is_score_pixel = 1;
        end
        else if (in_digit_1) begin
            pattern_x = (rel_x - (DIGIT_WIDTH + DIGIT_SPACING)) / SCALE;
            pattern_y = (rel_y - 8) / SCALE;
            current_digit = digit_1000;
            pixel_on = digit_pattern[current_digit][pattern_y][4 - pattern_x];
            is_score_pixel = 1;
        end
        else if (in_digit_2) begin
            pattern_x = (rel_x - 2*(DIGIT_WIDTH + DIGIT_SPACING)) / SCALE;
            pattern_y = (rel_y - 8) / SCALE;
            current_digit = digit_100;
            pixel_on = digit_pattern[current_digit][pattern_y][4 - pattern_x];
            is_score_pixel = 1;
        end
        else if (in_digit_3) begin
            pattern_x = (rel_x - 3*(DIGIT_WIDTH + DIGIT_SPACING)) / SCALE;
            pattern_y = (rel_y - 8) / SCALE;
            current_digit = digit_10;
            pixel_on = digit_pattern[current_digit][pattern_y][4 - pattern_x];
            is_score_pixel = 1;
        end
        else if (in_digit_4) begin
            pattern_x = (rel_x - 4*(DIGIT_WIDTH + DIGIT_SPACING)) / SCALE;
            pattern_y = (rel_y - 8) / SCALE;
            current_digit = digit_1;
            pixel_on = digit_pattern[current_digit][pattern_y][4 - pattern_x];
            is_score_pixel = 1;
        end
        
        // 設定顏色
        if (is_score_pixel) begin
            if (pixel_on)
                score_color = 12'hF_F_0; // 黃色數字
            else
                score_color = 12'h3_0_0;
        end
    end

endmodule