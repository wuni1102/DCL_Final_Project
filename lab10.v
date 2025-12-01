`timescale 1ns / 1ps

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,

    // VGA
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
);

// ============================================================================
// 參數設定
// ============================================================================
localparam VBUF_W = 320;
localparam VBUF_H = 240;

localparam F0_W = 64;
localparam F0_H = 32;
localparam F0_FRAMES = 8;
localparam F0_PIX_PER_FRAME = F0_W * F0_H;

localparam F1_W = 64;
localparam F1_H = 44;
localparam F1_FRAMES = 4;
localparam F1_PIX_PER_FRAME = F1_W * F1_H;

localparam F2_W = 64;
localparam F2_H = 72;
localparam F2_FRAMES = 4;
localparam F2_PIX_PER_FRAME = F2_W * F2_H;

localparam BG_PIX   = VBUF_W * VBUF_H;
localparam RAM0_SIZE = BG_PIX + F0_PIX_PER_FRAME * F0_FRAMES;
localparam RAM1_SIZE = F1_PIX_PER_FRAME * F1_FRAMES;
localparam RAM2_SIZE = F2_PIX_PER_FRAME * F2_FRAMES;

localparam GREEN_KEY = 12'h0f0;

// ============================================================================
// VGA 時脈 & 同步
// ============================================================================
wire vga_clk;
wire video_on, pixel_tick;
wire [9:0] pixel_x, pixel_y;

clk_divider #(.divider(2)) clk_div(
    .clk(clk),
    .reset(~reset_n),
    .clk_out(vga_clk)
);

vga_sync vga0(
    .clk(vga_clk),
    .reset(~reset_n),
    .oHS(VGA_HSYNC),
    .oVS(VGA_VSYNC),
    .visible(video_on),
    .p_tick(pixel_tick),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y)
);

// ============================================================================
// SRAM 控制訊號
// ============================================================================
wire        sram_we  = usr_btn[3];
wire        sram_en  = 1'b1;
wire [11:0] data_in  = 12'h000;

reg [17:0] bg_addr;
reg [17:0] f0_addr;
reg [17:0] f1_addr;
reg [17:0] f2_addr;

wire [11:0] bg_color;
wire [11:0] f0_color;
wire [11:0] f1_color;
wire [11:0] f2_color;
wire [11:0] dummy1, dummy2;

// ============================================================================
// SRAM 實例化
// ============================================================================
sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(18),
    .RAM_SIZE(RAM0_SIZE),
    .FILE("image.mem")
) ram0 (
    .clk(clk),
    .we(sram_we),
    .en(sram_en),
    .addr(bg_addr),
    .addr1(f0_addr),
    .addr2(18'd0),
    .data_i(data_in),
    .data_o(bg_color),
    .data_o1(f0_color)
);

sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(18),
    .RAM_SIZE(RAM1_SIZE),
    .FILE("fish1.mem")
) ram1 (
    .clk(clk),
    .we(sram_we),
    .en(sram_en),
    .addr(f1_addr),
    .addr1(18'd0),
    .addr2(18'd0),
    .data_i(data_in),
    .data_o(f1_color),
    .data_o1(dummy1)
);

sram #(
    .DATA_WIDTH(12),
    .ADDR_WIDTH(18),
    .RAM_SIZE(RAM2_SIZE),
    .FILE("fish2.mem")
) ram2 (
    .clk(clk),
    .we(sram_we),
    .en(sram_en),
    .addr(f2_addr),
    .addr1(18'd0),
    .addr2(18'd0),
    .data_i(data_in),
    .data_o(f2_color),
    .data_o1(dummy2)
);

// ============================================================================
// 魚的狀態
// ============================================================================
reg [31:0] anim_clk;

reg [9:0] f0_x, f0_y;
reg [9:0] f1_x, f1_y;
reg [9:0] f2_x, f2_y;

// 魚的方向：0 = 向右/下，1 = 向左/上
reg f0_dir, f1_dir, f2_dir;

// Switch 控制移動模式：1 = 左右移動，0 = 上下移動
wire f0_horizontal = usr_sw[0];
wire f1_horizontal = usr_sw[1];
wire f2_horizontal = usr_sw[2];

// 速度控制
localparam SPEED0 = 20'd800000;
localparam SPEED1 = 20'd600000;
localparam SPEED2 = 20'd500000;

reg [19:0] speed_cnt0, speed_cnt1, speed_cnt2;

// ============================================================================
// 按鈕 Debouncing
// ============================================================================
wire [2:0] btn_push;

de_bouncing db0(
    .clk(clk),
    .button_click(usr_btn[0]),
    .button_output(btn_push[0])
);

de_bouncing db1(
    .clk(clk),
    .button_click(usr_btn[1]),
    .button_output(btn_push[1])
);

de_bouncing db2(
    .clk(clk),
    .button_click(usr_btn[2]),
    .button_output(btn_push[2])
);

// 按鈕邊緣檢測
reg [2:0] btn_prev;
wire btn0_pressed = btn_push[0] && !btn_prev[0];
wire btn1_pressed = btn_push[1] && !btn_prev[1];
wire btn2_pressed = btn_push[2] && !btn_prev[2];

// ============================================================================
// 魚位置更新邏輯
// ============================================================================
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        anim_clk   <= 0;
        speed_cnt0 <= 0;
        speed_cnt1 <= 0;
        speed_cnt2 <= 0;
        btn_prev   <= 3'b0;
        
        f0_x   <= 10'd0;
        f0_y   <= 10'd80;
        f0_dir <= 1'b0;
        
        f1_x   <= 10'd150;
        f1_y   <= 10'd68;
        f1_dir <= 1'b0;
        
        f2_x   <= 10'd0;
        f2_y   <= 10'd150;
        f2_dir <= 1'b0;
    end 
    else begin
        anim_clk <= anim_clk + 1;
        btn_prev <= btn_push;
        
        // ====== Fish0 ======
        if (btn0_pressed)
            f0_dir <= ~f0_dir;
        
        speed_cnt0 <= speed_cnt0 + 1;
        if (speed_cnt0 >= SPEED0) begin
            speed_cnt0 <= 0;
            if (f0_horizontal) begin
                // 左右移動
                if (f0_dir == 0) begin
                    if (f0_x >= VBUF_W - F0_W)
                        f0_dir <= 1;
                    else
                        f0_x <= f0_x + 1;
                end
                else begin
                    if (f0_x == 0)
                        f0_dir <= 0;
                    else
                        f0_x <= f0_x - 1;
                end
            end
            else begin
                // 上下移動
                if (f0_dir == 0) begin
                    if (f0_y >= VBUF_H - F0_H)
                        f0_dir <= 1;
                    else
                        f0_y <= f0_y + 1;
                end
                else begin
                    if (f0_y == 0)
                        f0_dir <= 0;
                    else
                        f0_y <= f0_y - 1;
                end
            end
        end
        
        // ====== Fish1 ======
        if (btn1_pressed)
            f1_dir <= ~f1_dir;
        
        speed_cnt1 <= speed_cnt1 + 1;
        if (speed_cnt1 >= SPEED1) begin
            speed_cnt1 <= 0;
            if (f1_horizontal) begin
                // 左右移動
                if (f1_dir == 0) begin
                    if (f1_x >= VBUF_W - F1_W)
                        f1_dir <= 1;
                    else
                        f1_x <= f1_x + 1;
                end
                else begin
                    if (f1_x == 0)
                        f1_dir <= 0;
                    else
                        f1_x <= f1_x - 1;
                end
            end
            else begin
                // 上下移動
                if (f1_dir == 0) begin
                    if (f1_y >= VBUF_H - F1_H)
                        f1_dir <= 1;
                    else
                        f1_y <= f1_y + 1;
                end
                else begin
                    if (f1_y == 0)
                        f1_dir <= 0;
                    else
                        f1_y <= f1_y - 1;
                end
            end
        end
        
        // ====== Fish2 ======
        if (btn2_pressed)
            f2_dir <= ~f2_dir;
        
        speed_cnt2 <= speed_cnt2 + 1;
        if (speed_cnt2 >= SPEED2) begin
            speed_cnt2 <= 0;
            if (f2_horizontal) begin
                // 左右移動
                if (f2_dir == 0) begin
                    if (f2_x >= VBUF_W - F2_W)
                        f2_dir <= 1;
                    else
                        f2_x <= f2_x + 1;
                end
                else begin
                    if (f2_x == 0)
                        f2_dir <= 0;
                    else
                        f2_x <= f2_x - 1;
                end
            end
            else begin
                // 上下移動
                if (f2_dir == 0) begin
                    if (f2_y >= VBUF_H - F2_H)
                        f2_dir <= 1;
                    else
                        f2_y <= f2_y + 1;
                end
                else begin
                    if (f2_y == 0)
                        f2_dir <= 0;
                    else
                        f2_y <= f2_y - 1;
                end
            end
        end
    end
end

// ============================================================================
// Fish region 判斷
// ============================================================================
wire fish0_on = (pixel_y >= (f0_y << 1)) &&
                (pixel_y <  ((f0_y + F0_H) << 1)) &&
                (pixel_x >= (f0_x << 1)) &&
                (pixel_x <  ((f0_x + F0_W) << 1));

wire fish1_on = (pixel_y >= (f1_y << 1)) &&
                (pixel_y <  ((f1_y + F1_H) << 1)) &&
                (pixel_x >= (f1_x << 1)) &&
                (pixel_x <  ((f1_x + F1_W) << 1));

wire fish2_on = (pixel_y >= (f2_y << 1)) &&
                (pixel_y <  ((f2_y + F2_H) << 1)) &&
                (pixel_x >= (f2_x << 1)) &&
                (pixel_x <  ((f2_x + F2_W) << 1));

wire any_fish_on = fish0_on | fish1_on | fish2_on;

// ============================================================================
// 位址產生
// ============================================================================
wire [2:0] f0_frame = anim_clk[25:23];
wire [1:0] f1_frame = anim_clk[24:23];
wire [1:0] f2_frame = anim_clk[24:23];

wire [9:0] f0_sx_raw = (pixel_x >> 1) - f0_x;
wire [9:0] f0_sy_raw = (pixel_y >> 1) - f0_y;
wire [9:0] f1_sx_raw = (pixel_x >> 1) - f1_x;
wire [9:0] f1_sy_raw = (pixel_y >> 1) - f1_y;
wire [9:0] f2_sx_raw = (pixel_x >> 1) - f2_x;
wire [9:0] f2_sy_raw = (pixel_y >> 1) - f2_y;

// 水平翻轉：只在左右移動模式下翻轉
wire [9:0] f0_sx_flip = (f0_horizontal && f0_dir) ? (F0_W - 1 - f0_sx_raw) : f0_sx_raw;
wire [9:0] f1_sx_flip = (f1_horizontal && f1_dir) ? (F1_W - 1 - f1_sx_raw) : f1_sx_raw;
wire [9:0] f2_sx_flip = (f2_horizontal && !f2_dir) ? (F2_W - 1 - f2_sx_raw) : f2_sx_raw;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        bg_addr <= 0;
        f0_addr <= 0;
        f1_addr <= 0;
        f2_addr <= 0;
    end 
    else begin
        bg_addr <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);

        if (fish0_on)
            f0_addr <= BG_PIX + f0_frame * F0_PIX_PER_FRAME + f0_sy_raw * F0_W + f0_sx_flip;
        else
            f0_addr <= BG_PIX;

        if (fish1_on)
            f1_addr <= f1_frame * F1_PIX_PER_FRAME + f1_sy_raw * F1_W + f1_sx_flip;
        else
            f1_addr <= 0;

        if (fish2_on)
            f2_addr <= f2_frame * F2_PIX_PER_FRAME + f2_sy_raw * F2_W + f2_sx_flip;
        else
            f2_addr <= 0;
    end
end

// ============================================================================
// RGB 輸出
// ============================================================================
reg [11:0] rgb_reg, rgb_next;
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

wire f0_transparent = (f0_color == GREEN_KEY);
wire f1_transparent = (f1_color == GREEN_KEY);
wire f2_transparent = (f2_color == GREEN_KEY);

always @(posedge vga_clk or negedge reset_n) begin
    if (!reset_n)
        rgb_reg <= 12'h000;
    else if (pixel_tick)
        rgb_reg <= rgb_next;
end

always @(*) begin
    if (!video_on)
        rgb_next = 12'h000;
    else if (fish0_on && !f0_transparent)
        rgb_next = f0_color;
    else if (fish1_on && !f1_transparent)
        rgb_next = f1_color;
    else if (fish2_on && !f2_transparent)
        rgb_next = f2_color;
    else
        rgb_next = bg_color;
end

// ============================================================================
// Debug LEDs
// ============================================================================
assign usr_led[0] = f0_dir;
assign usr_led[1] = f1_dir;
assign usr_led[2] = f2_dir;
assign usr_led[3] = any_fish_on;

endmodule

// ============================================================================
// Debouncing Module
// ============================================================================
module de_bouncing(
    input clk,
    input button_click,
    output reg button_output
);

reg [20:0] timer2;
reg button_stable;

always @(posedge clk) begin
    if (button_click == 1) begin
        if (timer2 < 21'd1000000)
            timer2 <= timer2 + 1;
        else
            button_stable <= 1;
    end
    else begin
        timer2 <= 0;
        button_stable <= 0;
    end
    
    button_output <= button_stable;
end
endmodule