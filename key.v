`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MSXBO 
// Engineer: tjy
// 
// Create Date: 2019/05/01 13:13:51
// Design Name: key captrue
// Module Name: key
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

module key #
(
    parameter CLK_FREQ = 100000000
)
(
input clk_i,
input key_i,
output key_cap
);
//10ms
parameter CNT_10MS = (CLK_FREQ/100 - 1'b1);
parameter KEY_S0 = 2'd0;
parameter KEY_S1 = 2'd1;
parameter KEY_S2 = 2'd2;
parameter KEY_S3 = 2'd3;

reg [24:0] cnt10ms = 25'd0;
reg [1:0] key_s = 2'b0;
reg [1:0] key_s_r = 2'b0;
wire en_10ms ;
 
assign en_10ms = (cnt10ms == CNT_10MS);
assign key_cap = (key_s==KEY_S2)&&(key_s_r==KEY_S1);

always @(posedge clk_i)begin
    if(cnt10ms < CNT_10MS) 
        cnt10ms <= cnt10ms + 1'b1;
    else 
        cnt10ms <= 25'd0;
end

always @(posedge clk_i)begin
    key_s_r <= key_s;
end

always @(posedge clk_i)begin
    if(en_10ms)begin
        case(key_s)
        KEY_S0:begin
           if(!key_i)
               key_s <= KEY_S1; 
        end  
        KEY_S1:begin
           if(!key_i)
               key_s <= KEY_S2; 
            else 
               key_s <= KEY_S0; 
        end 
        KEY_S2:begin
           if(key_i)
               key_s <= KEY_S3; 
        end  
        KEY_S3:begin
           if(key_i)
              key_s <= KEY_S0;
            else   
              key_s <= KEY_S2; 
        end
        endcase                  
    end
end


endmodule
