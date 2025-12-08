`timescale 1ns / 1ps

module text_display(
    input [9:0] pixel_x,
    input [9:0] pixel_y,
    input [9:0] display_x_start,
    input [9:0] display_y_start,
    input [7:0] text_type,  // 0: "GAME OVER", 1: "USE SW0 TO START"
    output reg is_text_pixel,
    output reg [11:0] text_color
);

    // 字型定義 (5x7 點陣)
    reg [4:0] char_pattern[0:25][0:6];  // A-Z
    
    initial begin
        // G
        char_pattern[6][0] = 5'b01110;
        char_pattern[6][1] = 5'b10001;
        char_pattern[6][2] = 5'b10000;
        char_pattern[6][3] = 5'b10011;
        char_pattern[6][4] = 5'b10001;
        char_pattern[6][5] = 5'b10001;
        char_pattern[6][6] = 5'b01110;
        
        // A
        char_pattern[0][0] = 5'b01110;
        char_pattern[0][1] = 5'b10001;
        char_pattern[0][2] = 5'b10001;
        char_pattern[0][3] = 5'b11111;
        char_pattern[0][4] = 5'b10001;
        char_pattern[0][5] = 5'b10001;
        char_pattern[0][6] = 5'b10001;
        
        // M
        char_pattern[12][0] = 5'b10001;
        char_pattern[12][1] = 5'b11011;
        char_pattern[12][2] = 5'b10101;
        char_pattern[12][3] = 5'b10101;
        char_pattern[12][4] = 5'b10001;
        char_pattern[12][5] = 5'b10001;
        char_pattern[12][6] = 5'b10001;
        
        // E
        char_pattern[4][0] = 5'b11111;
        char_pattern[4][1] = 5'b10000;
        char_pattern[4][2] = 5'b10000;
        char_pattern[4][3] = 5'b11110;
        char_pattern[4][4] = 5'b10000;
        char_pattern[4][5] = 5'b10000;
        char_pattern[4][6] = 5'b11111;
        
        // O
        char_pattern[14][0] = 5'b01110;
        char_pattern[14][1] = 5'b10001;
        char_pattern[14][2] = 5'b10001;
        char_pattern[14][3] = 5'b10001;
        char_pattern[14][4] = 5'b10001;
        char_pattern[14][5] = 5'b10001;
        char_pattern[14][6] = 5'b01110;
        
        // V
        char_pattern[21][0] = 5'b10001;
        char_pattern[21][1] = 5'b10001;
        char_pattern[21][2] = 5'b10001;
        char_pattern[21][3] = 5'b10001;
        char_pattern[21][4] = 5'b10001;
        char_pattern[21][5] = 5'b01010;
        char_pattern[21][6] = 5'b00100;
        
        // R
        char_pattern[17][0] = 5'b11110;
        char_pattern[17][1] = 5'b10001;
        char_pattern[17][2] = 5'b10001;
        char_pattern[17][3] = 5'b11110;
        char_pattern[17][4] = 5'b10100;
        char_pattern[17][5] = 5'b10010;
        char_pattern[17][6] = 5'b10001;
        
        // U
        char_pattern[20][0] = 5'b10001;
        char_pattern[20][1] = 5'b10001;
        char_pattern[20][2] = 5'b10001;
        char_pattern[20][3] = 5'b10001;
        char_pattern[20][4] = 5'b10001;
        char_pattern[20][5] = 5'b10001;
        char_pattern[20][6] = 5'b01110;
        
        // S
        char_pattern[18][0] = 5'b01110;
        char_pattern[18][1] = 5'b10001;
        char_pattern[18][2] = 5'b10000;
        char_pattern[18][3] = 5'b01110;
        char_pattern[18][4] = 5'b00001;
        char_pattern[18][5] = 5'b10001;
        char_pattern[18][6] = 5'b01110;
        
        // W
        char_pattern[22][0] = 5'b10001;
        char_pattern[22][1] = 5'b10001;
        char_pattern[22][2] = 5'b10001;
        char_pattern[22][3] = 5'b10101;
        char_pattern[22][4] = 5'b10101;
        char_pattern[22][5] = 5'b11011;
        char_pattern[22][6] = 5'b10001;
        
        // T
        char_pattern[19][0] = 5'b11111;
        char_pattern[19][1] = 5'b00100;
        char_pattern[19][2] = 5'b00100;
        char_pattern[19][3] = 5'b00100;
        char_pattern[19][4] = 5'b00100;
        char_pattern[19][5] = 5'b00100;
        char_pattern[19][6] = 5'b00100;
    end

    // 數字 0 的定義
    reg [4:0] digit_0_pattern[0:6];
    initial begin
        digit_0_pattern[0] = 5'b01110;
        digit_0_pattern[1] = 5'b10001;
        digit_0_pattern[2] = 5'b10011;
        digit_0_pattern[3] = 5'b10101;
        digit_0_pattern[4] = 5'b11001;
        digit_0_pattern[5] = 5'b10001;
        digit_0_pattern[6] = 5'b01110;
    end

    // 放大倍數
    parameter SCALE = 3;
    parameter CHAR_WIDTH = 5 * SCALE;
    parameter CHAR_HEIGHT = 7 * SCALE;
    parameter CHAR_SPACING = 2 * SCALE;
    
    // 計算相對位置
    wire [9:0] rel_x = pixel_x - display_x_start;
    wire [9:0] rel_y = pixel_y - display_y_start;
    
    // 字元索引對應 (基於 char_pattern 的索引)
    // G=6, A=0, M=12, E=4, O=14, V=21, R=17
    // U=20, S=18, W=22, T=19, 0=26(特殊處理)
    
    reg [4:0] char_index;
    reg [2:0] pattern_x;
    reg [2:0] pattern_y;
    reg pixel_on;
    integer char_num;
    
    always @(*) begin
        is_text_pixel = 0;
        text_color = 12'h0_0_0;
        pixel_on = 0;
        char_index = 0;
        char_num = rel_x / (CHAR_WIDTH + CHAR_SPACING);
        
        if (rel_y >= 0 && rel_y < CHAR_HEIGHT) begin
            pattern_y = rel_y / SCALE;
            
            if (text_type == 0) begin  // "GAME OVER"
                case (char_num)
                    0: char_index = 6;   // G
                    1: char_index = 0;   // A
                    2: char_index = 12;  // M
                    3: char_index = 4;   // E
                    4: char_index = 99;  // Space
                    5: char_index = 14;  // O
                    6: char_index = 21;  // V
                    7: char_index = 4;   // E
                    8: char_index = 17;  // R
                    default: char_index = 99;
                endcase
            end
            else if (text_type == 1) begin  // "USE SW0 TO START"
                case (char_num)
                    0: char_index = 20;  // U
                    1: char_index = 18;  // S
                    2: char_index = 4;   // E
                    3: char_index = 99;  // Space
                    4: char_index = 18;  // S
                    5: char_index = 22;  // W
                    6: char_index = 26;  // 0 (special)
                    7: char_index = 99;  // Space
                    8: char_index = 19;  // T
                    9: char_index = 14;  // O
                    10: char_index = 99; // Space
                    11: char_index = 18; // S
                    12: char_index = 19; // T
                    13: char_index = 0;  // A
                    14: char_index = 17; // R
                    15: char_index = 19; // T
                    default: char_index = 99;
                endcase
            end
            
            if (char_index < 26) begin
                pattern_x = (rel_x % (CHAR_WIDTH + CHAR_SPACING)) / SCALE;
                if (pattern_x < 5) begin
                    pixel_on = char_pattern[char_index][pattern_y][4 - pattern_x];
                    is_text_pixel = 1;
                end
            end
            else if (char_index == 26) begin  // 數字 0
                pattern_x = (rel_x % (CHAR_WIDTH + CHAR_SPACING)) / SCALE;
                if (pattern_x < 5) begin
                    pixel_on = digit_0_pattern[pattern_y][4 - pattern_x];
                    is_text_pixel = 1;
                end
            end
        end
        
        // 設定顏色
        if (is_text_pixel && pixel_on) begin
            if (text_type == 0)
                text_color = 12'hF_0_0;  // 紅色 (GAME OVER)
            else
                text_color = 12'hF_F_0;  // 黃色 (USE SW0 TO START)
        end
        else begin
            text_color = 12'h0_0_0;
        end
    end

endmodule