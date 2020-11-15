`timescale 1ns / 1ps
/*
Company : Liyang Milian Electronic Technology Co., Ltd.
Brand: 米联客(msxbo)
Technical forum:uisrc.com
taobao: osrc.taobao.com
Create Date: 2019/12/17
Module Name: fdma_ctr_adc
Description: 
Copyright: Copyright (c) msxbo
Revision: 1.0
Signal description:
1) _i input
2) _o output
3) _n activ low
4) _dg debug signal 
5) _r delay or register
6) _s state mechine
*/
//////////////////////////////////////////////////////////////////////////////////

module fdma_ctr_adc#
(
parameter  integer  ADDR_OFFSET = 0,
parameter  integer  AXI_BURST_LEN  = 8, 
parameter  integer  AXI_DATA_WIDTH = 128,                
parameter  integer  FDMA_BUF_SIZE = 2,
parameter  integer  FDMA_BUF_LEN  = 32// FDMA_BUF_LEN*4 BYTES 			
)
(
    input           ui_clk,
    input           ui_rstn,
//sensor input -W0_FIFO--------------
//    input           W0_FS_i,
    input           W0_wclk_i,
    input           W0_wren_i,
    input  [127:0]   W0_data_i, 
//----------fdma signals write-------       
    output  reg    pkg_wr_areq,       
    input           pkg_wr_en,
    input           pkg_wr_last,
    output  [31:0]  pkg_wr_addr,
    output  [127:0]    pkg_wr_data,
    output  [31:0]  pkg_wr_size,
    output  reg [1 :0]  xdma_irq_req        
    );
    
parameter FBUF_SIZE   = FDMA_BUF_SIZE -1'b1;  // 1          // 8*32/8=32 字节
parameter BURST_SIZE  = AXI_BURST_LEN*AXI_DATA_WIDTH/8;//BYTES 设置FDMA 每次burst大小正好等于 AXI4总线burst大小,如果这里设置成4倍的AXI_BURST_LEN*AXI_DATA_WIDTH/8，那么只要burst 1次（BURST_TIMES），FIFO也得改
parameter PKG_SIZE    = AXI_BURST_LEN;// lenth of AXI_DATA_WIDTH   8
parameter BURST_TIMES = FDMA_BUF_LEN/(BURST_SIZE/4);//计算为了传输FDMA_BUF_LEN量 数据，需要多少次FDMA burst  8*4/32
assign pkg_wr_size = PKG_SIZE;//256*128 =4KB 和FDMA的参数设置一致，每次最大传输4KB,总线效率最高  //
//------------vs 滤波---------------// 8*32bit= 8*4=32 byte
//reg  W0_FIFO_Rst; 
parameter S_IDLE  =  2'd0;  
parameter S_RST   =  2'd1;  
parameter S_DATA1 =  2'd2;   
parameter S_DATA2 =  2'd3; 

reg [1 :0]  W_MS;
reg [13:0]  W0_addr;
reg [31 :0] W0_fcnt;
reg [10 :0] W0_bcnt;
wire[9 :0]  W0_rcnt;
reg W0_REQ;

reg [6:0] W0_Fbuf;
wire  [3:0] Fbuf = (W0_Fbuf==0) ? FBUF_SIZE : (W0_Fbuf - 1);

always @(posedge ui_clk)begin
    if(!ui_rstn)begin
        xdma_irq_req <= 2'd0;
    end
    else begin
        xdma_irq_req <= 0;
        xdma_irq_req[Fbuf] <= 1'b1;
    end
end

assign pkg_wr_addr = {11'd0,W0_Fbuf,W0_addr}+ ADDR_OFFSET;
//assign pkg_wr_data = {32'hffff0000,32'hffff1111,32'haaaa0000,W0_fcnt};
//--------一副图像写入DDR------------
 always @(posedge ui_clk) begin
    if(!ui_rstn)begin
        W_MS <= S_IDLE;
        W0_addr <= 14'd0;
        pkg_wr_areq <= 1'd0;
        W0_fcnt  <= 0;
        W0_bcnt  <= 0;
        W0_Fbuf  <= 7'd0;
    end
    else begin
      case(W_MS)
       S_IDLE:begin
          W0_addr  <= 14'd0;
          W0_fcnt  <= 0;
          W0_bcnt  <= 11'd0;
          W_MS <= S_RST;
       end
       S_RST:begin
          if(W0_fcnt > 8'd30 ) W_MS <= S_DATA1;
          W0_fcnt <= W0_fcnt +1'd1;
        end          
        S_DATA1:begin 
            if(W0_bcnt == BURST_TIMES) begin
                if(W0_Fbuf == FBUF_SIZE) 
                    W0_Fbuf <= 7'd0;
                 else 
                    W0_Fbuf <= W0_Fbuf + 1'b1; 
                 W_MS <= S_IDLE;
            end
            else if(W0_REQ) begin
                W0_fcnt <=0;
                pkg_wr_areq <= 1'b1;
                W_MS <= S_DATA2;  
            end           
         end
         S_DATA2:begin
            pkg_wr_areq <= 1'b0;
            if(pkg_wr_last)begin
                W_MS <= S_DATA1; 
                W0_bcnt <= W0_bcnt + 1'd1; 
                W0_addr <= W0_addr + BURST_SIZE;
            end
         end
       endcase
    end
 end 


// always@(posedge ui_clk)
// begin     
//     W0_REQ    <= (W0_rcnt  > PKG_SIZE - 2); 
// end
 
 always@(posedge ui_clk)
 begin     
     W0_REQ    <= ( W0_rcnt  > 0 ); 
 end
 
 wire [127:0]fifo_data;
 assign pkg_wr_data={
                     fifo_data[127 : 0]
                     };

W0_FIFO W0_FIFO_0 (
  .rst(~ui_rstn),  // input wire rst
  .wr_clk(W0_wclk_i),  // input wire wr_clk
  .din(W0_data_i),        // input wire [127 : 0] din
  .wr_en(W0_wren_i),    // input wire wr_en
  
  .rd_clk(ui_clk),  // input wire rd_clk 
  .rd_en(pkg_wr_en),    // input wire rd_en
  .dout(fifo_data),      // output wire [127 : 0] dout
  .rd_data_count(W0_rcnt)  // output wire [10 : 0] wr_data_count
);


endmodule
