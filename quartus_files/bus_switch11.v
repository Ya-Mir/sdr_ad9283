//два входа - два выхода
module bus_switch11(bus_in1,bus_in2, result1,result2, sel);

input sel;
input [9:0] bus_in1, bus_in2;
output [9:0] result1, result2;

assign result1 = sel ? bus_in2 : bus_in1;
assign result2 = sel ? bus_in1 : bus_in2;

endmodule