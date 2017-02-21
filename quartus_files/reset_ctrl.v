//модуль сброса
//при включении формирует сигнал сброса длительностью 1.5 сек
module power_up
(
input  clk,
output res_out, //0 - reset
input  ext_res//0 - reset
);

reg [15:0] rcnt = 15'd0;
reg         s_rclk = 1'b0;

assign res_out = s_rclk & ext_res;//0 at strat

always @(posedge clk)
begin
if (rcnt != 16'hffff)            rcnt <= rcnt + 16'b1;
s_rclk <= (rcnt == 16'hffff);
end


endmodule
