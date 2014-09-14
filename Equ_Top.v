/*************************************
*
* NAME:  Equalizer Top Module
*
* DESCRIPTION:
*  Equalizer
*
* NOTES:
*
* REVISION HISTORY*
*  Revision     Date       Programmer    Description
*  1.0          04/04/2014  SK15,DN      Top Module for Equlaizer
*                                        
*M*****************************************/
// synopsys off
`include "DW_div_pipe.v"
`include "DW02_mult_4_stage.v"   
//synopsys on

`define AddressSize 16
`define AddressSizeMinusOne 15
`define DataBusSize 127
`define NumStates   10 
`define Shift       28  

module topeq(clock, reset, Control, ReadBusScratch1, ReadAddressScratch1, WriteAddressScratch2,WriteBusScratch2,WriteEnableScratch2,flag);

/*-------------------------------Inputs-----------------------------------*/

input                    clock;             /* clock                     */
input [`DataBusSize:0]   ReadBusScratch1;   /* Read Bus for Scratch SRAM */
input                    reset;             /* reset                     */
input [1:0]              Control;           /* Input from control block  */

                      
/*------------------------------Outputs----------------------------------*/


output [`AddressSizeMinusOne:0] ReadAddressScratch1;    /* Read Address Bus for Scratch SRAM  */    
output [`AddressSizeMinusOne:0] WriteAddressScratch2;   /* Write Address Bus for Scratch SRAM */
output [`DataBusSize:0]         WriteBusScratch2;       /* Write Bus for Scratch SRAM         */
output                          WriteEnableScratch2;    /* Write Enable line for Scratch SRAM */ 
output                          flag; 



wire [`AddressSizeMinusOne:0] ReadAddressScratch1;    /* Read Address Bus for ReadBusScratch1ratch SRAM  */    
wire [`AddressSizeMinusOne:0] WriteAddressScratch2;   /* Write Address Bus for Scratch SRAM */
wire [`DataBusSize:0]         WriteBusScratch2;       /* Write Bus for Scratch SRAM         */
wire                          WriteEnableScratch2;    /* Write Enable line for Scratch SRAM */ 
wire                          flag; 

wire [(`Shift+8+31):0]  Mul_product_0;
wire [(`Shift+8+31):0]  Mul_product_1;
wire [(`Shift+8+31):0]  Mul_product_2;
wire [(`Shift+8+31):0]  Mul_product_3;
wire [`Shift+7:0]       Div_quotient;

wire [`Shift+7:0]             Dividend;
wire [31:0]                   Divisor;
wire [31:0]                   Multiplicant_1_0;
wire [31:0]                   Multiplicant_1_1;
wire [31:0]                   Multiplicant_1_2;
wire [31:0]                   Multiplicant_1_3;
wire [`Shift+7:0]             Multiplicant_2_0;
wire [`Shift+7:0]             Multiplicant_2_1;
wire [`Shift+7:0]             Multiplicant_2_2;
wire [`Shift+7:0]             Multiplicant_2_3;                      

 
Equalizer eq1 (.clock(clock), .reset(reset), .Control(Control), .ReadBusScratch1(ReadBusScratch1), .Mul_product_0(Mul_product_0), .Mul_product_1(Mul_product_1), .Mul_product_2(Mul_product_2), .Mul_product_3(Mul_product_3), 
				.Div_quotient(Div_quotient), 
                .ReadAddressScratch1(ReadAddressScratch1), .WriteAddressScratch2(WriteAddressScratch2),.WriteBusScratch2(WriteBusScratch2),.WriteEnableScratch2(WriteEnableScratch2),
                .flag(flag), .Dividend(Dividend), .Divisor(Divisor),
                .Multiplicant_1_0(Multiplicant_1_0), .Multiplicant_1_1(Multiplicant_1_1), .Multiplicant_1_2(Multiplicant_1_2), .Multiplicant_1_3(Multiplicant_1_3),
                .Multiplicant_2_0(Multiplicant_2_0), .Multiplicant_2_1(Multiplicant_2_1), .Multiplicant_2_2(Multiplicant_2_2), .Multiplicant_2_3(Multiplicant_2_3));

DW02_mult_4_stage  #(.A_width(32),
                     .B_width(`Shift+8)) mul0 (.CLK(clock),.A(Multiplicant_1_0),.B(Multiplicant_2_0), .PRODUCT(Mul_product_0),.TC(1'b0));

DW02_mult_4_stage  #(.A_width(32),
                     .B_width(`Shift+8)) mul1 (.CLK(clock),.A(Multiplicant_1_1),.B(Multiplicant_2_1), .PRODUCT(Mul_product_1),.TC(1'b0));

DW02_mult_4_stage  #(.A_width(32),
                     .B_width(`Shift+8)) mul2 (.CLK(clock),.A(Multiplicant_1_2),.B(Multiplicant_2_2), .PRODUCT(Mul_product_2),.TC(1'b0));

DW02_mult_4_stage  #(.A_width(32),
                     .B_width(`Shift+8)) mul3 (.CLK(clock),.A(Multiplicant_1_3),.B(Multiplicant_2_3), .PRODUCT(Mul_product_3),.TC(1'b0));

DW_div_pipe          #(.a_width(`Shift+8),
                     .b_width(32),
                     .num_stages(4),
                     .stall_mode(0) ) div (.clk(clock),.rst_n(!reset),.en(1'b0),.a(Dividend),.b(Divisor),.quotient(Div_quotient));
endmodule