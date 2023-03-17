module temperature_detector(clk, rst_n, dq, SH_CP, ST_CP, DS);

	input clk;
	input rst_n;
	inout dq;
	
	output SH_CP;
	output ST_CP;
	output DS;
	
	
	wire [5:0]dis_sel;
	wire [7:0]dis_seg;
	
	wire [19:0]temp_data;
	

	ds18b12_ctrl ds18b12_u(
		.clk(clk), 
		.rst_n(rst_n), 
		.dq(dq), 
		.temp_data(temp_data), 
		.sign(sign)
	);

	seg_ctrl seg_ctrl_u(
		.clk(clk), 
		.rst_n(rst_n), 
		.dout(temp_data), 
		.dis_sel(dis_sel), 
		.dis_seg(dis_seg)
	);
	
	HC595_Driver HC595_Driver_u(
		.Clk(clk),
		.Rst_n(rst_n),
		.Data({1'b1, dis_seg, dis_sel}),
		.S_EN(1'b1),
		.SH_CP(SH_CP),
		.ST_CP(ST_CP),
		.DS(DS)
	);
	
endmodule 