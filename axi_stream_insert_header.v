module axi_stream_insert_header #(
	parameter DATA_WD = 32,
	parameter DATA_BYTE_WD = DATA_WD / 8
) (
	input clk,
	input rst_n,

	// AXI Stream input original data
	input valid_in,
	input [DATA_WD-1 : 0] data_in,
	input [DATA_BYTE_WD-1 : 0] keep_in,
	input last_in,
	output reg ready_in,

	// The header to be inserted to AXI Stream input
	input valid_insert,
	input [DATA_WD-1 : 0] header_insert,
	input [DATA_BYTE_WD-1 : 0] keep_insert,
	output reg ready_insert,

	// AXI Stream output with header inserted
	output reg valid_out,
	output reg [DATA_WD-1 : 0] data_out,
	output reg [DATA_BYTE_WD-1 : 0] keep_out,
	output reg last_out,
	input ready_out
);

	reg [DATA_WD-1 : 0] data_in_t;					//data_in信号打一拍，用于数据拼接输出
	reg ready_in_t;									//ready_in信号打一拍，用于提取上升沿和下降沿
	reg [DATA_BYTE_WD-1 : 0] keep_insert_lock;		//keep_insert信号寄存，用于确定最后一个输出数据有效位数

	wire ready_in_up, ready_in_down;				//取ready_in上升沿用户添加头部数据，取ready_in下降沿用于确定尾部数据
	assign ready_in_up = ~ready_in_t && ready_in;    
	assign ready_in_down = ready_in_t && ~ready_in;	 

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in <= 0;
		end
		else if (last_in) begin
			ready_in <= 0;
		end
		else if (ready_out && valid_insert && valid_in) begin
			ready_in <= 1; 
		end
		else begin
			ready_in <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_in_t <= 0;
		end
		else begin
			ready_in_t <= ready_in;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			ready_insert <= 0;
		end 
		else if (ready_in) begin
			ready_insert <= 0;
		end
		else if (ready_out && valid_insert && valid_in) begin
			ready_insert <= 1;
		end
		else begin
			ready_insert <= ready_insert;
		end
	end

	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_in_t <= 0;
		end
		else if (ready_in) begin
			data_in_t <= data_in;
		end
		else begin
			data_in_t <= data_in_t;
		end
	end


	always @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			data_out <= 0;
			keep_out <= 0;
			last_out <= 0;
			valid_out <= 0;
			keep_insert_lock <= 0;
		end
		else if (ready_in_up) begin
			case (keep_insert)
				4'b1111:data_out <= header_insert;
				4'b0111:data_out <= {header_insert[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {header_insert[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {header_insert[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;
			keep_out <= 4'b1111;
			last_out <= 0;
			keep_insert_lock <= keep_insert;
		end
		else if (ready_in) begin
			case (keep_insert_lock)
				4'b1111:data_out <= data_in_t;
				4'b0111:data_out <= {data_in_t[23:0],data_in[DATA_WD-1:24]};
				4'b0011:data_out <= {data_in_t[15:0],data_in[DATA_WD-1:16]};
				4'b0001:data_out <= {data_in_t[7:0],data_in[DATA_WD-1:8]};
				4'b0000:data_out <= data_in;
				default : data_out <= data_out;
			endcase
			valid_out <= 1;
			keep_out <= 4'b1111;
			last_out <= 0;
			keep_insert_lock <= keep_insert_lock;
		end
		else if (ready_in_down) begin
			case ({keep_insert_lock, keep_in})
				16'b1111_1111:begin
					data_out <= data_in_t;
					valid_out <= 1;
					keep_out <= 4'b1111;
					last_out <= 1;
				end
				16'b1111_1110:begin
					data_out <= {data_in_t[DATA_WD-1:8],8'b0};
					valid_out <= 1;
					keep_out <= 4'b1110;
					last_out <= 1;
				end
				16'b1111_1100:begin
					data_out <= {data_in_t[DATA_WD-1:16],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b1111_1000:begin
					data_out <= {data_in_t[DATA_WD-1:24],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0111_1111:begin
					data_out <= {data_in_t[23:0],8'b0};
					valid_out <= 1;
					keep_out <= 4'b1110;
					last_out <= 1;
				end
				16'b0111_1110:begin
					data_out <= {data_in_t[23:8],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b0111_1100:begin
					data_out <= {data_in_t[23:16],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0011_1111:begin
					data_out <= {data_in_t[15:0],16'b0};
					valid_out <= 1;
					keep_out <= 4'b1100;
					last_out <= 1;
				end
				16'b0011_1110:begin
					data_out <= {data_in_t[15:8],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				16'b0001_1111:begin
					data_out <= {data_in_t[7:0],24'b0};
					valid_out <= 1;
					keep_out <= 4'b1000;
					last_out <= 1;
				end
				default : begin
					data_out <= data_in_t;
					valid_out <= 1;
					keep_out <= 4'b0000;
					last_out <= 1;
				end
			endcase
			keep_insert_lock <= keep_insert_lock;
		end
		else begin
			data_out <= data_out;
			keep_out <= keep_out;
			keep_insert_lock <= keep_insert_lock;
			last_out <= 0;
			valid_out <= 0;
		end
	end
endmodule