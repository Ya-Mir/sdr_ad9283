//Ethernet_TDp, Ethernet_TDm - ����� Ethernet ��������
//ext_ram_adr - ����� ������������� �����
//ext_ram_data - �������� ������������ �����
//start - ������ ��������
//tx_led - ����� �� ����� ��������
//clk20 - 20 ���
module TENBASET_TxD(clk20, Ethernet_TDp, Ethernet_TDm, ext_ram_adr, ext_ram_data, start, tx_led);

 // a 20MHz clock (this code won't work with a different frequency)
input clk20;
input start;
output [9:0] ext_ram_adr;
input [7:0] ext_ram_data;
output tx_led;

 // the two differential 10BASE-T outputs
output Ethernet_TDp, Ethernet_TDm;

 // "IP source" - put an unused IP - if unsure, see comment below after the source code
parameter IPsource_1 = 192;
parameter IPsource_2 = 168;
parameter IPsource_3 = 10;
parameter IPsource_4 = 44;

 // "IP destination" - put the IP of the PC you want to send to
parameter IPdestination_1 = 192;
parameter IPdestination_2 = 168;
parameter IPdestination_3 = 10;
parameter IPdestination_4 = 10;

 // "Physical Address" - put the address of the PC you want to send to
parameter PhysicalAddress_1 = 8'h20;
parameter PhysicalAddress_2 = 8'h47;
parameter PhysicalAddress_3 = 8'h47;
parameter PhysicalAddress_4 = 8'h36;
parameter PhysicalAddress_5 = 8'h97;
parameter PhysicalAddress_6 = 8'h08;
 //


parameter payload_length = 16'd1024;


parameter UDP_payload_length = 16'd8 + payload_length;//payload + 8

parameter IP_total_length = 16'd28 + payload_length;//(Total Length = 20 + 8 + payload)

parameter adress_end1 = 12'd54 + payload_length;//54+payload_length
parameter adress_end2 = 12'd50 + payload_length;//adress_end1 - 4

 //////////////////////////////////////////////////////////////////////
 // sends a packet roughly every second
//reg [23:0] counter; always @(posedge clk20) counter<=counter+1;
//reg StartSending; always @(posedge clk20) StartSending<=&counter;
reg StartSending; always @(posedge clk20) StartSending<=start;


 //////////////////////////////////////////////////////////////////////
 // we send a UDP packet, 18 bytes payload

 // calculate the IP checksum, big-endian style
parameter IPchecksum1 = 32'h0000C511 + IP_total_length[15:0] + (IPsource_1<<8)+IPsource_2+(IPsource_3<<8)+IPsource_4+
                                                                 (IPdestination_1<<8)+IPdestination_2+(IPdestination_3<<8)+(IPdestination_4);
