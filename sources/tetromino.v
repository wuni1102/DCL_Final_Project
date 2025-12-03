`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/23 13:50:23
// Design Name: 
// Module Name: tetromino
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Tetromino(
    input [2:0] piece,
    input [3:0] piece_x,
    input [5:0] piece_y,
    input [1:0] rotation,
    
    output reg [3:0] piece_x_off_0,
    output reg [5:0] piece_y_off_0,
    output reg [3:0] piece_x_off_1,
    output reg [5:0] piece_y_off_1,
    output reg [3:0] piece_x_off_2,
    output reg [5:0] piece_y_off_2
    );
    parameter BOARD_EMPTY = 0;
    parameter BOARD_L = 1;
    parameter BOARD_J = 2;
    parameter BOARD_I = 3;
    parameter BOARD_O = 4;
    parameter BOARD_Z = 5;
    parameter BOARD_S = 6;
    parameter BOARD_T = 7;
    
    parameter ROTATION_0 = 0;
    parameter ROTATION_1 = 1;
    parameter ROTATION_2 = 2;
    parameter ROTATION_3 = 3;

    integer idx;

    reg signed [3:0] x_off[0:2];
    reg signed [5:0] y_off[0:2];
    reg signed [3:0] x_rot_off[0:2];
    reg signed [5:0] y_rot_off[0:2];
    
    always @(*) begin
        case (piece)
            BOARD_L: begin
                x_off[0] <=  1; y_off[0] <=  0;
                x_off[1] <= -1; y_off[1] <=  0;
                x_off[2] <=  1; y_off[2] <=  1;
            end
            BOARD_J: begin
                x_off[0] <=  1; y_off[0] <=  0;
                x_off[1] <= -1; y_off[1] <=  0;
                x_off[2] <= -1; y_off[2] <=  1;
            end
            BOARD_I: begin
                x_off[0] <=  1; y_off[0] <=  0;
                x_off[1] <= -1; y_off[1] <=  0;
                x_off[2] <=  2; y_off[2] <=  0;
            end
            BOARD_O: begin
                x_off[0] <=  1; y_off[0] <=  0;
                x_off[1] <=  1; y_off[1] <=  1;
                x_off[2] <=  0; y_off[2] <=  1;
            end
            BOARD_Z: begin
                x_off[0] <=  0; y_off[0] <=  1;
                x_off[1] <= -1; y_off[1] <=  1;
                x_off[2] <=  1; y_off[2] <=  0;
            end
            BOARD_S: begin
                x_off[0] <=  0; y_off[0] <=  1;
                x_off[1] <=  1; y_off[1] <=  1;
                x_off[2] <= -1; y_off[2] <=  0;
            end
            BOARD_T: begin
                x_off[0] <= -1; y_off[0] <=  0;
                x_off[1] <=  1; y_off[1] <=  0;
                x_off[2] <=  0; y_off[2] <=  1;
            end
        endcase

        for (idx = 0; idx <= 2; idx = idx + 1) begin
            case (rotation)
                ROTATION_0: begin
                    x_rot_off[idx] <=  x_off[idx];
                    y_rot_off[idx] <=  y_off[idx];
                end
                ROTATION_1: begin
                    x_rot_off[idx] <=  y_off[idx];
                    y_rot_off[idx] <= -x_off[idx];
                end
                ROTATION_2: begin
                    x_rot_off[idx] <= -x_off[idx];
                    y_rot_off[idx] <= -y_off[idx];
                end
                ROTATION_3: begin
                    x_rot_off[idx] <= -y_off[idx];
                    y_rot_off[idx] <=  x_off[idx];
                end
            endcase
        end
        piece_x_off_0 <= x_rot_off[0] + piece_x;
        piece_y_off_0 <= y_rot_off[0] + piece_y;
        piece_x_off_1 <= x_rot_off[1] + piece_x;
        piece_y_off_1 <= y_rot_off[1] + piece_y;
        piece_x_off_2 <= x_rot_off[2] + piece_x;
        piece_y_off_2 <= y_rot_off[2] + piece_y;
    end
endmodule