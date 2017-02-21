module serializer(clk, start, inp_re, inp_im, out_data, capture);
input clk, start, capture;
input  [23:0] inp_re;
input  [23:0] inp_im;
output [7:0] out_data;

reg [1:0] counter;
reg [7:0] out_data;

reg [23:0] temp_data_re;
reg [23:0] temp_data_im;

always @(posedge capture) temp_data_re <= inp_re;//input data bufferization
always @(posedge capture) temp_data_im <= inp_im;//input data bufferization

always @(posedge clk)
begin
	if (start == 1'b1) counter <= 2;
	else counter <= counter + 1'b1;
end

always @(posedge clk)
begin
	case(counter)
		2'd0: out_data <= temp_data_im[15:8];//2
		2'd1: out_data <= temp_data_im[23:16];//1
		2'd2: out_data <= temp_data_re[15:8];//4
		2'd3: out_data <= temp_data_re[23:16];//3
	endcase
end

endmodule