parameter IPchecksum2 =  ((IPchecksum1&32'h0000FFFF)+(IPchecksum1>>16));
parameter IPchecksum3 = ~((IPchecksum2&32'h0000FFFF)+(IPchecksum2>>16));

reg [11:0] rdaddress;
reg [7:0] pkt_data;
wire ext_memory = (((rdaddress > 12'd49) && (rdaddress < adress_end2))? 1: 0);

wire [7:0] pkt_data_mux = (ext_memory ? ext_ram_data : pkt_data);//data to transmit

assign ext_ram_adr = (ext_memory ? (rdaddress - 12'd50): 0);

always @(posedge clk20) 
case(rdaddress)
 // Ethernet preamble
   12'h00: pkt_data <= 8'h55;
   12'h01: pkt_data <= 8'h55;
   12'h02: pkt_data <= 8'h55;
   12'h03: pkt_data <= 8'h55;
   12'h04: pkt_data <= 8'h55;
   12'h05: pkt_data <= 8'h55;
   12'h06: pkt_data <= 8'h55;
   12'h07: pkt_data <= 8'hD5;
 // Ethernet header
   12'h08: pkt_data <= 8'h20;
   12'h09: pkt_data <= 8'h47;
   12'h0A: pkt_data <= 8'h47;
   12'h0B: pkt_data <= 8'h36;
   12'h0C: pkt_data <= 8'h97;
   12'h0D: pkt_data <= 8'h08;

	
	
   12'h0E: pkt_data <= 8'h00;
   12'h0F: pkt_data <= 8'h12;
   12'h10: pkt_data <= 8'h34;
   12'h11: pkt_data <= 8'h56;
   12'h12: pkt_data <= 8'h78;
   12'h13: pkt_data <= 8'h90;
 
 // Ethernet type
   12'h14: pkt_data <= 8'h08;
   12'h15: pkt_data <= 8'h00;
 // IP header
   12'h16: pkt_data <= 8'h45;//byte 0
   12'h17: pkt_data <= 8'h00;//byte 1
   12'h18: pkt_data <= IP_total_length[15:8];//Total Length 0 (Total Length = 20 + 8 + payload)
   12'h19: pkt_data <= IP_total_length[7:0];//Total Length 1
   12'h1A: pkt_data <= 8'h00;//Identification
   12'h1B: pkt_data <= 8'h00;//Identification
   12'h1C: pkt_data <= 8'h00;//byte 6
   12'h1D: pkt_data <= 8'h00;//byte 7
   12'h1E: pkt_data <= 8'h80;//byte 8
   12'h1F: pkt_data <= 8'h11;//byte 9
   12'h20: pkt_data <= IPchecksum3[15:8];
   12'h21: pkt_data <= IPchecksum3[ 7:0];
   12'h22: pkt_data <= IPsource_1;
   12'h23: pkt_data <= IPsource_2;
   12'h24: pkt_data <= IPsource_3;
   12'h25: pkt_data <= IPsource_4;
   12'h26: pkt_data <= IPdestination_1;
   12'h27: pkt_data <= IPdestination_2;
   12'h28: pkt_data <= IPdestination_3;
   12'h29: pkt_data <= IPdestination_4;
 // UDP header
   12'h2A: pkt_data <= 8'h04;//UPD source port
   12'h2B: pkt_data <= 8'h00;//UPD source port
   12'h2C: pkt_data <= 8'h04;//UPD destination port 
   12'h2D: pkt_data <= 8'h00;//UPD destination port
   12'h2E: pkt_data <= UDP_payload_length[15:8];//UDP payload length
   12'h2F: pkt_data <= UDP_payload_length[7:0];//UDP payload length
   12'h30: pkt_data <= 8'h00;//UPD checksum
   12'h31: pkt_data <= 8'h00;//UPD checksum (h31 = d49)
 // payload
   default: pkt_data <= 8'h00; //last 4 bytes is checksumm
endcase

 //////////////////////////////////////////////////////////////////////
 // and finally the 10BASE-T's magic
reg [3:0] ShiftCount;
reg SendingPacket;
always @(posedge clk20) if(StartSending) SendingPacket<=1; else if(ShiftCount==14 && rdaddress== adress_end1) SendingPacket<=0;
assign tx_led = SendingPacket;

always @(posedge clk20) ShiftCount <= (SendingPacket ? ShiftCount+1 : 15);//8bit -> 16 tick

wire readram = (ShiftCount==15);//start read data signal
always @(posedge clk20) if(ShiftCount==15) rdaddress <= (SendingPacket ? rdaddress+1 : 0);//calculate byte adress

reg [7:0] ShiftData; 
always @(posedge clk20) 
begin
	if(ShiftCount[0]) ShiftData <= (readram ? pkt_data_mux : {1'b0, ShiftData[7:1]});//calculate data to send
end


 // generate the CRC32
reg [31:0] CRC;
reg CRCflush; 
always @(posedge clk20) if(CRCflush) CRCflush <= SendingPacket; else if(readram) CRCflush <= (rdaddress==adress_end2);
reg CRCinit; 
always @(posedge clk20) if(readram) CRCinit <= (rdaddress==7);
wire CRCinput = CRCflush ? 0 : (ShiftData[0] ^ CRC[31]);
always @(posedge clk20) if(ShiftCount[0]) CRC <= CRCinit ? ~0 : ({CRC[30:0],1'b0} ^ ({32{CRCinput}} & 32'h04C11DB7));

 // generate the NLP
reg [17:0] LinkPulseCount; always @(posedge clk20) LinkPulseCount <= SendingPacket ? 0 : LinkPulseCount+1;//inc if no tx
reg LinkPulse; always @(posedge clk20) LinkPulse <= &LinkPulseCount[17:1];//2 ticks

 // TP_IDL, shift-register and manchester encoder
reg SendingPacketData;
always @(posedge clk20) SendingPacketData <= SendingPacket;

reg [2:0] idlecount;
always @(posedge clk20) if(SendingPacketData) idlecount<=0; else if(~&idlecount) idlecount<=idlecount+1;

wire dataout = CRCflush ? ~CRC[31] : ShiftData[0];
reg qo; always @(posedge clk20) qo <= SendingPacketData ? ~dataout^ShiftCount[0] : 1;
reg qoe; always @(posedge clk20) qoe <= SendingPacketData | LinkPulse | (idlecount<7);
reg Ethernet_TDp; always @(posedge clk20) Ethernet_TDp <= (qoe ? qo : 1'b0);
reg Ethernet_TDm; always @(posedge clk20) Ethernet_TDm <= (qoe ? ~qo : 1'b0);

endmodule
