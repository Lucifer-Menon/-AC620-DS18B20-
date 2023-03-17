`timescale 1ns/1ns
`define clock_period 20

module seg_ctrl_tb();

	reg clk;
	reg rst_n;
	reg [19:0]dout;
	
	wire [5:0]dis_sel;
	wire [7:0]dis_seg;
	
	seg_ctrl seg_ctrl_u0(
		.clk(clk), 
		.rst_n(rst_n), 
		.dout(dout), 
		.dis_sel(dis_sel), 
		.dis_seg(dis_seg)
	);
	
	initial clk = 1;
	always#(`clock_period/2) clk = ~clk;
	
	initial begin
		rst_n = 0;
		#(`clock_period*2);
		rst_n = 1;
		dout = 00000000000110111010;
		#(`clock_period*50);
		dout = 00000000001100010100;
		#(`clock_period*50);
		dout = 00000000000101101011;
		#(`clock_period*150);
		$stop;
	end

endmodule 