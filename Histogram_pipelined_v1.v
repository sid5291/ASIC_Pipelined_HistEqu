/*************************************
*
* NAME:  Histogram
*
* DESCRIPTION:
*  Histogram
*
* NOTES:
*
* REVISION HISTORY*
*  Revision     Date       Programmer    Description
*  4.0          3/23/2014  SK15,DN,ARJ   With Pipelined FSM 
*                                        Considering 16 pixel read
*M*/

`define AddressSize 16
`define AddressSizeMinusOne 15
`define DataBusSize 128
`define NumStates   4

/*=============================Declarations===============================*/


module Histogram #(
/*-----------------------------Parameters---------------------------------*/
parameter [`AddressSize-2:0] ImageBaseAddress  = `AddressSizeMinusOne'h000,    /* Starting address for Image             */
parameter [`AddressSize-2:0] CountBaseAddress  = `AddressSizeMinusOne'h000,    /* Starting address for Counters          */
parameter [18:0]             NumberofPixels     = 19'd10,                      /* 640x480 Pixels / 16 pixels per read    */
parameter                    NumPixelVals       = 255,                         /* Number of Values a Pixel can take: 2^8 */
parameter [3:0]              State0             = 2'b00,                       /* State 0 */
parameter [3:0]              State1             = 2'b01,                       /* State 1 */
parameter [3:0]              State2             = 2'b11,                       /* State 2 */
parameter [3:0]              State3             = 2'b10,                       /* State 3 */
parameter [3:0]              p_State0           = 4'b0001                      /* State 0 */
)

(clock, reset, Control, ReadBusInput, ReadAddressInput, WriteAddressScratch,WriteBusScratch,WriteEnableScratch,flag);

/*-------------------------------Inputs-----------------------------------*/

input                    clock;            /* Clock                     */
input [`DataBusSize-1:0] ReadBusInput;     /* Read Bus for Input SRAM   */
input                    reset;            /* Reset                     */
input [1:0]              Control;          /* Input from control block  */

/*------------------------------Outputs----------------------------------*/

output  [`AddressSize-1:0] ReadAddressInput;      /* Read Address Bus for Input SRAM    */    
output  [`AddressSize-1:0] WriteAddressScratch;   /* Write Address Bus for Scratch SRAM */
output  [`DataBusSize-1:0] WriteBusScratch;       /* Write Bus for Scratch SRAM         */
output                     WriteEnableScratch;    /* Write Enable line for Scratch SRAM */
output                     flag;                  /* Completion state flag to Control   */     


/*-------------------------Nets and Registers-----------------------------*/

reg                    Clear;                               /* Internal Clear Flag                  */
reg                    Stop;
reg                    Pipelined;
reg                    PipelineStart;

reg [18:0]             PixelCount_State_1;
reg [7:0]              PixelValueRegister [0:15];           /* Temporary Pixel's Value              */
reg [`DataBusSize-1:0] TempWriteBusScratch;                 /* Temporary Write Bus for Scratch SRAM */
reg [8:0]              RegCounterBlock;                     /* Current Counter's Value              */


reg [1:0]              State;                               /* Current State                        */ 
reg [1:0]              Next_State;                          /* Next State                           */
reg [4:0]              Pipelined_State;
reg [4:0]              Pipelined_NextState;  

reg [1:0]              PixelInc_State;                      /* Pixel Count Increment Flag           */   
reg [4:0]              PixelVal_State;                      /* Pixel Value Store Flag               */ 
reg                    PixelCntFlag;                        /* Pixel Value Counter Flag             */      
reg [4:0]              PixelCounter [0:NumPixelVals];       /* Counter for Pixel Values             */
reg [18:0]             PixelCounterReg [0:NumPixelVals];    /* Counter Flip-Flop for Pixel Values   */
reg                    PixelRegFlag;


reg                    CountWrite;                          /* Write Counter Flag                   */
reg [NumPixelVals:0]   CounterBuff [0:`AddressSize-1];      /* Temp Counter Buffer from Decoder output*/
reg                    InputAddressFlag;

reg                    PixelCntReset;
reg                    BlockFlag;

reg                    Completeflag;
reg [4:0]              Completeflag_State;
reg                    Completeflag_Final;

reg [`AddressSize-1:0] ReadAddressInput;                     /* Read Address Bus for Input SRAM    */   
reg [`AddressSize-1:0] WriteAddressScratch;                  /* Write Address Bus for Scratch SRAM */
reg [`DataBusSize-1:0] WriteBusScratch;                      /* Write Bus for Scratch SRAM         */
reg                    WriteEnableScratch;                   /* Write Enable line for Scratch SRAM */
reg                    flag;                                 /* Completion state flag to Control   */     

/*----------------------------Wires---------------------------------------*/


integer j;



/*=============================Functions==================================*/

function [15:0] decoder4to16;
input [3:0] value; 
    casex (value)
      4'h0 : decoder4to16 = 16'h0001;
      4'h1 : decoder4to16 = 16'h0002;
      4'h2 : decoder4to16 = 16'h0004;
      4'h3 : decoder4to16 = 16'h0008;
      4'h4 : decoder4to16 = 16'h0010;
      4'h5 : decoder4to16 = 16'h0020;
      4'h6 : decoder4to16 = 16'h0040;
      4'h7 : decoder4to16 = 16'h0080;
      4'h8 : decoder4to16 = 16'h0100;
      4'h9 : decoder4to16 = 16'h0200;
      4'hA : decoder4to16 = 16'h0400;
      4'hB : decoder4to16 = 16'h0800;
      4'hC : decoder4to16 = 16'h1000;
      4'hD : decoder4to16 = 16'h2000;
      4'hE : decoder4to16 = 16'h4000;
      4'hF : decoder4to16 = 16'h8000;
    endcase
endfunction

function [NumPixelVals:0] decoder_out;   // double the speed of shift register decoder
input [7:0] value;                   // 8 to 256 decoder
begin
    casex (value[7:4])
      4'h0 : decoder_out = decoder4to16(value[3:0]);
      4'h1 : decoder_out = {decoder4to16(value[3:0]),16'b0};
      4'h2 : decoder_out = {decoder4to16(value[3:0]),32'h0};
      4'h3 : decoder_out = {decoder4to16(value[3:0]),48'h0};
      4'h4 : decoder_out = {decoder4to16(value[3:0]),64'h0};
      4'h5 : decoder_out = {decoder4to16(value[3:0]),80'h0};
      4'h6 : decoder_out = {decoder4to16(value[3:0]),96'h0};
      4'h7 : decoder_out = {decoder4to16(value[3:0]),112'h0};
      4'h8 : decoder_out = {decoder4to16(value[3:0]),128'h0};
      4'h9 : decoder_out = {decoder4to16(value[3:0]),144'h0};
      4'hA : decoder_out = {decoder4to16(value[3:0]),160'h0};
      4'hB : decoder_out = {decoder4to16(value[3:0]),176'h0};
      4'hC : decoder_out = {decoder4to16(value[3:0]),192'h0};
      4'hD : decoder_out = {decoder4to16(value[3:0]),208'h0};
      4'hE : decoder_out = {decoder4to16(value[3:0]),224'h0};
      4'hF : decoder_out = {decoder4to16(value[3:0]),240'h0};
    endcase
end
endfunction




/*=============================Flip-Flops=================================*/


/*-------------------------------State------------------------------------*/
always@(posedge clock)
begin
    casex({reset,Control[0],Stop})
        3'b1xx:   
             State <= State0;
        3'b0x1:
             State <= State0;
        3'b010:
             State <= Next_State;
    endcase
end

/*----------------------- Pipelined Reset State------------------------------------*/

always@(posedge clock)
begin
    casex({reset,Control[0],Stop})
        3'b1xx:   
             Pipelined_State <= p_State0;
        3'b0x1:
             Pipelined_State <= p_State0;
        3'b010:
             Pipelined_State <= Pipelined_NextState;
    endcase
end


/*---------------------- Store Current Pixel Value-----------------------*/    

  always @ (posedge clock)
  begin
    casex({reset,Clear})
      2'b00:
      begin
        casex(PixelVal_State[2])
            1'b1:
                begin
                PixelValueRegister[0] <= ReadBusInput[7:0];
                PixelValueRegister[1] <= ReadBusInput[15:8];
                PixelValueRegister[2] <= ReadBusInput[23:16];
                PixelValueRegister[3] <= ReadBusInput[31:24];
                PixelValueRegister[4] <= ReadBusInput[39:32];
                PixelValueRegister[5] <= ReadBusInput[47:40];
                PixelValueRegister[6] <= ReadBusInput[55:48];
                PixelValueRegister[7] <= ReadBusInput[63:56];
                PixelValueRegister[8] <= ReadBusInput[71:64];
                PixelValueRegister[9] <= ReadBusInput[79:72];
                PixelValueRegister[10] <= ReadBusInput[87:80];
                PixelValueRegister[11] <= ReadBusInput[95:88];
                PixelValueRegister[12] <= ReadBusInput[103:96];
                PixelValueRegister[13] <= ReadBusInput[111:104];
                PixelValueRegister[14] <= ReadBusInput[119:112];
                PixelValueRegister[15] <= ReadBusInput[127:120];
              end
        endcase
      end
      default:
        begin
        for(j=0; j<16; j=j+1) 
            PixelValueRegister[j] <= 8'b0;
        end
    endcase
end


/*-------------------- Store Pixel Count-------------------------------*/

always@(posedge clock)
begin
  casex({reset,Clear})
    2'b00:
      casex(PixelInc_State[1])
        1'b1: PixelCount_State_1 <= PixelCount_State_1 + 1'b1;
      endcase
    default: PixelCount_State_1  <= 19'b0;
  endcase
end

/*------------------ Store Temp Count Value --------------------------*/
genvar i;
generate
for(i=0;i<(NumPixelVals+1);i=i+1) begin: counter_val_assign
  always@(posedge clock)
  begin
    casex({reset,Clear})
      2'b00:
        casex({PixelCntFlag})
          1'b1:
            begin
            if(PixelCounter[i] != 0)
                begin
                     PixelCounterReg[i] <= PixelCounterReg[i] + PixelCounter[i];
                end
            end
          endcase
    default: 
    begin
    PixelCounterReg[i]  <= 19'b0;
    end
  endcase
  end
end
endgenerate


/*----------------Store Counter Block Value-----------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex({BlockFlag})
        1'b1: 
        begin
          RegCounterBlock <= RegCounterBlock  + 3'b100 ;
        end
    endcase
    default:
    begin
        RegCounterBlock <= 9'b0;
    end
endcase
end

/*----------------Write to ReadAddressInput-----------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex({InputAddressFlag})
        1'b1: ReadAddressInput  <= PixelCount_State_1 + {Control[1],ImageBaseAddress};
    endcase
    default:
    begin
        ReadAddressInput <= 8'b0;
    end
endcase
end

/*----------------Start Pipeline-----------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    PipelineStart <= Pipelined;
    default:
    begin
    PipelineStart <= 1'b0;
    end
endcase
end


/*----------------Pipeline Registers-----------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    begin
        casex(Pipelined_NextState[2])
            1'b1:
            begin
                Completeflag_State[2] <= Completeflag_State[1];
            end       
        endcase
        casex(Pipelined_NextState[3])
            1'b1:
            begin
                Completeflag_State[3] <= Completeflag_State[2];
            end       
        endcase
        casex(Pipelined_NextState[4])
            1'b1:
            begin
                Completeflag_State[4] <= Completeflag_State[3];
            end       
        endcase
    end
    default:
        begin
            for(j=2;j<`NumStates;j=j+1)
            begin
                Completeflag_State[j]    <= 1'b0;
            end
        end
endcase
end

/*---------------------- Write to RAM ------------------------------*/

always@(posedge clock)
begin
  casex({reset,Clear})
    2'b00:
      casex({CountWrite})
        1'b1:
        begin
            WriteAddressScratch  <=  {10'b0,(RegCounterBlock>>2)} + {Control[1],CountBaseAddress};
            WriteBusScratch      <=  TempWriteBusScratch;
            WriteEnableScratch   <=  1'b1;
        end
        1'b0: WriteEnableScratch     <=  1'b0;
      endcase
    default: WriteEnableScratch     <=  1'b0;
  endcase
end


/*----------------Completion Flag-----------------------*/

always@(posedge clock)
begin
casex(reset)
1'b0:
casex({Clear,Control[0]})
    2'b01:
    begin
    flag <= Completeflag_Final;
    Stop <= Completeflag_Final;
    end
    default:
    begin
    Stop <= 1'b0;
    flag <= 1'b0;
    end
endcase
1'b1:
begin
    flag <= 1'b0;
    Stop <= 1'b0;
end
endcase
end

generate
for(i=0;i<NumPixelVals+1;i=i+1) begin : pixel_counter_calc
always@(posedge clock)
  begin
    casex(PixelRegFlag)
    1'b1:
      {PixelCounter[i][4],PixelCounter[i][3:0]} <= (((CounterBuff[1][i]   + CounterBuff[0][i])   +
                                                    (CounterBuff[3][i]   + CounterBuff[2][i]))  +
                                                   ((CounterBuff[5][i]   + CounterBuff[4][i])   +
                                                    (CounterBuff[7][i]   + CounterBuff[6][i]))) +
                                                  (((CounterBuff[9][i]   + CounterBuff[8][i])   +
                                                    (CounterBuff[11][i]  + CounterBuff[10][i])) +
                                                   ((CounterBuff[13][i]  + CounterBuff[12][i])  +
                                                    (CounterBuff[15][i]  + CounterBuff[14][i])));
    1'b0:
      {PixelCounter[i][4],PixelCounter[i][3:0]} <= 5'b0;
  endcase
  end  
end
endgenerate



/*=========================Combinational Logic============================*/


/*--------------------------PixelCounter Calc-----------------------------*/




always@(*)
  begin
    CounterBuff[0]  = decoder_out(PixelValueRegister[0] );
    CounterBuff[1]  = decoder_out(PixelValueRegister[1] );
    CounterBuff[2]  = decoder_out(PixelValueRegister[2] );
    CounterBuff[3]  = decoder_out(PixelValueRegister[3] );
    CounterBuff[4]  = decoder_out(PixelValueRegister[4] );
    CounterBuff[5]  = decoder_out(PixelValueRegister[5] );
    CounterBuff[6]  = decoder_out(PixelValueRegister[6] );
    CounterBuff[7]  = decoder_out(PixelValueRegister[7] );
    CounterBuff[8]  = decoder_out(PixelValueRegister[8] );
    CounterBuff[9]  = decoder_out(PixelValueRegister[9] );
    CounterBuff[10] = decoder_out(PixelValueRegister[10]);
    CounterBuff[11] = decoder_out(PixelValueRegister[11]);
    CounterBuff[12] = decoder_out(PixelValueRegister[12]);
    CounterBuff[13] = decoder_out(PixelValueRegister[13]);
    CounterBuff[14] = decoder_out(PixelValueRegister[14]);
    CounterBuff[15] = decoder_out(PixelValueRegister[15]);
  end 
/*-----------------------Pipelined FSM-----------------------------------*/


/*----------------------------State 0-----------------------------------*/
always@(*)
begin
Pipelined_NextState[0] = 1'b1;
    casex(Pipelined_State[0])
        1'b1:
            begin 
            $display("Pipelined_State 0");
            casex(PipelineStart)
                1'b1:
                begin
                    Pipelined_NextState[1] = 1'b1;
                end
                default :
                begin
                    Pipelined_NextState[1] = 1'b0;
                end
            endcase
            end
        1'b0:
        begin
            Pipelined_NextState[1] =1'b0;
        end
    endcase
end 


/*----------------------------State 1-----------------------------------*/

always@(*) 
begin
    casex(Pipelined_State[1])
        1'b1:
            begin
             $display("Pipelined_State 1");
            if(PixelCount_State_1 != NumberofPixels)
            begin
                PixelInc_State[1]       = 1'b1;
                InputAddressFlag        = 1'b1;
                Pipelined_NextState[2]  = 1'b1;              
                Completeflag_State[1]   = 1'b0;
            end
            else 
            begin
                InputAddressFlag        = 1'b0;
                PixelInc_State[1]       = 1'b0;
                Completeflag_State[1]   = 1'b1;
                Pipelined_NextState[2]  = 1'b1;     
            end
           end
        default:
            begin
                InputAddressFlag        = 1'b0;
                PixelInc_State[1]       = 1'b0;
                Completeflag_State[1]   = 1'b0;
                Pipelined_NextState[2]  = 1'b0;
            end
    endcase
end

/*----------------------------State 2-----------------------------------*/

always@(*)
begin
    casex(Pipelined_State[2])
        1'b1:
            begin
            $display("Pipelined_State 2");
            casex(Completeflag_State[2])
            1'b0:
            begin
                PixelVal_State[2]    = 1'b1;
            end
            1'b1:
                PixelVal_State[2]    = 1'b0;
            endcase
            Pipelined_NextState[3] = 1'b1;
            end
        default:
            begin
                PixelVal_State[2]      = 1'b0;
                Pipelined_NextState[3] = 1'b0;
            end
    endcase
end

/*----------------------------State 3-----------------------------------*/
always@(*)
begin
    casex(Pipelined_State[3])
        1'b1:
            begin
            $display("Pipelined_State 2");
            casex(Completeflag_State[2])
            1'b0:
            begin
                PixelRegFlag   = 1'b1;
            end
            1'b1:
                PixelRegFlag    = 1'b0;
            endcase
            Pipelined_NextState[4] = 1'b1;
            end
        default:
            begin
                PixelRegFlag           = 1'b0;
                Pipelined_NextState[4] = 1'b0;
            end
    endcase
end

/*----------------------------State 4-----------------------------------*/

always@(*)
begin
casex(Pipelined_State[4])
    1'b1:
        begin
        $display("Pipelined_State 3");
        casex(Completeflag_State[4])
        1'b0:
            begin
                Completeflag = 1'b0;
                PixelCntFlag = 1'b1;       
            end
        1'b1:
        begin
            Completeflag = 1'b1;
            PixelCntFlag = 1'b0;  
        end
        endcase
        end
    default:
        begin
            Completeflag = 1'b0;
            PixelCntFlag = 1'b0;  
        end
endcase
end


/*---------------------------------FSM-----------------------------------*/

always@(*)             
                                
begin
Clear               = 1'b0;
CountWrite          = 1'b0;
BlockFlag           = 1'b0;
TempWriteBusScratch = 128'b0;
Next_State          = State0;
Completeflag_Final = 1'b0;
Pipelined           = 1'b0; 
casex(State)
/*-------------------------------State 0-----------------------------------*/
    State0:
    begin
        casex(Control[0])
            1'b1:
            begin 
                Clear       = 1'b1;
                Next_State  = State1;
            end
            default :
            begin
                Next_State = State0;
            end
        endcase
    end
/*-------------------------------State 1------------------------------------*/
    State1:
    begin  
    if(Completeflag)
    begin
        Pipelined  = 1'b0;
        Next_State = State2;
    end
    else 
    begin
      Pipelined  = 1'b1;
      Next_State = State1;
    end   
    end    
/*-------------------------------State 7------------------------------------*/
    State2:
      begin
        if((RegCounterBlock) != (NumPixelVals+1))
        begin
          TempWriteBusScratch[127:96]  =  {13'b0,(PixelCounterReg[RegCounterBlock+3])};
          TempWriteBusScratch[95:64]   =  {13'b0,(PixelCounterReg[RegCounterBlock+2])};
          TempWriteBusScratch[63:32]   =  {13'b0,(PixelCounterReg[RegCounterBlock+1])};
          TempWriteBusScratch[31:0]    =  {13'b0,(PixelCounterReg[RegCounterBlock])}; 
          CountWrite     = 1'b1;
          BlockFlag      = 1'b1; 
          Next_State     = State3;
          Completeflag_Final = 1'b0;
        end
        else begin
          CountWrite         = 1'b1;
          Next_State         = State0;
          BlockFlag          = 1'b0;
          Completeflag_Final = 1'b1;
        end
      end
     
/*-------------------------------State 3-----------------------------------*/
    State3:
    begin
        Next_State     = State2;
    end
endcase
end
endmodule



