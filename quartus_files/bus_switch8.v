//оди вход - два выхода
module bus_switch8(bus_in, result1,result2, sel);

input sel;
input [7:0] bus_in;
output [7:0] result1, result2;

assign result1 = sel ? 0 : bus_in;
assign result2 = sel ? bus_in : 0;

endmodule
