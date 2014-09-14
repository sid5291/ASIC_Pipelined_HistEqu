`define AddressSize 16
`define DataBusSize 128
`define NumStates   9

module test_top();

/*-------------------------------Inputs-----------------------------------*/

reg                    clock;            /* Clock                     */
reg                    reset;            /* Reset                     */
reg 		           StartSignal;          /* Input from control block  */

/*------------------------------Outputs----------------------------------*/

wire  [`AddressSize-1:0] ReadAddressInput_1, ReadAddressInput_2;      /* Read Address Bus for Input SRAM    */
wire  [`AddressSize-1:0] ReadAddressScratch1_2, ReadAddressScratch2_1, ReadAddressScratch2_2;    /* Read Address Bus for Scratch SRAM  */    
wire  [`AddressSize-1:0] WriteAddressScratch1, WriteAddressScratch2, WriteAddressOutput;   /* Write Address Bus for Scratch SRAM */
wire  [`DataBusSize-1:0] WriteBusScratch1, WriteBusScratch2, WriteBusOutput;       /* Write Bus for Scratch SRAM         */
wire                     WriteEnableScratch1, WriteEnableScratch2, WriteEnableOutput;    /* Write Enable line for Scratch SRAM */
wire [1:0]              GlobalFlag;                  /* Completion state flag to Control   */   
wire [`DataBusSize-1:0] ReadBusInput_1, ReadBusInput_2;     /* Read Bus for Input SRAM   */
wire [`DataBusSize-1:0] ReadBusScratch1_2, ReadBusScratch2_1, ReadBusScratch2_2;   /* Read Bus for Scratch SRAM */  

initial
begin
	$readmemh("input_atomant.mem",input_mem.Register,0,19199);
	$readmemh("input_small_hex.txt",input_mem.Register,32768,51967);

	clock=0;
	reset = 1'b0;
	StartSignal = 2'b0;
	#3 reset = 1'b1;
	#8 reset = 1'b0;
		StartSignal = 2'b01;
	wait (GlobalFlag === 2'b01); 
		$writememh("output_final_1.txt", output_mem.Register,0,19199);
	wait (GlobalFlag === 2'b10); 
		$writememh("output_final_2.txt", output_mem.Register,32768,51967);
	$finish;
end

initial
begin 
//#10000 $finish;
end

always #5 clock = ~clock;



sram_2R1W input_mem(.clock(clock), .WE(1'b0), .WriteAddress(16'b0), .ReadAddress1(ReadAddressInput_1), .ReadAddress2(ReadAddressInput_2), .WriteBus(128'b0), .ReadBus1(ReadBusInput_1), 
	.ReadBus2(ReadBusInput_2));
sram_2R1W scratch1_mem(.clock(clock), .WE(WriteEnableScratch1), .WriteAddress(WriteAddressScratch1), .ReadAddress1(16'b0), .ReadAddress2(ReadAddressScratch1_2), .WriteBus(WriteBusScratch1), 
						.ReadBus2(ReadBusScratch1_2), .ReadBus1());
sram_2R1W output_mem(.clock(clock), .WE(WriteEnableOutput), .WriteAddress(WriteAddressOutput), .ReadAddress1(16'b0), .ReadAddress2(16'b0), .WriteBus(WriteBusOutput), .ReadBus1(), .ReadBus2());
sram_2R1W scratch2_mem(.clock(clock), .WE(WriteEnableScratch2), .WriteAddress(WriteAddressScratch2), .ReadAddress1(ReadAddressScratch2_1), .ReadAddress2(ReadAddressScratch2_2), 
	.WriteBus(WriteBusScratch2), .ReadBus1(ReadBusScratch2_1), .ReadBus2(ReadBusScratch2_2));

Top top1(.clock(clock), .reset(reset), .StartSignal(StartSignal), .ReadBusInput_1(ReadBusInput_1), .ReadBusInput_2(ReadBusInput_2), .ReadBusScratch1_2(ReadBusScratch1_2), 
	.ReadBusScratch2_1(ReadBusScratch2_1), .ReadBusScratch2_2(ReadBusScratch2_2), .ReadAddressInput_1(ReadAddressInput_1), .ReadAddressInput_2(ReadAddressInput_2), 
	.ReadAddressScratch1_2(ReadAddressScratch1_2), .ReadAddressScratch2_1(ReadAddressScratch2_1), .ReadAddressScratch2_2(ReadAddressScratch2_2), .WriteAddressOutput(WriteAddressOutput), 
	.WriteAddressScratch1(WriteAddressScratch1), .WriteAddressScratch2(WriteAddressScratch2), .WriteBusOutput(WriteBusOutput), .WriteBusScratch1(WriteBusScratch1), 
	.WriteBusScratch2(WriteBusScratch2), .WriteEnableOutput(WriteEnableOutput), .WriteEnableScratch1(WriteEnableScratch1), .WriteEnableScratch2(WriteEnableScratch2), .GlobalFlag(GlobalFlag));

endmodule