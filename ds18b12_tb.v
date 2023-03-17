`timescale 1ns/1ns
`define clock_period 20

module ds18b12_tb();

	reg clk;
	reg rst_n;
	reg dq;
	
	wire [19:0]temp_data;
	wire sign;

	ds18b12_ctrl ds18b12_u0(
		.clk(clk), 
		.rst_n(rst_n), 
		.dq(dq), 
		.temp_data(temp_data), 
		.sign(sign)
	);
	
	integer i=0;
	initial clk = 1;
	always#(`clock_period/2) clk = ~clk;
	
	initial begin
		rst_n = 0;
        #(`clock_period*20);
        rst_n = 1'b1;
        repeat(5)begin
            for(i=0;i<500000;i=i+1)begin
                dq = {$random};
                #(`clock_period*20);
            end
            #(`clock_period*20);
        end
        $stop;
	end

endmodule 