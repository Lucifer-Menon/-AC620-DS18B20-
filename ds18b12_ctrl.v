module ds18b12_ctrl(clk, rst_n, dq, temp_data, sign);

	input clk;  //定义时钟信号,系统时钟为50M频率
	input rst_n;  //定义低电平复位信号
	inout dq;  //单总线（双向信号）
	output reg[19:0]temp_data;  //转化后得到的温度值
	output reg sign;  //符号位
	
//利用杜热玛来编辑状态机名称与状态
localparam INIT1    = 6'b000001;
localparam WR_CMD   = 6'b000010;
localparam WAIT     = 6'b000100;
localparam INIT2    = 6'b001000;
localparam RD_CMD   = 6'b010000;
localparam RD_DATA  = 6'b100000;

//时间定义
localparam T_INIT = 1000; //初始化最大时间，单位是us
localparam T_WAIT = 780_000; //转换等待延时，单位是us

//命令定义
localparam WR_CMD_DATA = 16'h44cc;  //跳过 ROM 及温度转换命令，低位在前
localparam RD_CMD_DATA = 16'hbecc;  //跳过 ROM 及读取温度命令，低位在前

//端口类型定义
reg	[5:0]	curr_state	;  //现态
reg	[5:0]	next_state	;  //次态
reg	[4:0]	cnt			;  //50分频计数器，1Mhz(1us)
reg			dq_out		;  //双向总线输出
reg			dq_en		;  //双向总线输出使能，1则输出，0则高阻态
reg			flag_ack	;  //从机响应标志信号
reg			clk_us		;  //us时钟
reg [19:0]	cnt_us		;  //us计数器,最大可表示1048ms
reg [3:0]	bit_cnt		;  //接收数据计数器
reg [15:0]	data_temp	;  //读取的温度数据寄存
reg [15:0]	data		;  //未处理的原始温度数据

wire		dq_in		;  //双向总线输入

assign dq_in = dq;
assign dq    = dq_en ? dq_out : 1'bz;

