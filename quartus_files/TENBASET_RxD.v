module TENBASET_RxD(clk48, manchester_data_in, new_byte_available,end_of_frame, rx_led, data_out);
input clk48, manchester_data_in;
output new_byte_available, end_of_frame,  rx_led;
output [31:0] data_out;

wire rx_led;
reg rx_led_tmp;
reg [31:0] data_out = 32'd304942678;
reg [23:0] data_tmp;

reg [2:0] in_data;
always @(posedge clk48) in_data <= {in_data[1:0], manchester_data_in};

reg [1:0] cnt;
always @(posedge clk48) if(|cnt || (in_data[2] ^ in_data[1])) cnt<=cnt+1;

reg [7:0] data;
reg new_bit_avail;
always @(posedge clk48) new_bit_avail <= (cnt==3);
always @(posedge clk48) if(cnt==3) data<={in_data[1],data[7:1]};

/////////////////////////////////////////////////
reg end_of_frame;

reg [4:0] sync1;
always @(posedge clk48)
if(end_of_frame)
  sync1<=0; 
else 
if(new_bit_avail) 
begin
  if(!(data==8'h55 || data==8'hAA)) // not preamble?
    sync1 <= 0;
  else
  if(~&sync1) // if all bits of this "sync1" counter are one, we decide that enough of the preamble
                  // has been received, so stop counting and wait for "sync2" to detect the SFD
    sync1 <= sync1 + 1; // otherwise keep counting
end

reg [9:0] sync2;
always @(posedge clk48)
if(end_of_frame)
  sync2 <= 0;
else 
if(new_bit_avail) 
begin
  if(|sync2) // if the SFD has already been detected (Ethernet data is coming in)
    sync2 <= sync2 + 1; // then count the bits coming in
  else
  if(&sync1 && data==8'hD5) // otherwise, let's wait for the SFD (0xD5)
    sync2 <= sync2 + 1;
end

wire new_byte_available = new_bit_avail && (sync2[2:0]==3'h0) && (sync2[9:3]!=0);  

/////////////////////////////////////////////////
// if no clock transistion is detected for some time, that's the end of the Ethernet frame

reg [2:0] transition_timeout;
always @(posedge clk48) if(in_data[2]^in_data[1]) transition_timeout<=0; else if(~&cnt) transition_timeout<=transition_timeout+1;
always @(posedge clk48) end_of_frame <= &transition_timeout;

reg [4:0] state_cnt;

//always @(posedge new_byte_available or posedge end_of_frame)
always @(posedge clk48)
begin
	if (end_of_frame) state_cnt<= 0;
	else if (new_byte_available)
	begin
		case(state_cnt)
		4'd0: if (data == 8'h13) state_cnt<= state_cnt+ 4'b1; else state_cnt<=0;
		4'd1: if (data == 8'h57) state_cnt<= state_cnt+ 4'b1; else state_cnt<=0;
		4'd2: if (data == 8'h9a) 
		begin
			state_cnt<= state_cnt+ 4'b1;
			data_tmp <= 0;
		end
		else state_cnt<=0;		
		4'd3: begin data_tmp <= data; state_cnt<= state_cnt+ 4'b1; end
		4'd4: begin data_tmp <= data_tmp + (data<<8); state_cnt<= state_cnt+ 4'b1; end
		4'd5: begin data_tmp <= data_tmp + (data<<16); state_cnt<= state_cnt+ 4'b1; end
		4'd6: if (data == 8'haa)
		begin
			data_out[31:8] <= data_tmp;
			state_cnt<= state_cnt+ 4'b1;
			rx_led_tmp <= 1;
		end
		else state_cnt<=0;
		4'd7: begin rx_led_tmp<= 0; state_cnt<= 0; end	
		endcase
	end
end

//delay timer for LED - 0.5s duration
reg [25:0] led_cnt;
always @(posedge clk48)
begin
	if (rx_led_tmp == 1) led_cnt <= 0;
	else if (led_cnt < 26'd24000000) led_cnt <= led_cnt + 1;
end

assign rx_led = ~(led_cnt < 23999998);



reg [8:0] counter;
//always @(posedge new_byte_available) if (end_of_frame == 1)  else counter<= counter + 8'd1;
always @(posedge new_byte_available or posedge end_of_frame)
begin
	if (end_of_frame) counter<= 0;
	else if (new_byte_available) counter<= counter + 8'd1;
end
 
//rx_ram my_rx_ram(.data(data),.wren(new_byte_available),.address(counter),.clock(clk48));



endmodule
