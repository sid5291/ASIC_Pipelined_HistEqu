/*************************************
*
* NAME:  Output
*
* DESCRIPTION:
*  Module 3 of the project
*
* NOTES:
*
* REVISION HISTORY*
*  Revision     Date       Programmer    Description
*  4.0          4/1/2014  SK15,DN,ARJ   
*M*/

`define AddressSize 16
`define AddressSizeMinusOne 15
`define DataBusSize 128
`define NumStates   11

/*====================================================================Declarations=======================================================================*/

module Output #(
/*-----------------------------Parameters---------------------------------*/
parameter [`AddressSize-2:0] ImageBaseAddress  			 = `AddressSizeMinusOne'h000,    		/* Starting address for Input and Output Image     */
parameter [`AddressSize-2:0] EqualizedBaseAddress  		 = `AddressSizeMinusOne'h000,    	/* Starting address for Equalized values    	   */
parameter [`AddressSize-2:0] EqualizedBaseAddressOffset  = `AddressSizeMinusOne'h008,    	/* Starting address for Equalized values    	   */
parameter [`AddressSize-2:0] CountBaseAddress  = `AddressSizeMinusOne'h000, 
parameter [18:0]             NumberofPixels     = 19'd19200,             			/* 640x480 Pixels / 16 pixels per read    */
parameter                    NumPixelVals       = 255,                   			/* Number of Values a Pixel can take: 2^8 */
parameter [3:0]              State0             = 4'b0000,               			/* State 0 */
parameter [3:0]              State1             = 4'b0001,               			/* State 1 */
parameter [3:0]              State2             = 4'b0011,               			/* State 2 */
parameter [3:0]              State3             = 4'b0010,               		  /* State 3 */
parameter [3:0]              State4             = 4'b0110,               			/* State 4 */
parameter [3:0]              State5             = 4'b0111,               			/* State 5 */
parameter [3:0]              State6             = 4'b1111,               			/* State 6 */
parameter [3:0]              State7             = 4'b1110,               			/* State 7 */
parameter [3:0]              State8             = 4'b1100,               			/* State 8 */
parameter [3:0]              State9             = 4'b1000,               			/* State 9 */
parameter [3:0]              State10	          = 4'b1001,							      /* State 10 */
parameter [3:0]              State11	          = 4'b1011,							      /* State 11 */
parameter [3:0]              State12            = 4'b1010                     /* State 12 */
)(clock, reset, Control, ReadBusInput, ReadBusScratch1, ReadBusScratch2, ReadAddressInput, ReadAddressScratch1, ReadAddressScratch2, 
	WriteAddressOutput, WriteBusOutput ,WriteEnableOutput, flag);

/*-------------------------------Inputs-----------------------------------*/

input                    clock;            					 /* Clock                     */
input [`DataBusSize-1:0] ReadBusInput;     					 /* Read Bus for Input SRAM   */
input [`DataBusSize-1:0] ReadBusScratch1, ReadBusScratch2;   /* Read Bus for Scratch SRAM */
input                    reset;            					 /* Reset                     */
input [1:0]              Control;          					 /* Input from control block  */

/*------------------------------Outputs----------------------------------*/

output  [`AddressSize-1:0] ReadAddressInput;      						/* Read Address Bus for Input SRAM    */
output  [`AddressSize-1:0] ReadAddressScratch1, ReadAddressScratch2;    /* Read Address Bus for Scratch SRAM  */    
output  [`AddressSize-1:0] WriteAddressOutput;    						/* Write Address Bus for Output SRAM  */
output  [`DataBusSize-1:0] WriteBusOutput;        						/* Write Bus for Output SRAM          */
output                     WriteEnableOutput;     						/* Write Enable line for Output SRAM  */
output                     flag;                  						/* Completion state flag to Control   */     


/*-------------------------Nets and Registers-----------------------------*/

reg  [`AddressSize-1:0] ReadAddressInput;   
reg  [`AddressSize-1:0] ReadAddressScratch1, ReadAddressScratch2; 
reg  [`AddressSize-1:0] WriteAddressOutput; 
reg  [`DataBusSize-1:0] WriteBusOutput;     
reg                     WriteEnableOutput;  
reg                     flag;   
reg  [7:0]     			Equalized_Vals [0:255];
reg  [4:0]				count;
reg  [18:0]      		PixelCount, PixelCount_1d, PixelCount_2d, PixelCount_3d;
reg 					doneequ;
reg  [7:0]				Pixel_0, Pixel_1, Pixel_2, Pixel_3, Pixel_4, Pixel_5, Pixel_6, Pixel_7;
reg  [7:0]				Pixel_8, Pixel_9, Pixel_10, Pixel_11, Pixel_12, Pixel_13, Pixel_14, Pixel_15;
reg  [127:0]			TempWriteBus;

reg [7:0] count_mul_16, count_mul_16_128;
reg doneequ_d;
integer i;

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(doneequ == 1'b0)
    		begin
    		count  <= count + 1'b1;
    		
			end
    	default:
    	begin
        	count <= 5'd0;
    	end
	endcase
end

always@(posedge clock)
begin
    count_mul_16 <= count<<4;
    count_mul_16_128 <= (count<<4) + 128;
    doneequ_d <= doneequ;
end

always@(posedge clock)
begin
casex({reset,Control[0]})
    2'b01:
    	if (doneequ == 1'b0) 
    	begin
    		ReadAddressScratch1 <= count + {Control[1], EqualizedBaseAddress};
    		ReadAddressScratch2 <= count + {Control[1], EqualizedBaseAddressOffset};
    	end
    default:
    begin
        ReadAddressScratch1 <= 16'd0;
        ReadAddressScratch2 <= 16'd0;
    end
endcase
end


always@(posedge clock)
	begin
		casex({reset,Control[0]})
		    2'b01:
		    	if (doneequ_d == 1'b0) 
		    	begin
		    		Equalized_Vals[(count_mul_16)] 	    <= ReadBusScratch1 [7:0];
		    		Equalized_Vals[count_mul_16+1] 	    <= ReadBusScratch1 [15:8];
		    		Equalized_Vals[(count_mul_16)+2] 	<= ReadBusScratch1 [23:16];
		    		Equalized_Vals[(count_mul_16)+3] 	<= ReadBusScratch1 [31:24];
		    		Equalized_Vals[(count_mul_16)+4] 	<= ReadBusScratch1 [39:32];
		    		Equalized_Vals[(count_mul_16)+5] 	<= ReadBusScratch1 [47:40];
		    		Equalized_Vals[(count_mul_16)+6] 	<= ReadBusScratch1 [55:48];
		    		Equalized_Vals[(count_mul_16)+7] 	<= ReadBusScratch1 [63:56];
		    		Equalized_Vals[(count_mul_16)+8] 	<= ReadBusScratch1 [71:64];
		    		Equalized_Vals[(count_mul_16)+9] 	<= ReadBusScratch1 [79:72];
		    		Equalized_Vals[(count_mul_16)+10] 	<= ReadBusScratch1 [87:80];
		    		Equalized_Vals[(count_mul_16)+11] 	<= ReadBusScratch1 [95:88];
		    		Equalized_Vals[(count_mul_16)+12] 	<= ReadBusScratch1 [103:96];
		    		Equalized_Vals[(count_mul_16)+13] 	<= ReadBusScratch1 [111:104];
		    		Equalized_Vals[(count_mul_16)+14] 	<= ReadBusScratch1 [119:112];
		    		Equalized_Vals[(count_mul_16)+15] 	<= ReadBusScratch1 [127:120];

		    		Equalized_Vals[(count_mul_16_128)] 	    <= ReadBusScratch2 [7:0];
		    		Equalized_Vals[count_mul_16_128+1] 	    <= ReadBusScratch2 [15:8];
		    		Equalized_Vals[(count_mul_16_128)+2] 	<= ReadBusScratch2 [23:16];
		    		Equalized_Vals[(count_mul_16_128)+3] 	<= ReadBusScratch2 [31:24];
		    		Equalized_Vals[(count_mul_16_128)+4] 	<= ReadBusScratch2 [39:32];
		    		Equalized_Vals[(count_mul_16_128)+5] 	<= ReadBusScratch2 [47:40];
		    		Equalized_Vals[(count_mul_16_128)+6] 	<= ReadBusScratch2 [55:48];
		    		Equalized_Vals[(count_mul_16_128)+7] 	<= ReadBusScratch2 [63:56];
		    		Equalized_Vals[(count_mul_16_128)+8] 	<= ReadBusScratch2 [71:64];
		    		Equalized_Vals[(count_mul_16_128)+9] 	<= ReadBusScratch2 [79:72];
		    		Equalized_Vals[(count_mul_16_128)+10] 	<= ReadBusScratch2 [87:80];
		    		Equalized_Vals[(count_mul_16_128)+11] 	<= ReadBusScratch2 [95:88];
		    		Equalized_Vals[(count_mul_16_128)+12] 	<= ReadBusScratch2 [103:96];
		    		Equalized_Vals[(count_mul_16_128)+13] 	<= ReadBusScratch2 [111:104];
		    		Equalized_Vals[(count_mul_16_128)+14] 	<= ReadBusScratch2 [119:112];
		    		Equalized_Vals[(count_mul_16_128)+15] 	<= ReadBusScratch2 [127:120];
		    		
				end
		    default:
		    begin
		        for(i=0; i<256; i=i+1)
		        	Equalized_Vals[i] <= 8'b0;
		    end
		endcase
	end


always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(count == 7)
    		doneequ  <= 1'b1;

    	default:
    	begin
        	doneequ <= 1'b0;
    	end
	endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(doneequ) 
    		begin
    			PixelCount <= PixelCount + 1'b1;
    			PixelCount_1d <= PixelCount;
    			PixelCount_2d <= PixelCount_1d;
    			PixelCount_3d <= PixelCount_2d;
    		end
    	default:
    	begin
        	PixelCount <= 19'd0;
        	PixelCount_1d <= 19'd0;
    		PixelCount_2d <= 19'd0;
    		PixelCount_3d <= 19'd0;
    	end
	endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(doneequ) ReadAddressInput  <= PixelCount + {Control[1],ImageBaseAddress};
    	default:
    	begin
        	ReadAddressInput <= 16'd0;
    	end
	endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(doneequ) 
    		begin
    			Pixel_0  <= ReadBusInput [7:0];
    			Pixel_1  <= ReadBusInput [15:8];
    			Pixel_2  <= ReadBusInput [23:16];
    			Pixel_3  <= ReadBusInput [31:24];
    			Pixel_4  <= ReadBusInput [39:32];
    			Pixel_5  <= ReadBusInput [47:40];
    			Pixel_6  <= ReadBusInput [55:48];
    			Pixel_7  <= ReadBusInput [63:56];
    			Pixel_8  <= ReadBusInput [71:64];
    			Pixel_9  <= ReadBusInput [79:72];
    			Pixel_10 <= ReadBusInput [87:80];
    			Pixel_11 <= ReadBusInput [95:88];
    			Pixel_12 <= ReadBusInput [103:96];
    			Pixel_13 <= ReadBusInput [111:104];
    			Pixel_14 <= ReadBusInput [119:112];
    			Pixel_15 <= ReadBusInput [127:120];
    		end
    	default:
    	begin
        		Pixel_0  <= 8'd0;
    			Pixel_1  <= 8'd0;
    			Pixel_2  <= 8'd0;
    			Pixel_3  <= 8'd0;
    			Pixel_4  <= 8'd0;
    			Pixel_5  <= 8'd0;
    			Pixel_6  <= 8'd0;
    			Pixel_7  <= 8'd0;
    			Pixel_8  <= 8'd0;
    			Pixel_9  <= 8'd0;
    			Pixel_10 <= 8'd0;
    			Pixel_11 <= 8'd0;
    			Pixel_12 <= 8'd0;
    			Pixel_13 <= 8'd0;
    			Pixel_14 <= 8'd0;
    			Pixel_15 <= 8'd0;
    	end
    endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(doneequ) 
    		begin
    			  TempWriteBus [7:0]		<= Equalized_Vals[Pixel_0];
    			  TempWriteBus [15:8]       <= Equalized_Vals[Pixel_1];
    			  TempWriteBus [23:16]		<= Equalized_Vals[Pixel_2];
    			  TempWriteBus [31:24]		<= Equalized_Vals[Pixel_3];
    			  TempWriteBus [39:32]		<= Equalized_Vals[Pixel_4];
    			  TempWriteBus [47:40]		<= Equalized_Vals[Pixel_5];
    			  TempWriteBus [55:48]		<= Equalized_Vals[Pixel_6];
    			  TempWriteBus [63:56]		<= Equalized_Vals[Pixel_7];
    			  TempWriteBus [71:64]		<= Equalized_Vals[Pixel_8];
    			  TempWriteBus [79:72]		<= Equalized_Vals[Pixel_9];
    			  TempWriteBus [87:80]		<= Equalized_Vals[Pixel_10];
    			  TempWriteBus [95:88]		<= Equalized_Vals[Pixel_11];
    			  TempWriteBus [103:96]		<= Equalized_Vals[Pixel_12];
    			  TempWriteBus [111:104]	<= Equalized_Vals[Pixel_13];
    			  TempWriteBus [119:112]	<= Equalized_Vals[Pixel_14];
    			  TempWriteBus [127:120]	<= Equalized_Vals[Pixel_15];
    		end
    	default:
    	begin
        		TempWriteBus [127:0]		<= 128'd0;
		end
    endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if(PixelCount_2d!=19'd0)
    		begin
    			WriteEnableOutput  <= 1'b1;
    			WriteAddressOutput <= (PixelCount_2d - 1'b1) + {Control[1],ImageBaseAddress};
    			WriteBusOutput	   <= TempWriteBus;
    		end
    	default:
    	begin
        	WriteEnableOutput  <= 1'b0;
    		WriteAddressOutput <= 16'd0;
    		WriteBusOutput	   <= 128'd0;
    	end
	endcase
end

always@(posedge clock)
begin
	casex({reset,Control[0]})
    	2'b01:
    		if((PixelCount_3d-1) == NumberofPixels)
    		
    			flag <= 1'b1;
    		
    		else flag <= 1'b0;
    	default:
    	begin
        	flag <= 1'b0;
    	end
	endcase
end

endmodule