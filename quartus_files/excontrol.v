
/******************************************************
****************** Extended control module*************
**************************autor************************
*********************David Fainitski*******************	
*****************2015 Berlin, Germany******************		
******************************************************* 
***veryllog********************************************
***Quartus II 13.0 SP1 x64*****************************
******************************************************* 
*******************************************************/ 
              
                      // Extended control module
module excontrol (rx_tune_phase[14:0], Conn_X1 );	

input [14:0] rx_tune_phase;
output reg [2:0] Conn_X1;
//		
//***************************************************************************	
                       //      BPF	Control
always @(rx_tune_phase[14:0])//   Every time, if freq changes.....
begin
if       (rx_tune_phase[14:0] < 683 )// If freq less than 1M....
Conn_X1[2:0] <= 0; //then... code = 0 
else if (rx_tune_phase[14:0] < 1368 )//If not and less than 2М...
Conn_X1[2:0] <= 1; //then... code = 1
else if (rx_tune_phase[14:0] < 2735 )//If not and less 4М...
Conn_X1[2:0] <= 2; //code = 2
else if (rx_tune_phase[14:0] < 5464 )// <8М
Conn_X1[2:0] <= 3; // = 3
else if (rx_tune_phase[14:0] < 10239 ) // <15М 
Conn_X1[2:0] <= 4;
else //If more than 30М
Conn_X1[2:0] <= 6; 
end


endmodule						 
