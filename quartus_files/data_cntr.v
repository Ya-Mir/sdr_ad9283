//������ 1024 �������� ������� ��������� ������� start
//adr_out ���������������� �� ������� �������� �������
//page - ������ ���������� ������ start
module data_ctrl(clk, start, adr_out, page);
input clk;
output start, page;
output [9:0] adr_out;

reg [9:0] counter;
reg page;
reg start;

//assign start = (counter == 0);
assign adr_out = counter;

//���������� �������
always @(posedge clk)
begin
		counter = counter + 10'd1;
		start <= (counter == 0 ? 1 : 0);
end

always @(posedge start)
begin
		page <= ~page;
end

endmodule
