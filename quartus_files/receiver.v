

module Receiver(
	input clock,
	input ready,
	input [7:0] adc_data,
	input [31:0] rx_freq,
	input signed [15:0] tx_real,
	input signed [15:0] tx_imag,
	output wire out_ready,
	output  [2:0] lpf_control,
	output reg signed [23:0] rx_real,
	output reg signed [23:0] rx_imag,
	output [13:0] dac_data
	);
	
	reg [13:0] adc_data_cap;
	assign out_ready = cic_outstrobe_2;
	always @(negedge clock) adc_data_cap <= adc_data;
	always @(posedge decim_avail) begin  rx_real <= decim_real; rx_imag <= decim_imag;  end

	excontrol ex (rx_freq[30:16], lpf_control[2:0] )	;
	
	
//------------------------------------------------------------------------------
//                               cordic
//------------------------------------------------------------------------------
cordic_rx cordic(
  .clock(clock),
  .in_data({adc_data[7:0], 8'b0}),  //16 bit input
  .frequency(rx_freq),         //32 bit
  .out_data_I(cordic_outdata_I), //22 bit
  .out_data_Q(cordic_outdata_Q)
  );
 
wire signed [21:0] cordic_outdata_I;
wire signed [21:0] cordic_outdata_Q;
  
//cordic rx_cordic (adc_data_cap, clock, rx_freq, cordic_outdata_I, cordic_outdata_Q); 

//------------------------------------------------------------------------------
//                     register-based CIC decimator
//------------------------------------------------------------------------------
//I channel
cic #(.STAGES(3), .DECIMATION(50), .IN_WIDTH(22), .ACC_WIDTH(39), .OUT_WIDTH(24))
  cic_inst_I1(
    .clock(clock),
    .in_strobe(1'b1),
    .out_strobe(cic_outstrobe_1),
    .in_data(cordic_outdata_I),
    .out_data(cic_outdata_I1)
    );


//Q channel
cic #(.STAGES(3), .DECIMATION(50), .IN_WIDTH(22), .ACC_WIDTH(39), .OUT_WIDTH(24))
  cic_inst_Q1(
    .clock(clock),
    .in_strobe(1'b1),
    .out_strobe(),
    .in_data(cordic_outdata_Q),
    .out_data(cic_outdata_Q1)
    );


wire cic_outstrobe_1;
wire signed [23:0] cic_outdata_I1;
wire signed [23:0] cic_outdata_Q1;

//------------------------------------------------------------------------------
//                       memory-based CIC decimator
//------------------------------------------------------------------------------
memcic #(.STAGES(11), .DECIMATION(10)) 
  memcic_inst_I(
    .clock(clock),
    .in_strobe(cic_outstrobe_1),
    .out_strobe(cic_outstrobe_2),
    .in_data(cic_outdata_I1),
    .out_data(cic_outdata_I2)
    );


memcic #(.STAGES(11), .DECIMATION(10)) 
  memcic_inst_Q(
    .clock(clock),
    .in_strobe(cic_outstrobe_1),
    .out_strobe(),
    .in_data(cic_outdata_Q1),
    .out_data(cic_outdata_Q2)
    );



wire cic_outstrobe_2;
wire signed [23:0] cic_outdata_I2;
wire signed [23:0] cic_outdata_Q2;

wire [23:0] decim_real, decim_imag;
wire decim_avail;

//------------------------------------------------------------------------------
//                     FIR coefficients and sequencing
//------------------------------------------------------------------------------
wire signed [23:0] fir_coeff;

fir_coeffs fir_coeffs_inst(
  .clock(clock),
  .start(cic_outstrobe_2),
  .coeff(fir_coeff)
  );
 
//------------------------------------------------------------------------------
//                            FIR decimator
//------------------------------------------------------------------------------

fir #(.OUT_WIDTH(24))
  fir_inst_I(
    .clock(clock),
    .start(cic_outstrobe_2), 
    .coeff(fir_coeff),
    .in_data(cic_outdata_I2),
    .out_data(decim_real),
    .out_strobe(decim_avail)
    );


fir #(.OUT_WIDTH(24))
  fir_inst_Q(
    .clock(clock),
    .start(cic_outstrobe_2),
    .coeff(fir_coeff),
    .in_data(cic_outdata_Q2),
    .out_data(decim_imag),
    .out_strobe()
    );

reg  signed [15:0] tx_reg_real, tx_reg_imag;
	always @(posedge req1) begin tx_reg_real <= tx_real; tx_reg_imag <= tx_imag;  end 
	
	
	// Interpolate I/Q samples in memory from 96 kHz to the clock frequency
	wire req1, req2;
	wire signed [19:0] y1_r, y1_i;
	wire signed [15:0] y2_r, y2_i;
	FirInterp8 fi (clock, req2, req1, tx_reg_real, tx_reg_imag, y1_r, y1_i);
	CicInterpM5 #(.RRRR(125), .IBITS(20), .OBITS(16), .GBITS(28))
        	in2 (clock, 1'd1, req2, y1_r, y1_i, y2_r, y2_i);

	// Tune transmitter with CORDIC
   wire signed [15:0]cordic_out_i, cordic_out_q;	
	cordic_tx #(.OUT_WIDTH(16))
 		cordic_inst (.clock(clock), .frequency(rx_freq), .in_data_I(y2_i[15:0]),			
		.in_data_Q(y2_r[15:0]), .out_data_I(cordic_out_i), .out_data_Q(cordic_out_q));
	
	assign dac_data = cordic_out_i[15:2];
	
	
endmodule	