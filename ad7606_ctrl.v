`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Module Name:    ad7606 
//////////////////////////////////////////////////////////////////////////////////
module ad7606_ctrl(
    input        		clk_i,                  //50mhz
	input               reset_i,
	input[15:0] 		ad_data,            //ad7606 采样数据
	input        		ad_busy,            //ad7606 忙标志位
    input        		first_data,         //ad7606 第一个数据标志位  
	output[2:0] 		ad_os,              //ad7606 过采样倍率选择
	output     		    ad_cs,              //ad7606 AD cs
	output    	    	ad_rd,              //ad7606 AD data read
	output     reg 		ad_reset,           //ad7606 AD reset
	output     		    ad_convsta,         //ad7606 AD convert start
	//output     		    ad_convstb,         //ad7606 AD convert start	
	
	output              ad_ch1_o,
	output              ad_ch2_o,
	output              ad_ch3_o,
	output              ad_ch4_o,
	output              ad_ch5_o,
	output              ad_ch6_o,
	output              ad_ch7_o,
	output              ad_ch8_o,
	output              ad_data_valid_o
    );

wire[15:0] ad_data;
wire       ad_busy;
wire       first_data;
wire[2:0]  ad_os;
reg        ad_cs;
reg        ad_rd;
reg        ad_convsta;
//reg        ad_convstb;
wire       ad_range;
reg[15:0]  ad_ch1_o;
reg[15:0]  ad_ch2_o;
reg[15:0]  ad_ch3_o;
reg[15:0]  ad_ch4_o;
reg[15:0]  ad_ch5_o;
reg[15:0]  ad_ch6_o;
reg[15:0]  ad_ch7_o;
reg[15:0]  ad_ch8_o;
reg        ad_data_valid_o;

reg [7:0] cnt;
reg [7:0] i;
reg [15:0] cnt5us;
reg [7:0] ad_state;

assign ad_os=3'b000;  //无过采样


//ad复位
always@(posedge clk_i)
begin        
    if(reset_i)   
        ad_reset<=1'b0;            
    if(cnt<8'd60) 
    begin
        cnt<=cnt+1'b1;
        ad_reset<=1'b1;
    end
    else
        ad_reset<=1'b0;  //计数器停止，ad_reset拉低，复位结束     
end       
	
//设置采样频率
always@ (posedge clk_i)   //200k采样率
begin
        if(reset_i)
            cnt5us <= 16'd0;
        if((cnt5us < 16'd999)&&(cnt==8'd60))
            cnt5us <= cnt5us + 1'b1;
        else
            cnt5us <= 16'd0;
end

//状态循环
always @(posedge clk_i) 
begin
    if(reset_i)
    begin
        ad_cs<=1'b1;
        ad_rd<=1'b1; 
        ad_convsta<=1'b1;   
  //      ad_convstb<=1'b1;   
        i<=8'd0;   
        ad_ch1_o<=16'd0;
        ad_ch2_o<=16'd0;
        ad_ch3_o<=16'd0;
        ad_ch4_o<=16'd0;
        ad_ch5_o<=16'd0;
        ad_ch6_o<=16'd0;
        ad_ch7_o<=16'd0;
        ad_ch8_o<=16'd0;
        ad_data_valid_o <= 1'b0;
        ad_state<=8'd0; 
    end
    else if(ad_reset)
    begin
        ad_cs<=1'b1;
        ad_rd<=1'b1; 
        ad_convsta<=1'b1;   
    //    ad_convstb<=1'b1;   
        i<=8'd0;   
        ad_state<=8'd0; 
    end
    else        
    begin
        case(ad_state)     
		  8'd0: begin
                     ad_cs<=1'b1;
                     ad_rd<=1'b1; 
                     ad_convsta<=1'b1;
                   //  ad_convstb<=1'b1;
                     ad_data_valid_o <= 1'b0;    
                     ad_state <= 8'd1;
		  end
		  
		8'd1: begin
                          if(i == 8'd20)            
                          begin
                              i<=8'd0;             
                              ad_state<=8'd2;
                          end
                          else 
                          begin
                              i<=i+1'b1;
                              ad_state<=8'd1;
                          end
                    end
                    
                    8'd2: begin       
                           if(i==8'd8)     
                           begin                        //等待2个lock，convstab的下降沿最少为25ns，故至少需要两个时钟
                               i<=8'd0;             
                               ad_convsta<=1'b1;
                            //   ad_convstb<=1'b1;
                               ad_state<=8'd3;                                          
                           end
                           else 
                           begin
                               i<=i+1'b1;
                               ad_convsta<=1'b0;
                         //      ad_convstb<=1'b0;                     //启动AD转换
                               ad_state<=8'd2;
                           end
                    end
                    
                    8'd3: begin            
                           if(i==8'd20) 
                           begin                           //等待5个clock, 等待busy信号为高(tconv)
                               i<=8'd0;
                               ad_state<=8'd4;
                           end
                           else 
                           begin
                               i<=i+1'b1;
                               ad_state<=8'd3;
                           end
                    end        
                    
                    8'd4: begin            
                             if(!ad_busy) 
                             begin                    //等待busy为低电平  即转换之后读取模式         
                                 ad_state<=8'd5;
                             end
                             else
                                 ad_state<=8'd4;
                    end    
                    
                    8'd5: begin 
                            ad_cs<=1'b0;                              //cs信号有效  直到读取8通道结束  
                            ad_rd<=1'b0;                       
                            ad_state<=8'd6;  
                     end
                    
                    8'd6: begin            
                            ad_state<=8'd7;
                    end
                    
                    
                    8'd7: begin  
                            if(first_data)                       
                                ad_state<=8'd8;
                            else
                                ad_state<=8'd7;    
                     end
                     
                     8'd8: begin
                           if(i==8'd4)
                           begin 
                               ad_rd<=1'b1;
                               ad_ch1_o<=ad_data;                        //读CH1               
                               i<=8'd0;
                               ad_state<=8'd9;                 
                           end
                           else 
                           begin  
                               i<=i+1'b1;
                               ad_state<=8'd8; 
                           end
                     end
                     8'd9: begin
                           if(i==8'd4)
                           begin
                               ad_rd<=1'b0;              
                               i<=8'd0;
                               ad_state<=8'd10;                 
                           end
                           else 
                           begin  
                               i<=i+1'b1;
                               ad_state<=8'd9; 
                           end
                     end
                     
                     8'd10: begin 
                            if(i==8'd4)
                            begin
                                ad_rd<=1'b1;
                                ad_ch2_o<=ad_data;                        //读CH2
                                i<=8'd0;
                                ad_state<=8'd11;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd10;
                            end
                    end
                    8'd11: begin 
                           if(i==8'd4) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd12;                 
                            end
                            else 
                            begin                           
                                i<=i+1'b1;
                                ad_state<=8'd11;  
                            end
                    end        
                      
                    8'd12: begin 
                            if(i==8'd4)
                            begin
                                ad_rd<=1'b1;
                                ad_ch3_o<=ad_data;                        //读CH3
                                i<=8'd0;
                                ad_state<=8'd13;                 
                            end
                            else 
                            begin    
                                i<=i+1'b1;
                                ad_state<=8'd12;
                            end
                    end
                    8'd13: begin 
                            if(i==8'd4)
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd14;                 
                            end
                            else 
                            begin                                 
                                i<=i+1'b1;
                                ad_state<=8'd13;
                            end
                    end
                    
                    8'd14: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch4_o<=ad_data;                        //读CH4
                                i<=8'd0;
                                ad_state<=8'd15;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd14;
                            end
                    end
                    8'd15: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd16;                 
                            end
                            else 
                            begin                           
                                i<=i+1'b1;
                                ad_state<=8'd15; 
                            end
                    end
                    
                    8'd16: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch5_o<=ad_data;                        //读CH5
                                i<=8'd0;
                                ad_state<=8'd17;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd16;
                            end
                    end
                    8'd17: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd18;                 
                            end
                            else 
                            begin                            
                                i<=i+1'b1;
                                ad_state<=8'd17; 
                            end
                    end
                    
                    8'd18: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch6_o<=ad_data;                        //读CH6
                                i<=8'd0;
                                ad_state<=8'd19;                 
                            end
                            else
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd18;
                            end
                    end
                    8'd19: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b0;
                                i<=8'd0;
                                ad_state<=8'd20;                 
                            end
                            else
                            begin                          
                                i<=i+1'b1;
                                ad_state<=8'd19;
                            end
                    end
                    
                    8'd20: begin 
                           if(i==8'd4) 
                           begin
                               ad_rd<=1'b1;
                               ad_ch7_o<=ad_data;                        //读CH7
                               i<=8'd0;
                               ad_state<=8'd21;                 
                           end
                           else
                           begin
                               i<=i+1'b1;
                               ad_state<=8'd20;    
                           end
                    end
                    8'd21: begin 
                           if(i==8'd4) 
                           begin 
                               ad_rd<=1'b0;
                               i<=8'd0;
                               ad_state<=8'd22;                 
                           end
                           else
                           begin                           
                               i<=i+1'b1;
                               ad_state<=8'd21;
                           end
                    end
                    
                    8'd22: begin 
                            if(i==8'd4) 
                            begin
                                ad_rd<=1'b1;
                                ad_ch8_o<=ad_data;                        //读CH8
                                i<=8'd0;
                                ad_state<=8'd23;                 
                            end
                            else 
                            begin
                                i<=i+1'b1;
                                ad_state<=8'd22;    
                            end
                    end
            
                    8'd23: begin 
                    if(i==8'd4) 
                    begin
                        ad_data_valid_o <= 1'b1;
                        ad_rd<=1'b1;                                           
                        i<=8'd0;
                        ad_state<=8'd24;                 
                    end
                    else 
                    begin                   
                        i<=i+1'b1;
                        ad_state<=8'd23;    
                    end
                    end
                    
          /*          8'd24: begin
                        ad_state<=8'd25;
                    end*/
                    
                    8'd24: begin                                 //完成读，回到idle状态
                               ad_rd<=1'b1;     
                               ad_cs<=1'b1;
                               ad_data_valid_o <= 1'b0;
                               if(cnt5us == 16'd999)                      
                                  ad_state<=8'h0;
                               else
                                  ad_state<=8'd24;
                    end        
                    
                    default:    ad_state<=8'd0;
                    endcase    
              end                                 
           end
           

          
endmodule
