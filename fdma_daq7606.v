`timescale 1ns / 1ps

module fdma_daq7606(
//===========================PS 
inout FIXED_IO_ddr_vrn,
inout FIXED_IO_ddr_vrp,
inout [53:0]FIXED_IO_mio,
inout FIXED_IO_ps_clk,
inout FIXED_IO_ps_porb,
inout FIXED_IO_ps_srstb,
inout [14:0]PS_DDR_addr,
inout [2:0]PS_DDR_ba,
inout PS_DDR_cas_n,
inout PS_DDR_ck_n,
inout PS_DDR_ck_p,
inout PS_DDR_cke,
inout PS_DDR_cs_n,
inout [3:0]PS_DDR_dm,
inout [31:0]PS_DDR_dq,
inout [3:0]PS_DDR_dqs_n,
inout [3:0]PS_DDR_dqs_p,
inout PS_DDR_odt,
inout PS_DDR_ras_n,
inout PS_DDR_reset_n,
inout PS_DDR_we_n,

/////////////////////////////
input sys_clk_p,
input sys_clk_n,

input key_i,
input key_rst,
output reg [3:0] led,
//--------------DAQ7606------------------

input  [15:0]ad_data,          
input  ad_busy,       
input  first_data,         
output [2:0] ad_os,           
output ad_cs,             
output ad_rd,             
output ad_reset,          
output ad_convsta,
//    output ad_convstb,         
output ad_range,

//--------------PCIE---------------------
input  [3:0]pcie_mgt_rxn,
input  [3:0]pcie_mgt_rxp,
output [3:0]pcie_mgt_txn,
output [3:0]pcie_mgt_txp,
input       pcie_resetn,
input       pcie_sys_clk_clk_n,
input       pcie_sys_clk_clk_p


);
    

    (*mark_debug = "true"*) wire pkg_wr_areq;
    (*mark_debug = "true"*) wire pkg_wr_en;
    (*mark_debug = "true"*) wire pkg_wr_last;
    (*mark_debug = "true"*) wire [31 :0]pkg_wr_addr;
    (*mark_debug = "true"*) wire [127:0]pkg_wr_data;
    (*mark_debug = "true"*) wire [31 :0]pkg_wr_size;
    wire [1:0]xdma_irq_req;
    wire ui_clk;
    wire W0_wclk_i;
    wire W0_wren_i;
    wire [127:0]W0_data_i;
    wire irq_rstn;
    wire ui_rstn;
    wire[6:0]wr_buf;
    
    (* ASYNC_REG = "TRUE" *) reg rstn_r1;
    (* ASYNC_REG = "TRUE" *) reg rstn_r2;
    (* ASYNC_REG = "TRUE" *) reg rstn_r3;
    
    always@(posedge ui_clk)begin
        rstn_r1 <= irq_rstn; 
        rstn_r2 <= rstn_r1;
        rstn_r3 <= rstn_r2;
    end

       
// 50M 25M
wire sys_clk_200M;
wire locked,clk25m;
wire clk_50M;
wire ad_clk_i;
  
wire rst_o;
wire ad_rst_i = ~rst_o;
assign ad_clk_i=clk_50M;  

// 差分 变成 单端

 IBUFDS #(
          .DIFF_TERM("FALSE"),       // Differential Termination
          .IBUF_LOW_PWR("TRUE"),     // Low power="TRUE", Highest performance="FALSE" 
          .IOSTANDARD("DEFAULT")     // Specify the input I/O standard
       ) IBUFDS_inst (
          .O(sys_clk_200M),  // Buffer output
          .I(sys_clk_p),  // Diff_p buffer input (connect directly to top-level port)
          .IB(sys_clk_n) // Diff_n buffer input (connect directly to top-level port)
       );

clk_wiz_0  clk_7606_inst(
 .clk_out1(clk_50M),
 .clk_out2(clk25m),
 .locked(locked),
 .clk_in1(sys_clk_200M)
 ); 
  
uidelay_0 uidelay_inst (
   .clk_i(clk25m),    // input wire clk_i
   .rstn_i(locked),  // input wire rstn_i
   .rst_o(rst_o)    // output wire rst_o
 ); 


//================================================= AD 转换部分

     wire [15:0]ad_ch1;
     wire [15:0]ad_ch2;
     wire [15:0]ad_ch3;
     wire [15:0]ad_ch4;
     wire [15:0]ad_ch8;
     wire ad_data_valid;  
   ad7606_ctrl ad7606_ctrl_inst
       (
           .clk_i               (ad_clk_i),
           .reset_i             (ad_rst_i),
           .ad_data             (ad_data),     //
           .ad_busy             (ad_busy),   //
           .first_data          (first_data),  // 
           .ad_os               (ad_os),      //
           .ad_cs               (ad_cs),    //
           .ad_rd               (ad_rd),      //
           .ad_reset            (ad_reset),   //
           .ad_convsta          (ad_convsta), //
          // .ad_convstb          (ad_convstb),
           .ad_range            (ad_range),   //
           .ad_ch1_o            (ad_ch1),
           .ad_ch2_o            (ad_ch2),
           .ad_ch3_o            (ad_ch3),
           .ad_ch4_o            (ad_ch4),
           .ad_ch5_o            (),
           .ad_ch6_o            (),
           .ad_ch7_o            (),
           .ad_ch8_o            (ad_ch8),
           .ad_data_valid_o     (ad_data_valid)
           ); 
//=================================================================
wire key_cap;
key#
(
.CLK_FREQ(50000000)
)
key0
(
.clk_i(ad_clk_i),
.key_i(key_i),
.key_cap(key_cap)
);

reg [15:0] key_num;
always@(posedge ad_clk_i or negedge key_rst)
begin
 if(!key_rst)
    begin
      led<=4'b0;
      key_num<=16'b0;
    end
 else if(key_cap)
   begin 
     led<=~led;
     key_num <= key_num+1'b1;
    end 
 else
   begin
     led<=led;
     key_num <= key_num;
   end 
end
   

//---------------fdma image buf controller---------------------------  
assign W0_wclk_i = ad_clk_i;
assign W0_wren_i = key_cap;
assign W0_data_i = { key_num+16'd7,key_num+16'd6,key_num+16'd5,key_num+16'd4,   // 16字节
                     key_num+16'd3,key_num+16'd2,key_num+16'd1, key_num+16'd0};
   
//# ( 
//    .ADDR_OFFSET(0),
//    .AXI_BURST_LEN(256),//AXI4 burst 长度
//    .AXI_DATA_WIDTH(128),//AXI4 数据位宽?                 
//    .FDMA_BUF_SIZE(2),//缓存数量
//    .FDMA_BUF_LEN(4096)//一次FMDA需要Burst的数据量
//    )
    
    fdma_ctr_adc  fdma_ctr_adc
    (
        //FDAM signals
      .ui_clk(ui_clk),
      .ui_rstn(rstn_r3&&ui_rstn),
      //.W0_FS_i(W0_FS_i),
      .W0_wclk_i(W0_wclk_i),
      .W0_wren_i(W0_wren_i),
      .W0_data_i(W0_data_i), 
             
      .pkg_wr_areq(pkg_wr_areq),    
      .pkg_wr_en(pkg_wr_en),
      .pkg_wr_last(pkg_wr_last),
      .pkg_wr_addr(pkg_wr_addr),
      .pkg_wr_data(pkg_wr_data),
      .pkg_wr_size(pkg_wr_size),
      .xdma_irq_req(xdma_irq_req)
     );
  
    
//---------------bd design------------------------------------      
    
system system_i
         (
          .pkg_wr_addr(pkg_wr_addr),
          .pkg_wr_data(pkg_wr_data),
          .pkg_wr_areq(pkg_wr_areq),     
          .pkg_wr_en(pkg_wr_en),
          .pkg_wr_last(pkg_wr_last),
          .pkg_wr_size(pkg_wr_size),

          .pkg_rd_addr(32'd0), 
          .pkg_rd_data(),
          .pkg_rd_areq(1'b0),         
          .pkg_rd_en(),
          .pkg_rd_last(),
          .pkg_rd_size(32'd256),

          .pcie_mgt_rxn(pcie_mgt_rxn),
          .pcie_mgt_rxp(pcie_mgt_rxp),
          .pcie_mgt_txn(pcie_mgt_txn),
          .pcie_mgt_txp(pcie_mgt_txp),
          .pcie_resetn(pcie_resetn),
          .pcie_sys_clk_clk_n(pcie_sys_clk_clk_n),
          .pcie_sys_clk_clk_p(pcie_sys_clk_clk_p),
          
          .user_irq_en_o(irq_rstn),
          .user_irq_req_i(xdma_irq_req),
          .axi_aresetn(ui_rstn),
          .ui_clk(ui_clk)
         
 );  
    
  PS PS_i
      (.FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
       .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
       .FIXED_IO_mio(FIXED_IO_mio),
       .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
       .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
       .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
       .PS_DDR_addr(PS_DDR_addr),
       .PS_DDR_ba(PS_DDR_ba),
       .PS_DDR_cas_n(PS_DDR_cas_n),
       .PS_DDR_ck_n(PS_DDR_ck_n),
       .PS_DDR_ck_p(PS_DDR_ck_p),
       .PS_DDR_cke(PS_DDR_cke),
       .PS_DDR_cs_n(PS_DDR_cs_n),
       .PS_DDR_dm(PS_DDR_dm),
       .PS_DDR_dq(PS_DDR_dq),
       .PS_DDR_dqs_n(PS_DDR_dqs_n),
       .PS_DDR_dqs_p(PS_DDR_dqs_p),
       .PS_DDR_odt(PS_DDR_odt),
       .PS_DDR_ras_n(PS_DDR_ras_n),
       .PS_DDR_reset_n(PS_DDR_reset_n),
       .PS_DDR_we_n(PS_DDR_we_n));
 
    
    
    
endmodule