//系统时钟为50Mhz
always@(posedge clk or negedge rst_n)begin 
	if(!rst_n)begin
		cnt  <= 5'd0;
	end
	else if(cnt == 5'd24)begin  //每25个时钟，即500ns进行清零
		cnt <= 5'd0;
	end
	else
		cnt <= cnt + 1'b1;
end

//每次cnt计数满25次之后clk_us产生反转,产生1us的时钟
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		clk_us <= 1'b0;
	end
	else if(cnt == 5'd24)begin //每次计数器技术到500ns
		clk_us <= ~clk_us; //时钟翻转
	end
	else
		clk_us <= clk_us;
end

//状态机编写，利用三段式状态机
//第一段状态机：同步时序描述状态转移
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		curr_state <= INIT1;
	end
	else begin
		curr_state <= next_state;
	end
end

//地二段状态机：组合逻辑判断状态转移条件，描述状态转移规律以及输出
always@(*)begin
	next_state = INIT1;
	case(curr_state)
		INIT1 : begin //初始化状态
			if(cnt_us == T_INIT && flag_ack) 		//满足初始化实践需求而且接收到从机
				next_state = WR_CMD;        	    //满足条件则状态转移
			else
				next_state = INIT1;                 //不满足条件保持原状土
		end
		WR_CMD : begin      						//写入数据状态
			if(bit_cnt == 4'd15 && cnt_us == 20'd62)//读取16位数据，并且在该阶段持续时间达到630us
				next_state = WAIT; 					//满足条件者状态转移
			else
				next_state = WR_CMD;				//不满足条件者停于原态
		end
		WAIT : begin
			if(cnt_us == T_WAIT)					//等待时延结束时
				next_state = INIT2;					//进入第二段初始化时序
			else
				next_state = WAIT;					//不满足条件者停于原态
		end
		INIT2 : begin
			if(cnt_us == T_INIT && flag_ack)		//再进行初始化，时序同INIT1
				next_state = RD_CMD;				//初始化时段结束后，进入发送跳过ROM和读取温度指令
			else
				next_state = INIT2;					//不满足条件者停于原态
		end
		RD_CMD : begin
			if(bit_cnt == 4'd15 && cnt_us == 20'd62)//向主机发送读取数据命令，在该阶段持续时间达到630us
				next_state = RD_DATA;				//成功发送16个数据后，发送命令完成，进入读取阶段
			else
				next_state = RD_CMD;				//不满足条件者停于原态
		end
		RD_DATA : begin
			if(bit_cnt == 4'd15 && cnt_us == 20'd62)//主机读取从机返回的16位温度数据
				next_state = INIT1;					//当成功读取16个数据后，接收命令完成，重新完成初始化
			else
				next_state = RD_DATA;				//不满足条件者停于原态
		end
		default : next_state = INIT1;				//默认初始化状态
	endcase
end

//第三段状态机：时序逻辑描述输出
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		dq_en <= 1'b0;								//默认输出
		dq_out <= 1'b0;
		flag_ack <= 1'b0;
		cnt_us <= 20'b0;
		bit_cnt <= 4'b0;
	end
	else begin
		case(curr_state)
			INIT1 : begin							//进入第一初始化时的条件
				if(cnt_us == T_INIT)begin			//时间计数到最大值（初始化时间）
					cnt_us <= 20'b0;				//计数器清零
					flag_ack <= 1'b0;				//从机响应标志信号拉低
				end
				else begin
					cnt_us <= cnt_us + 1'd1;		//没有计数到最大值，计数器计数
					if(cnt_us <= 20'd499)begin		//小于500us时
						dq_en <=1'b1;				//控制总线
						dq_out <= 1'b0;				//输出0，即拉低总线
					end
					else begin						//在500us处
						dq_en <= 1'b0;				//释放总线，等待从机响应	
						if(cnt_us == 20'd570 && !dq_in)//在570us处采集总线电平，如果为0则说明从机响应了
							flag_ack <= 1'b1;		//拉高从机响应标志信号
					end
				end
			end
			WR_CMD : begin							//选择和写入跳过ROM指令命令
				if(cnt_us == 20'd62)begin			//一个写时隙周期63us，满足计时条件则
					cnt_us <= 20'd0;				//清空计数器
					dq_en <= 1'b0;					//释放总线
					if(bit_cnt == 4'd15)			//如果数据已经写了16个
						bit_cnt <= 4'd0;			//清空
					else
						bit_cnt <= bit_cnt + 1'd1;	//没满16个则继续写入
				end
				else begin
					cnt_us <= cnt_us + 1'b1;		//一个写时隙周期63us未完成，计数器一直写入
					if(cnt_us <= 20'd1)begin		//0~1us（每两个写数据之间需要间隔2us）
						dq_en <= 1'b1;				//拉低总线
						dq_out <= 1'b0;				//拉低输出
					end
					else begin
						if(WR_CMD_DATA[bit_cnt] == 1'b0)begin//需要写入的数据为0
							dq_en <= 1'b1;			//拉低总线
							dq_out <= 1'b0;			//拉低输出
						end
						else if(WR_CMD_DATA[bit_cnt] == 1'b1)begin//需要写入的数据为1
							dq_en <= 1'b0;    		//释放总线
							dq_out <= 1'b0;			//拉低输出
						end
					end
				end
			end
			WAIT : begin							//等待温度转换完成
				dq_en <= 1'b1;						//拉低总线兼容寄生电源模式
				dq_out <= 1'b1;						
				if(cnt_us == T_WAIT)begin			//计数完成
					cnt_us <= 20'd0;				
				end
				else
					cnt_us <= cnt_us + 1'd1;		//计数未完成
			end
			INIT2 : begin							//第二次初始化，时序同INIT1
				if(cnt_us == T_WAIT)begin			
					cnt_us <= 20'd0;				
					flag_ack <= 1'b0;				
				end
				else begin
					cnt_us <= cnt_us + 1'b1;		
					if(cnt_us <= 20'd499)begin		
						dq_en <=1'b1;		
						dq_out <= 1'b0;				
					end
					else begin				
						dq_en <= 1'b0;				
						if(cnt_us == 20'd570 && !dq_in)
							flag_ack <= 1'b1;		
					end
				end
			end
			RD_CMD : begin							//发送度16个数据的命令，时序同WR_CMD
				if(cnt_us == 20'd62)begin	
					cnt_us <= 20'b0;				
					dq_en <= 1'b0;					
					if(bit_cnt == 4'd15)			
						bit_cnt <= 4'b0;			
					else
						bit_cnt <= bit_cnt + 1'b1;	
				end
				else begin
					cnt_us <= cnt_us + 1'b1;		
					if(cnt_us <= 20'd1)begin		
						dq_en <= 1'b1;				
						dq_out <= 1'b0;				
					end
					else begin
						if(RD_CMD_DATA[bit_cnt] == 1'b0)begin
							dq_en <= 1'b1;			
							dq_out <= 1'b0;			
						end
						else if(RD_CMD_DATA[bit_cnt] == 1'b1)begin//
							dq_en <= 1'b0;			
							dq_out <= 1'b0;			
						end
					end
				end
			end	
			RD_DATA : begin							//读16位温度数据
				if(cnt_us == 20'd62)begin			//一个读时隙周期63us，满足计时条件则
					cnt_us <= 20'd0;				//清空计数器
					dq_en <= 1'b0;					//释放总线
					if(bit_cnt == 4'd15)begin		//如果数据已经读取了16个
						bit_cnt <= 4'b0;			//则清空
						data <= data_temp;			//临时的数据赋值给data
					end
					else begin
						bit_cnt <= bit_cnt + 1'd1;	//如数据没读取16个，则计数器+1，意味着读取了一个数据
						data <= data;				
					end	
				end
				else begin
					cnt_us <= cnt_us + 1'd1;		//一个读时隙周期还没结束，计数器累加
					if(cnt_us <= 20'd1) begin		//0~1us（每两个读数据之间需要间隔2us）
						dq_en <= 1'b1;				//拉低总线
						dq_out <= 1'b0;				
					end
					else begin						//2us后
						dq_en <= 1'b0;				//释放总掉线
						if(cnt_us == 20'd10)		//在10us处读取总线电平
							data_temp <= {dq, data_temp[15 : 1]};//读取总线电平
					end
				end
			end
			default;
		endcase
	end
end

//12位温度数据处理
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		temp_data <= 20'b0;							//初始状态
		sign <= 1'b0;								//初始状态
	end
	else begin
		if(!data[15])begin							//最高位为0则温度为正
			sign <= 1'b0;							//标志位为正
			temp_data <= data[10 : 0] * 11'd625/7'd100;//12位温度数据处理,数据放大10000倍
		end
		else if(data[15])begin						//最高位为1则温度为负
			sign <= 1'b1;							//标志位为负
			temp_data <= (~data_temp[10 : 0] + 1'b1) * 11'd625/7'd100;//12位温度数据处理
		end
	end
end

endmodule 