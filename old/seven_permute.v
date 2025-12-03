`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/12/23 13:53:08
// Design Name: 
// Module Name: seven_permute
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


module seven_permute(
    input clk, // 100MHz
    input rst, // active low

    input latch,

    input [2:0] in_val,
    output [2:0] out_val
    );

    reg [2:0] rand7 = 1;
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            rand7 <= 1;
        end
        else begin
            rand7[2:1] <= rand7[1:0];
            rand7[0] <= rand7[2] ^ rand7[1];
        end
    end

    reg [2:0] rand6 = 0;
    always @(posedge rand3[1]) begin
        if (rst == 1'b0) begin
            rand6 <= 0;
        end
        else begin
            if (rand6 == 6 - 1) begin
                rand6 <= 0;
            end
            else begin
                rand6 <= rand6 + 1;
            end
        end
    end

    reg [2:0] rand5 = 0;
    always @(posedge clk) begin
        if (rst == 1'b0) begin
            rand5 <= 0;
        end
        else begin
            if (rand5 == 5 - 1) begin
                rand5 <= 0;
            end
            else begin
                rand5 <= rand5 + 1;
            end
        end
    end

    reg [1:0] rand4 = 0;
    always @(posedge rand2) begin
        rand4[1] <= rand4[0];
        rand4[0] <= !rand4[1];
    end

    reg [1:0] rand3 = 1;
    always @(posedge rand4[1]) begin
        if (rst == 1'b0) begin
            rand3 <= 1;
        end
        else begin
            rand3[1] <= rand3[0];
            rand3[0] <= rand3[1] ^ rand3[0];
        end
    end

    reg rand2 = 0;
    always @(posedge clk) begin
        rand2 <= !rand2;
    end

    reg [2:0] rand7_latch = 0;
    reg [2:0] rand6_latch = 0;
    reg [2:0] rand5_latch = 0;
    reg [1:0] rand4_latch = 0;
    reg [1:0] rand3_latch = 0;
    reg       rand2_latch = 0;
    always @(negedge clk) begin
        if (latch) begin
            rand7_latch <= rand7 - 1;
            rand6_latch <= rand6;
            rand5_latch <= rand5;
            rand4_latch <= rand4;
            rand3_latch <= rand3 - 1;
            rand2_latch <= rand2;
        end
    end

    reg [6:0] pool7 = 0;
    reg [5:0] pool6 = 0;
    reg [4:0] pool5 = 0;
    reg [3:0] pool4 = 0;
    reg [2:0] pool3 = 0;
    reg [1:0] pool2 = 0;
    reg [6:0] out_bit = 0;
    always @(*) begin
        case (in_val)
            0: pool7 = 7'b0000001;
            1: pool7 = 7'b0000010;
            2: pool7 = 7'b0000100;
            3: pool7 = 7'b0001000;
            4: pool7 = 7'b0010000;
            5: pool7 = 7'b0100000;
            6: pool7 = 7'b1000000;
        endcase
        out_bit[0] <= pool7[rand7_latch];
        case (rand7_latch)
            0: pool6 <= pool7[6:1];
            1: pool6 <= {pool7[6:2], pool7[0]};
            2: pool6 <= {pool7[6:3], pool7[1:0]};
            3: pool6 <= {pool7[6:4], pool7[2:0]};
            4: pool6 <= {pool7[6:5], pool7[3:0]};
            5: pool6 <= {pool7[6], pool7[4:0]};
            6: pool6 <= pool7[5:0];
        endcase
        out_bit[1] <= pool6[rand6_latch];
        case (rand6_latch)
            0: pool5 <= pool6[5:1];
            1: pool5 <= {pool6[5:2], pool6[0]};
            2: pool5 <= {pool6[5:3], pool6[1:0]};
            3: pool5 <= {pool6[5:4], pool6[2:0]};
            4: pool5 <= {pool6[5], pool6[3:0]};
            5: pool5 <= pool6[4:0];
        endcase
        out_bit[2] <= pool5[rand5_latch];
        case (rand5_latch)
            0: pool4 <= pool5[4:1];
            1: pool4 <= {pool5[4:2], pool5[0]};
            2: pool4 <= {pool5[4:3], pool5[1:0]};
            3: pool4 <= {pool5[4], pool5[2:0]};
            4: pool4 <= pool5[3:0];
        endcase
        out_bit[3] <= pool4[rand4_latch];
        case (rand4_latch)
            0: pool3 <= pool4[3:1];
            1: pool3 <= {pool4[3:2], pool4[0]};
            2: pool3 <= {pool4[3], pool4[1:0]};
            3: pool3 <= pool4[2:0];
        endcase
        out_bit[4] <= pool3[rand3_latch];
        case (rand3_latch)
            0: pool2 <= pool3[2:1];
            1: pool2 <= {pool3[2], pool3[0]};
            2: pool2 <= pool3[1:0];
        endcase
        out_bit[5] <= pool2[rand2_latch];
        out_bit[6] <= pool2[!rand2_latch];
    end

    assign out_val = out_bit[0] ? 1 :
                     out_bit[1] ? 2 :
                     out_bit[2] ? 3 :
                     out_bit[3] ? 4 :
                     out_bit[4] ? 5 :
                     out_bit[5] ? 6 : 7;

endmodule