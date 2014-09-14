`define AddressSize 16
`define AddressSizeMinusOne 15
`define DataBusSize 128

module Top(clock, reset, StartSignal, ReadBusInput_1, ReadBusInput_2, ReadBusScratch1_2, ReadBusScratch2_1, ReadBusScratch2_2, 
	       ReadAddressInput_1, ReadAddressInput_2, ReadAddressScratch1_2, ReadAddressScratch2_1, ReadAddressScratch2_2, 
	       WriteAddressOutput, WriteAddressScratch1, WriteAddressScratch2, WriteBusOutput, WriteBusScratch1, WriteBusScratch2, 
	       WriteEnableOutput, WriteEnableScratch1, WriteEnableScratch2, GlobalFlag);

/*-------------------------------Inputs-----------------------------------*/

input 						clock;
input 						reset;
input 						StartSignal;
input [`DataBusSize-1:0]	ReadBusInput_1;
input [`DataBusSize-1:0]	ReadBusInput_2 ;
input [`DataBusSize-1:0]	ReadBusScratch1_2;
input [`DataBusSize-1:0]	ReadBusScratch2_1;
input [`DataBusSize-1:0]	ReadBusScratch2_2;
input [`AddressSize-1:0]	ReadAddressInput_1;
input [`AddressSize-1:0]	ReadAddressInput_2;
input [`AddressSize-1:0]	ReadAddressScratch1_2;
input [`AddressSize-1:0]	ReadAddressScratch2_1;
input [`AddressSize-1:0]	ReadAddressScratch2_2;

/*------------------------------Outputs----------------------------------*/

output [`AddressSize-1:0]	WriteAddressOutput;
output [`AddressSize-1:0]	WriteAddressScratch1;
output [`AddressSize-1:0]	WriteAddressScratch2;
output [`DataBusSize-1:0]	WriteBusOutput;
output [`DataBusSize-1:0]	WriteBusScratch1;
output [`DataBusSize-1:0]	WriteBusScratch2;
output 						WriteEnableOutput;
output 						WriteEnableScratch1;
output 						WriteEnableScratch2;
output [1:0]         		GlobalFlag;

/*-------------------------Registers-----------------------------*/

wire [`AddressSize-1:0]		WriteAddressOutput;
wire [`AddressSize-1:0]		WriteAddressScratch1;
wire [`AddressSize-1:0]		WriteAddressScratch2;
wire [`DataBusSize-1:0]		WriteBusOutput;
wire [`DataBusSize-1:0]		WriteBusScratch1;
wire [`DataBusSize-1:0]		WriteBusScratch2;
wire 						WriteEnableOutput;
wire 						WriteEnableScratch1;
wire 						WriteEnableScratch2;
wire [1:0]     				GlobalFlag;

/*-------------------------wires-----------------------------*/
wire [1:0]  HistControl, EquControl, OutputControl;
wire 		HistFlag, EquFlag, OutputFlag;

/*-------------------------Instantiations-----------------------------*/

Histogram #(.NumberofPixels(19'd19200)) h1(.clock(clock), .reset(reset), .Control(HistControl), .ReadBusInput(ReadBusInput_1), .ReadAddressInput(ReadAddressInput_1), 
			  .WriteAddressScratch(WriteAddressScratch1), .WriteBusScratch(WriteBusScratch1), .WriteEnableScratch(WriteEnableScratch1), .flag(HistFlag));

topeq  e1(.clock(clock), .reset(reset), .Control(EquControl), .ReadBusScratch1(ReadBusScratch1_2), .ReadAddressScratch1(ReadAddressScratch1_2), 
	         .WriteAddressScratch2(WriteAddressScratch2), .WriteBusScratch2(WriteBusScratch2), .WriteEnableScratch2(WriteEnableScratch2), .flag(EquFlag));

Output #(.NumberofPixels(19'd19200)) o1(.clock(clock), .reset(reset), .Control(OutputControl), .ReadBusInput(ReadBusInput_2), .ReadBusScratch1(ReadBusScratch2_1), .ReadBusScratch2(ReadBusScratch2_2),
		 .ReadAddressInput(ReadAddressInput_2), 
		  .ReadAddressScratch1(ReadAddressScratch2_1), .ReadAddressScratch2(ReadAddressScratch2_2), .WriteAddressOutput(WriteAddressOutput),.WriteBusOutput(WriteBusOutput),
		  .WriteEnableOutput(WriteEnableOutput), .flag(OutputFlag));
Control c1 (.clock(clock), .reset(reset), .HistFlag(HistFlag), .EquFlag(EquFlag), .OutputFlag(OutputFlag), .StartSignal(StartSignal),
                        .HistControl(HistControl),.EquControl(EquControl),.OutputControl(OutputControl),.FinalFlag(GlobalFlag));
endmodule
