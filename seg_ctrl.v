module  seg_ctrl(clk, rst_n, dout, dis_sel, dis_seg);
	input clk;
	input rst_n;
	input [19 : 0]dout;
	
	output reg [5 : 0]dis_sel;
	output reg [7 : 0]dis_seg;
	
	reg        dis_dp;
	
	reg [31:0]cnt;
	reg [3:0]dis_num;
	reg [23:0]split_num;
	
	wire [3:0]num_r1;  	//右边的1位，个
	wire [3:0]num_r2;	//右边的2位，十
	wire [3:0]num_r3;	//右边的3位，百
	wire [3:0]num_r4;	//右边的4位，千
	wire [3:0]num_r5;	//右边的5位，万
	wire [3:0]num_r6;	//右边的6位，十万
	
	
	
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		cnt <= 32'b0;
	end
	else if(cnt == 32'd49999)begin
		cnt <= 32'b0;
	end
	else
		cnt <= cnt + 1'b1;
end

always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		dis_sel <= 6'b111110;
	end
	else if(cnt == 32'd49999)
		dis_sel <= {dis_seg[4:0], dis_sel[5]};
	else
		dis_sel <= dis_sel;
end


	assign num_r1 = dout % 4'd10;
	assign num_r2 = (dout/4'd10) % 4'd10;
	assign num_r3 = (dout/7'd100) % 4'd10;
	assign num_r4 = (dout/10'd1000) % 4'd10;
	assign num_r5 = (dout/14'd10000) % 4'd10;
	assign num_r6 = (dout/17'd100000) % 4'd10;
	
//BCD转换代码
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		split_num <= 24'h000000;
	end
	else if(num_r6)begin
		split_num[23:0] <= {num_r6, num_r5, num_r4, num_r3, num_r2, num_r1};
	end
	else if(num_r5)begin
		split_num[19:0] <= {num_r5, num_r4, num_r3, num_r2, num_r1};
		split_num[23:20] <= 4'h0;
	end
	else if(num_r4)begin
		split_num[15:0] <= {num_r4, num_r3, num_r2, num_r1};
		split_num[23:16] <= 8'h00;
	end
	else if(num_r3)begin
		split_num[11:0] <= {num_r3, num_r2, num_r1};
		split_num[23:12] <= 12'h000;
	end
	else if(num_r2)begin
		split_num[7:0] <= {num_r2, num_r1};
		split_num[23:8] <= 16'h0000;
	end
	else if(num_r1)begin
		split_num[3:0] <= num_r1;
		split_num[23:4] <= 20'h00000;
	end
end


//根据当前被点亮的数码管，判断应该显示什么数值
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n)
		dis_num <= 0;
	else
		case(dis_sel)
			6'b000001:begin dis_num <= split_num[3:0];dis_dp <= 1'b1;end
			6'b000010:begin	dis_num <= split_num[7:4];dis_dp <= 1'b1;end
			6'b000100:begin	dis_num <= split_num[11:8];dis_dp <= 1'b1;end
			6'b001000:begin	dis_num <= split_num[15:12];dis_dp <= 1'b1;end	
			6'b010000:begin	dis_num <= split_num[19:16];dis_dp <= 1'b0;end
			6'b100000:begin	dis_num <= split_num[23:20];dis_dp <= 1'b1;end					
			default:	dis_num <= 0;
		endcase
end

//根据数码管显示的数值，控制段选信号（低电平有效）
always @ (posedge clk or negedge rst_n) begin
	if (!rst_n)
		dis_seg <= 8'b1111_1111;					//复位时熄灭数码管（这一条用处不大，因为复位时数码管也不供电）
	else 
		case (dis_num)							//根据要显示的数字来对数码管编码
			4'h0 : dis_seg <= {dis_dp, 7'b1000000};//显示数字“0”，则数码管的段选编码为7'b000_0001
			4'h1 : dis_seg <= {dis_dp, 7'b1111001};
			4'h2 : dis_seg <= {dis_dp, 7'b0100100};
			4'h3 : dis_seg <= {dis_dp, 7'b0110000};
			4'h4 : dis_seg <= {dis_dp, 7'b0011001};
			4'h5 : dis_seg <= {dis_dp, 7'b0010010};
			4'h6 : dis_seg <= {dis_dp, 7'b0000010};
			4'h7 : dis_seg <= {dis_dp, 7'b1111000};
			4'h8 : dis_seg <= {dis_dp, 7'b0000000};
			4'h9 : dis_seg <= {dis_dp, 7'b0010000};//显示数字“9”，则数码管的段选编码为7'b000_0100
			default : dis_seg <= 8'b1111_1111;//其他数字（16进制的数字相对10进制无效）则熄灭数码管
		endcase	
end

endmodule 