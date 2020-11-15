`timescale 1ns / 1ps
module baoluo(
    input  wire [15 : 0] baoluo_in,
    input  wire baoluo_in_vaild,
    input  wire clk,
    output wire baoluo_out_vaild,
    output wire [15 : 0] baoluo_out
    );
    
reg  [15:0] signal_dm_ac;
 always @ (posedge clk)
    begin
      signal_dm_ac <= baoluo_in - (16'd7602) ;
    end


reg [15:0] AM_abs;
always @ (posedge clk)
       begin
         if(signal_dm_ac[15]== 1 )
            AM_abs<= -{ signal_dm_ac };
         else if( signal_dm_ac[15]== 0 ) 
            AM_abs <= signal_dm_ac;
         else
            AM_abs <= AM_abs;
       end



wire [39 : 0] m_axis_data_tdata;

fir_compiler_0 fir_compiler_0 (
  .aclk(clk),                              // input wire aclk
  .s_axis_data_tvalid(baoluo_in_vaild),  // input wire s_axis_data_tvalid
  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .s_axis_data_tdata(AM_abs),    // input wire [15 : 0] s_axis_data_tdata
  .m_axis_data_tvalid(baoluo_out_vaild),  // output wire m_axis_data_tvalid
  .m_axis_data_tdata(m_axis_data_tdata)    // output wire [39 : 0] m_axis_data_tdata
);

assign baoluo_out= m_axis_data_tdata[33:18];

endmodule
