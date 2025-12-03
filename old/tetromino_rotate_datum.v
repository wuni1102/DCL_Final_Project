`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/23 13:53:57
// Design Name: 
// Module Name: tetromino_rotate_datum
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


module tetromino_rotate_datum(
    input [3:0] piece,
    input [1:0] rotation,
    input [2:0] index,
    output reg signed [3:0] x_off,
    output reg signed [5:0] y_off
    );

    parameter BOARD_EMPTY = 0;
    parameter BOARD_L = 1;
    parameter BOARD_J = 2;
    parameter BOARD_I = 3;
    parameter BOARD_O = 4;
    parameter BOARD_Z = 5;
    parameter BOARD_S = 6;
    parameter BOARD_T = 7;
    //parameter BOARD_GARBAGE = 8;
    parameter ROTATION_0 = 0;
    parameter ROTATION_R = 1;
    parameter ROTATION_2 = 2;
    parameter ROTATION_L = 3;

    always @(*) begin
        case (piece)
            BOARD_O: begin
                case (rotation)
                    ROTATION_0: begin x_off <=  0; y_off <=  0; end
                    ROTATION_R: begin x_off <=  0; y_off <= -1; end
                    ROTATION_2: begin x_off <= -1; y_off <= -1; end
                    ROTATION_L: begin x_off <= -1; y_off <=  0; end
                endcase
            end
            BOARD_I: begin
                case (rotation)
                    ROTATION_0: begin
                        case (index)
                            0: begin x_off <=  0; y_off <=  0; end
                            1: begin x_off <= -1; y_off <=  0; end
                            2: begin x_off <=  2; y_off <=  0; end
                            3: begin x_off <= -1; y_off <=  0; end
                            4: begin x_off <=  2; y_off <=  0; end
                        endcase
                    end
                    ROTATION_R: begin
                        case (index)
                            0: begin x_off <= -1; y_off <=  0; end
                            1: begin x_off <=  0; y_off <=  0; end
                            2: begin x_off <=  0; y_off <=  0; end
                            3: begin x_off <=  0; y_off <=  1; end
                            4: begin x_off <=  0; y_off <= -2; end
                        endcase
                    end
                    ROTATION_2: begin
                        case (index)
                            0: begin x_off <= -1; y_off <=  1; end
                            1: begin x_off <=  1; y_off <=  1; end
                            2: begin x_off <= -2; y_off <=  1; end
                            3: begin x_off <=  1; y_off <=  0; end
                            4: begin x_off <= -2; y_off <=  0; end
                        endcase
                    end
                    ROTATION_L: begin
                        case (index)
                            0: begin x_off <=  0; y_off <=  1; end
                            1: begin x_off <=  0; y_off <=  1; end
                            2: begin x_off <=  0; y_off <=  1; end
                            3: begin x_off <=  0; y_off <= -1; end
                            4: begin x_off <=  0; y_off <=  2; end
                        endcase
                    end
                endcase
            end
            default: begin
                case (rotation)
                    ROTATION_0, ROTATION_2: begin
                        x_off <= 0;
                        y_off <= 0;
                    end
                    ROTATION_R: begin
                        case (index)
                            0: begin x_off <=  0; y_off <=  0; end
                            1: begin x_off <=  1; y_off <=  0; end
                            2: begin x_off <=  1; y_off <= -1; end
                            3: begin x_off <=  0; y_off <=  2; end
                            4: begin x_off <=  1; y_off <=  2; end
                        endcase
                    end
                    ROTATION_L: begin
                        case (index)
                            0: begin x_off <=  0; y_off <=  0; end
                            1: begin x_off <= -1; y_off <=  0; end
                            2: begin x_off <= -1; y_off <= -1; end
                            3: begin x_off <=  0; y_off <=  2; end
                            4: begin x_off <= -1; y_off <=  2; end
                        endcase
                    end
                endcase
            end
        endcase
    end
endmodule