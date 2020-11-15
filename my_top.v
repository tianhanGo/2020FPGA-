`timescale 1ns / 1ps

module my_top(
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

input key_i,     //  key3 普通按键 增加计数器
input key_rst,  // 复位按键 key4
output reg [3:0] led, // led[3] 亮灭表示收到4个信号
//--------------DAQ7606------------------

input  [15:0]ad_data,          
input  ad_busy,       
input  first_data,         
output [2:0] ad_os,           
output ad_cs,             
output ad_rd,             
output ad_reset,          
output ad_convstab,       


//--------------PCIE---------------------
input  [3:0]pcie_mgt_rxn,
input  [3:0]pcie_mgt_rxp,
output [3:0]pcie_mgt_txn,
output [3:0]pcie_mgt_txp,
input       pcie_resetn,
input       pcie_sys_clk_clk_n,
input       pcie_sys_clk_clk_p


);
    

    wire pkg_wr_areq;
    wire pkg_wr_en;
    wire pkg_wr_last;
    wire [31 :0]pkg_wr_addr;
    wire [127:0]pkg_wr_data;
    wire [31 :0]pkg_wr_size;
    wire [1:0]xdma_irq_req;
    wire ui_clk;
    wire W0_wclk_i;
(*mark_debug = "true"*)   wire W0_wren_i;
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
wire clk_10M;
  
wire rst_o;
wire ad_rst_i = ~rst_o;


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
 .clk_out3(clk_10M),
 .locked(locked),
 .clk_in1(sys_clk_200M)
 ); 
  
uidelay_0 uidelay_inst (
   .clk_i(clk25m),    // input wire clk_i
   .rstn_i(locked),  // input wire rstn_i
   .rst_o(rst_o)    // output wire rst_o
 ); 


//============================================================================ AD 转换部分

     wire [15:0]ad_ch1;
     wire [15:0]ad_ch2;
     wire [15:0]ad_ch3;
     wire [15:0]ad_ch4;
    
     wire ad_data_valid;  
     
(*mark_debug = "true"*)     reg [15:0] ad_ch1_ready;
     reg [15:0] ad_ch2_ready;
     reg [15:0] ad_ch3_ready;
     reg [15:0] ad_ch4_ready;

   ad7606_ctrl ad7606_ctrl_inst
       (
           .clk_i               (clk_50M),
           .reset_i             (ad_rst_i),
           .ad_data             (ad_data),     //
           .ad_busy             (ad_busy),   //
           .first_data          (first_data),  // 
           .ad_os               (ad_os),      //
           .ad_cs               (ad_cs),    //
           .ad_rd               (ad_rd),      //
           .ad_reset            (ad_reset),   //
           .ad_convsta          (ad_convstab), //
       
           .ad_ch1_o            (ad_ch1),
           .ad_ch2_o            (ad_ch2),
           .ad_ch3_o            (ad_ch3),
           .ad_ch4_o            (ad_ch4),
           .ad_ch5_o            (),
           .ad_ch6_o            (),
           .ad_ch7_o            (),
           .ad_ch8_o            (),
           .ad_data_valid_o     (ad_data_valid)
           ); 
           
//================================================================= 保证同步送进去数据          
always@(posedge clk_50M )
begin
    if( ad_data_valid == 1'b1 )
      begin
        ad_ch1_ready <= ad_ch1;
        ad_ch2_ready <= ad_ch2; 
        ad_ch3_ready <= ad_ch3;
        ad_ch4_ready <= ad_ch4;
      end
     else
      begin
        ad_ch1_ready <= ad_ch1_ready;
        ad_ch2_ready <= ad_ch2_ready;
        ad_ch3_ready <= ad_ch3_ready;
        ad_ch4_ready <= ad_ch4_ready;
      end
      
end
 
 //================================================================= 包络检测      
 (*mark_debug = "true"*)wire   [15 : 0] baoluo_out1;
wire   [15 : 0] baoluo_out2;
wire   [15 : 0] baoluo_out3;
wire   [15 : 0] baoluo_out4;
                       
wire   baoluo_out1_vaild;
 wire   baoluo_out2_vaild;
 wire   baoluo_out3_vaild;
 wire   baoluo_out4_vaild;

baoluo baoluo1(
   .baoluo_in( ad_ch1_ready ),
   .baoluo_in_vaild( ad_data_valid ),
   .clk(clk_50M ),
   .baoluo_out_vaild( baoluo_out1_vaild ),
   .baoluo_out( baoluo_out1 )
   );

baoluo baoluo2(
   .baoluo_in( ad_ch2_ready ),
   .baoluo_in_vaild( ad_data_valid ),
   .clk(clk_50M ),
   .baoluo_out_vaild( baoluo_out2_vaild ),
   .baoluo_out( baoluo_out2 )
   );
   
baoluo baoluo3(
       .baoluo_in( ad_ch3_ready ),
       .baoluo_in_vaild( ad_data_valid ),
       .clk(clk_50M ),
       .baoluo_out_vaild( baoluo_out3_vaild ),
       .baoluo_out( baoluo_out3 )
       );

baoluo baoluo4(
       .baoluo_in( ad_ch4_ready ),
       .baoluo_in_vaild( ad_data_valid ),
       .clk(clk_50M ),
       .baoluo_out_vaild( baoluo_out4_vaild ),
       .baoluo_out( baoluo_out4 )
       );        
 
 //=================================================================  提取时间
       //========================================计数器
(*mark_debug = "true"*)reg [31:0] cnt_time=0; // 42秒计数器满, 一共32位，只用了31位

always@( posedge clk_50M )
begin
    if( cnt_time == 32'd2147483640)
     cnt_time<= 32'd0;
    else
     cnt_time <= cnt_time+1'b1;     
end
       
       
//===========================================================
parameter level=7000; // 门限  用的镊子

(*mark_debug = "true"*)reg [3:0]  data_valid_ch; // 每个通道的有效信号，持续一个时钟的高电平

wire [63:0] data_buf_ch1;  // 32位的时间戳+ 32位的通道号
wire [63:0] data_buf_ch2;
wire [63:0] data_buf_ch3;
wire [63:0] data_buf_ch4;


reg channel_vaild1; // 每个通道检测到就拉高，4个通道都拉高后再拉低。持续到一次event结束，才拉低。
  reg channel_vaild2;
   reg channel_vaild3;
    reg channel_vaild4;
//============================================================提取通道1

(*mark_debug = "true"*)reg [31:0] cnt_time_chan1=0; // 每个通道的时间信息


reg [15 : 0] pai1_baoluo_out1;

always@( posedge clk_50M )               // 打1拍
begin  
      if( baoluo_out1_vaild==1'b1 )
       begin
          pai1_baoluo_out1 <= baoluo_out1; 
       end
      else
        begin
          pai1_baoluo_out1 <= pai1_baoluo_out1;
        
        end
end

always@( posedge clk_50M )
begin
    if(  baoluo_out1_vaild && (baoluo_out1> level) && ( pai1_baoluo_out1< level) ) 
     begin    
         cnt_time_chan1 <= cnt_time;
         data_valid_ch[0]<=1'b1;
        
     end
    else 
     begin
         cnt_time_chan1 <=  cnt_time_chan1;   
         data_valid_ch[0] <= 1'b0;
        
     end
end

//===============================================通道1数据包

assign  data_buf_ch1 = {cnt_time_chan1[31:0] , 32'd1};

////////========================================提取通道2
(*mark_debug = "true"*)reg [31:0] cnt_time_chan2=0;


reg [15 : 0] pai1_baoluo_out2;


always@( posedge clk_50M )
begin  
        if( baoluo_out2_vaild == 1'b1 )
         begin
           pai1_baoluo_out2 <= baoluo_out2;
  
         end
        else
          begin
             pai1_baoluo_out2 <= pai1_baoluo_out2;

          end
end

always@( posedge clk_50M )
begin
    if(   baoluo_out2_vaild && (baoluo_out2> level) && ( pai1_baoluo_out2< level) ) 
     begin    
         cnt_time_chan2 <= cnt_time;
         data_valid_ch[1]<=1'b1;
     end
    else 
     begin
         cnt_time_chan2 <=  cnt_time_chan2;   
         data_valid_ch[1]<=1'b0;
     end
end

//===============================================通道2数据包
assign  data_buf_ch2 = {cnt_time_chan2[31:0] , 32'd2};

//////========================================提取通道3
(*mark_debug = "true"*)reg [31:0] cnt_time_chan3=0;


reg [15 : 0] pai1_baoluo_out3;


always@( posedge clk_50M )
begin  
        if( baoluo_out3_vaild == 1'b1 )
         begin
           pai1_baoluo_out3 <= baoluo_out3;
  
         end
        else
          begin
             pai1_baoluo_out3 <= pai1_baoluo_out3;

          end
end

always@( posedge clk_50M )
begin
    if(   baoluo_out3_vaild && (baoluo_out3> level) && ( pai1_baoluo_out3< level) ) 
     begin    
         cnt_time_chan3 <= cnt_time;
         data_valid_ch[2]<=1'b1;
     end
    else 
     begin
         cnt_time_chan3 <=  cnt_time_chan3;   
         data_valid_ch[2]<=1'b0;
     end
end

//===============================================通道3数据包
assign  data_buf_ch3 = {cnt_time_chan3[31:0] , 32'd3};

////////==============================================================提取通道4
(*mark_debug = "true"*)reg [31:0] cnt_time_chan4=0;


reg [15 : 0] pai1_baoluo_out4;


always@( posedge clk_50M )
begin  
        if( baoluo_out4_vaild == 1'b1 )
         begin
           pai1_baoluo_out4 <= baoluo_out4;
  
         end
        else
          begin
             pai1_baoluo_out4 <= pai1_baoluo_out4;

          end
end

always@( posedge clk_50M )
begin
    if(   baoluo_out4_vaild && (baoluo_out4> level) && ( pai1_baoluo_out4< level) ) 
     begin    
         cnt_time_chan4 <= cnt_time;
         data_valid_ch[3]<=1'b1;
     end
    else 
     begin
         cnt_time_chan4 <=  cnt_time_chan4;   
         data_valid_ch[3]<=1'b0;
     end
end
         
//===============================================通道4数据包
assign  data_buf_ch4 = {cnt_time_chan4[31:0] , 32'd4};




//=============================================================普通计数器，测试pcie的数据是否正确
wire key_cap; // 按键锁定
key#
(
.CLK_FREQ(50000000)
)
key0
(
.clk_i(clk_50M),
.key_i(key_i),
.key_cap(key_cap)
);

reg [31:0] key_num;
always@(posedge clk_50M or negedge key_rst)
begin
 if(!key_rst)
    begin      
      key_num<=32'b0;
    end
 else if(key_cap)
   begin     
     key_num <= key_num+1'b1;
    end 
 else
   begin     
     key_num <= key_num;
   end 
end
//===========================================================10MS定时器，清除4个通道的标志
reg [19:0] cnt_10ms=0;
wire channel_vaild;
reg flag_channel_clear;
assign channel_vaild = channel_vaild1 | channel_vaild2 | channel_vaild3 | channel_vaild4; // 任意通道检测到数据，开始计时
 
always@( posedge clk_50M or negedge key_rst )
begin
    if( !key_rst )
      begin
        cnt_10ms <=20'd0;
        flag_channel_clear <= 1'b0;
      end
    else if( cnt_10ms==20'd49_9999 )
      begin
        cnt_10ms <= 20'd0;
        flag_channel_clear<=1'b1;
      end       
    else if( channel_vaild )
      begin
        cnt_10ms <= cnt_10ms +1'b1;
        flag_channel_clear <= 1'b0;
      end
    else
      begin
        cnt_10ms <= 20'd0 ;
        flag_channel_clear <= 1'b0;
      end
end

//==========================================================================PCIE 发送数据   
// 通道号 + 时间
(*mark_debug = "true"*)reg [63:0] buf_data; // 32位时间+32位通道号
(*mark_debug = "true"*)reg buf_en;             // 启动PCIE发送的使能


(*mark_debug = "true"*) reg [3:0] channel_cnt=0; // 目前接收到几个通道的数据

always@(posedge clk_50M or negedge key_rst) // === 时间戳
begin
     if(!key_rst) 
       begin
        led<=4'b0000;
        buf_data<=64'd0;
        buf_en <= 1'b0;
        channel_cnt <= 4'd0 ;
        
        channel_vaild1<=1'b0;
        channel_vaild2<=1'b0;
        channel_vaild3<=1'b0;
        channel_vaild4<=1'b0;
       end
     else if(  flag_channel_clear |( channel_vaild1 & channel_vaild2 & channel_vaild3 & channel_vaild4 ) )
        begin
         channel_vaild1<=1'b0; 
         channel_vaild2<=1'b0; 
         channel_vaild3<=1'b0; 
         channel_vaild4<=1'b0; 
        end
     else
        begin
            case ( data_valid_ch )
             4'b0001: begin
                            led[0] <= 1'b1;
                            buf_data<=data_buf_ch1;
                            buf_en <= 1'b1;
                            channel_cnt <= channel_cnt + 1'b1;
                            channel_vaild1<=1'b1;
                      end
             4'b0010: begin 
                            led[1] <= 1'b1;                                   
                            buf_data<=data_buf_ch2; 
                            buf_en <= 1'b1;
                            channel_cnt <= channel_cnt + 1'b1;
                            channel_vaild2<=1'b1;
                      end                                      
             4'b0100: begin   
                             led[2] <= 1'b1;                                
                             buf_data<=data_buf_ch3;                             
                             buf_en <= 1'b1;
                             channel_cnt <= channel_cnt + 1'b1;
                             channel_vaild3<=1'b1;
                       end                                           
             4'b1000: begin    
                             led[3] <= 1'b1;                                
                             buf_data<=data_buf_ch4;                             
                             buf_en <= 1'b1;
                             channel_cnt <= channel_cnt + 1'b1;
                             channel_vaild4<=1'b1;
                       end     
             default: begin   
                             led <= led;                     
                             buf_data <= buf_data; 
                             buf_en <= 1'b0;  
                             channel_cnt <= channel_cnt ;
                      end                                                                   
         endcase
      end
end


//---------------fdma image buf controller---------------------------  
assign W0_wclk_i = clk_50M;
assign W0_wren_i = channel_vaild1 & channel_vaild2 & channel_vaild3 & channel_vaild4;
assign W0_data_i = { cnt_time_chan4, cnt_time_chan3 , cnt_time_chan2 , cnt_time_chan1  // 16字节                
                   };
   
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
