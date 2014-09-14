/*************************************
*
* NAME:  Equalizer
*
* DESCRIPTION:
*  Equalizer
*
* NOTES:
*
* REVISION HISTORY*
*  Revision     Date       Programmer    Description
*  4.0          04/03/2014  SK15,DN     With Pipelined FSM 
*                                        Considering 16 pixel read
*M*****************************************/
`define AddressSize 16
`define AddressSizeMinusOne 15
`define DataBusSize 127
`define NumStates   10 
`define Shift       28  


/*=============================Declarations===============================*/




module Equalizer #(
/*-----------------------------Parameters---------------------------------*/

parameter [`AddressSize-2:0]       EquBaseAddress     = 0,                         /* Starting address for Image             */
parameter [`AddressSize-2:0]       CountBaseAddress   = 0,                         /* Starting address for Counters          */
parameter [`NumStates:0]           p_State0           = `NumStates'b0000000001,      /* Known Reset State                      */
parameter                          NumCounterVals     = 256,                       /* Number of Values a Pixel can take: 2^8 */
parameter                          L                  = 8'd255,
parameter                          NxM                = 32'd307200,
parameter [3:0]                    State0             = 4'b0000,                     /* State 0 */
parameter [3:0]                    State1             = 4'b0001,                     /* State 1 */
parameter [3:0]                    State2             = 4'b0011,                     /* State 2 */
parameter [3:0]                    State3             = 4'b0010,                     /* State 3 */
parameter [3:0]                    State4             = 4'b0110,                     /* State 4 */
parameter [3:0]                    State5             = 4'b0100,                     /* State 5 */
parameter [3:0]                    State6             = 4'b0101,                     /* State 6 */
parameter [3:0]                    State7             = 4'b0111,                     /* State 7 */
parameter [3:0]                    State8             = 4'b1111,
parameter [3:0]                    State9             = 4'b1110,
parameter [3:0]                    State10            = 4'b1100
)                   

(clock, reset, Control, ReadBusScratch1, Mul_product_0, Mul_product_1, Mul_product_2, Mul_product_3, Div_quotient, 
                ReadAddressScratch1, WriteAddressScratch2,WriteBusScratch2,WriteEnableScratch2,flag, Dividend, Divisor,
                Multiplicant_1_0, Multiplicant_1_1, Multiplicant_1_2, Multiplicant_1_3,
                Multiplicant_2_0, Multiplicant_2_1, Multiplicant_2_2, Multiplicant_2_3);

/*-------------------------------Inputs-----------------------------------*/

input                    clock;             /* clock                     */
input [`DataBusSize:0]   ReadBusScratch1;   /* Read Bus for Scratch SRAM */
input                    reset;             /* reset                     */
input [1:0]              Control;           /* Input from control block  */
input [(`Shift+8+31):0]  Mul_product_0;
input [(`Shift+8+31):0]  Mul_product_1;
input [(`Shift+8+31):0]  Mul_product_2;
input [(`Shift+8+31):0]  Mul_product_3;
input [`Shift+7:0]       Div_quotient;
                      
/*------------------------------Outputs----------------------------------*/


output [`AddressSizeMinusOne:0] ReadAddressScratch1;    /* Read Address Bus for Scratch SRAM  */    
output [`AddressSizeMinusOne:0] WriteAddressScratch2;   /* Write Address Bus for Scratch SRAM */
output [`DataBusSize:0]         WriteBusScratch2;       /* Write Bus for Scratch SRAM         */
output                          WriteEnableScratch2;    /* Write Enable line for Scratch SRAM */ 
output                          flag; 
output [`Shift+7:0]             Dividend;
output [31:0]                   Divisor;
output [31:0]                   Multiplicant_1_0;
output [31:0]                   Multiplicant_1_1;
output [31:0]                   Multiplicant_1_2;
output [31:0]                   Multiplicant_1_3;
output [`Shift+7:0]             Multiplicant_2_0;
output [`Shift+7:0]             Multiplicant_2_1;
output [`Shift+7:0]             Multiplicant_2_2;
output [`Shift+7:0]             Multiplicant_2_3;

 
/*-------------------------Nets and Registers-----------------------------*/

reg                   Clear;                                     /* Internal Clear Flag                  */
reg                   Stop;
reg                   Completeflag;
reg                   Completeflag_State[0:`NumStates];


reg [6:0]             BucketCount;
reg [6:0]             BucketCount_State[0:`NumStates];            /* Counter up to Total Number of Buckets*/
reg [`NumStates:0]    BucketInc_State;
reg                   BucketInc;
reg                   BucketIncReg;
reg                   BucketReset;

reg [31:0]            EquValue0_State [0:`NumStates]; 
reg [31:0]            EquValue1_State [0:`NumStates]; 
reg [31:0]            EquValue2_State [0:`NumStates]; 
reg [31:0]            EquValue3_State [0:`NumStates];
reg                   StoreEquFlag;
   
reg                   WriteEqu;
reg                   WriteEquFinal;
reg                   TempWriteEquFlag;

reg [31:0]            CDFPrev;
reg [7:0]             CDFMinPos;  
reg [31:0]            CDF0_State [0:`NumStates];
reg [31:0]            CDF1_State [0:`NumStates];
reg [31:0]            CDF2_State [0:`NumStates];
reg [31:0]            CDF3_State [0:`NumStates];
reg                   StoreCDF_State [0:`NumStates];                  
reg [3:0]             CDFMinFlag;                                /* CDFmin found Flag  */

/*Count Register*/
reg [32:0]            CountRegister_0_State[0:`NumStates];  
reg [32:0]            CountRegister_1_State[0:`NumStates];        
reg [32:0]            CountRegister_2_State[0:`NumStates];
reg [32:0]            CountRegister_3_State[0:`NumStates];
reg [32:0]            CountRegister[0:3];
reg [`NumStates:0]    CountStore_State;

reg [3:0]             State;                                     /* Current State                        */ 
reg [3:0]             Next_State;                                /* Next State                           */
reg [`NumStates:0]    Pipelined_State;                           /* Pipelined States                     */
reg [`NumStates:0]    Pipelined_NextState;                       /* Pipelined Next States                */

reg [`Shift+7:0]      Constant; 
reg [31:0]            Const_CDFMin;
reg                   ConstCalcFlag;
reg                   ConstDivFlag;
reg                   ConstStoreFlag;

reg                   Pipelined;           
reg                   PipelineStart;                        /* Start The Pipeline                   */ 
reg                   CountStore;                           /* Pixel Value Counter Flag             */       


reg [`DataBusSize:0]   TempWriteBusScratch2;                /* Temporary Write Bus for Scratch2 SRAM*/
reg                    Scratch1AddressFlag;
reg                    Scratch1AddressFlagReg;
reg [`AddressSize-1:0] ReadAddressScratch1;                 /* Read Address Bus for Scratch SRAM  */    
reg [`AddressSize-1:0] WriteAddressScratch2;                /* Write Address Bus for Scratch SRAM */
reg [`DataBusSize:0]   WriteBusScratch2;                    /* Write Bus for Scratch SRAM         */
reg                    WriteEnableScratch2;                 /* Write Enable line for Scratch SRAM */

reg                           CalculateMulFlag;
reg  [3:0]                    CalculateCDFFlag;
wire [4:0]                    Mul_Seq_Flag;

wire                          Div_Seq_Flag;
reg [`Shift+7:0]              Dividend;
reg [31:0]                    Divisor;
reg [31:0]                    Multiplicant_1_0;
reg [31:0]                    Multiplicant_1_1;
reg [31:0]                    Multiplicant_1_2;
reg [31:0]                    Multiplicant_1_3;
reg [`Shift+7:0]              Multiplicant_2_0;
reg [`Shift+7:0]              Multiplicant_2_1;
reg [`Shift+7:0]              Multiplicant_2_2;
reg [`Shift+7:0]              Multiplicant_2_3;
reg                           flag;                                 /* Completion state flag to Control   */ 
 
/*----------------------------Wires---------------------------------------*/


/*---------------------------Integer---------------------------------------*/
integer i;

/*-------------------------Modules----------------------------------------*/



/*=============================Functions==================================*/
task constant_mul;
input [31:0] CDFMin;
begin
    Const_CDFMin      = CDFMin;
    Dividend          = (L)<<`Shift;
    Divisor           = (NxM - CDFMin);
end
endtask

/*=============================Flip-Flops=================================*/


/*-------------------------------State------------------------------------*/
always@(posedge clock)
begin
    casex({reset,Control[0],Stop})
        3'b1xx:   
             State <= State0;
        3'b0x1:
             State <= State0;
        3'b001:
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
        3'b001:
             Pipelined_State <= p_State0;
        3'b010:
             Pipelined_State <= Pipelined_NextState;
    endcase
end


always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex(CalculateCDFFlag)
        1'b1:
        begin
            CDF0_State[4] <=  CountRegister_0_State[3] + CDFPrev;
            CDF1_State[4] <=  CountRegister_0_State[3] + CDFPrev + CountRegister_1_State[3];
            CDF2_State[4] <=  CountRegister_0_State[3] + CountRegister_1_State[3] + CDFPrev + CountRegister_2_State[3];
            CDF3_State[4] <=  CountRegister_0_State[3] + CountRegister_1_State[3] + CDFPrev + CountRegister_2_State[3] + CountRegister_3_State[3];
            CDFPrev       <=  CountRegister_0_State[3] + CountRegister_1_State[3] + CDFPrev + CountRegister_2_State[3] + CountRegister_3_State[3];
        end
    endcase
    default:
        begin
            CDF0_State[4] <= 32'b0;
            CDF1_State[4] <= 32'b0;
            CDF2_State[4] <= 32'b0;
            CDF3_State[4] <= 32'b0;
            CDFPrev       <= 32'b0;
        end
endcase
end



/*---------------------- Store Current Counter Values-----------------------*/    

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    begin
        casex({CountStore,CountStore_State[3]})
            2'b10:
                begin
                    CountRegister[0] <= ReadBusScratch1[31:0];
                    CountRegister[1] <= ReadBusScratch1[63:32];
                    CountRegister[2] <= ReadBusScratch1[95:64];
                    CountRegister[3] <= ReadBusScratch1[127:96];
                end                
            2'b01:
                begin
                    CountRegister_0_State[3] <= ReadBusScratch1[31:0];
                    CountRegister_1_State[3] <= ReadBusScratch1[63:32];
                    CountRegister_2_State[3] <= ReadBusScratch1[95:64];
                    CountRegister_3_State[3] <= ReadBusScratch1[127:96];
                end
        endcase
    end
    default:
    begin
        for(i=0;i<4;i=i+1)
            CountRegister[i] <= 32'b0;
        CountRegister_0_State[3] <= 32'b0;
        CountRegister_1_State[3] <= 32'b0;
        CountRegister_2_State[3] <= 32'b0;
        CountRegister_3_State[3] <= 32'b0;
    end
endcase
end



/*---------------------- Store State Registers---------------------------*/
always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    begin
        casex(Pipelined_NextState[3])
            1'b1:
            begin
                BucketCount_State[3]  <= BucketCount_State[1];
                Completeflag_State[3] <= Completeflag_State[1];
            end       
        endcase
        casex(Pipelined_NextState[4])
            1'b1:
            begin
                BucketCount_State[4]     <= BucketCount_State[3];
                CountRegister_0_State[4] <= CountRegister_0_State[3];
                CountRegister_1_State[4] <= CountRegister_1_State[3];
                CountRegister_2_State[4] <= CountRegister_2_State[3];
                CountRegister_3_State[4] <= CountRegister_3_State[3];
                Completeflag_State[4]    <= Completeflag_State[3];
            end       
        endcase
        casex(Pipelined_NextState[5])
            1'b1:
            begin
                BucketCount_State[5]     <= BucketCount_State[4];
                CDF0_State [5]           <= CDF0_State[4];
                CDF1_State [5]           <= CDF1_State[4];
                CDF2_State [5]           <= CDF2_State[4];
                CDF3_State [5]           <= CDF3_State[4];
                Completeflag_State[5]    <= Completeflag_State[4];
            end       
        endcase
        casex(Pipelined_NextState[6])
            1'b1:
            begin
                BucketCount_State[6]  <= BucketCount_State[5];
                Completeflag_State[6] <= Completeflag_State[5];
            end       
        endcase
        casex(Pipelined_NextState[7])
            1'b1:
            begin
                BucketCount_State[7]  <= BucketCount_State[6];
                Completeflag_State[7] <= Completeflag_State[6];
            end       
        endcase
        casex(Pipelined_NextState[8])
            1'b1:
            begin
                BucketCount_State[8]  <=  BucketCount_State[7];
                Completeflag_State[8] <= Completeflag_State[7];
            end       
        endcase
        casex(Pipelined_NextState[9])
            1'b1:
            begin
                BucketCount_State[9]  <= BucketCount_State[8];
                Completeflag_State[9] <= Completeflag_State[8];
            end       
        endcase
        casex(Pipelined_NextState[10])
            1'b1: 
            begin 
                BucketCount_State [10]    <= BucketCount_State [9];
                EquValue0_State   [10]    <= EquValue0_State   [9];
                EquValue1_State   [10]    <= EquValue1_State   [9];
                EquValue2_State   [10]    <= EquValue2_State   [9];
                EquValue3_State   [10]    <= EquValue3_State   [9];
                Completeflag_State[10]    <= Completeflag_State[9];
            end       
        endcase
    end
    default:
        begin
            for(i=2;i<10;i=i+1)
            begin
                BucketCount_State[i]     <= 8'b0;
                Completeflag_State[i]    <= 1'b0;
            end
            CDF0_State[5]            <= 32'b0;
            CDF1_State[5]            <= 32'b0;
            CDF2_State[5]            <= 32'b0;
            CDF3_State[5]            <= 32'b0;
            EquValue0_State[10]      <= 32'b0;
            EquValue1_State[10]      <= 32'b0;
            EquValue2_State[10]      <= 32'b0;
            EquValue3_State[10]      <= 32'b0;
            CountRegister_0_State[4] <= 32'b0;
            CountRegister_1_State[4] <= 32'b0;
            CountRegister_2_State[4] <= 32'b0;
            CountRegister_3_State[4] <= 32'b0;
            
        end
endcase
end


/*-------------------- Modify Bucket Count-------------------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    begin
    casex({BucketInc})
        1'b1:
            BucketCount <= BucketCount + 1'b1;
    endcase
    casex(BucketInc_State[1])
        1'b1:
            BucketCount_State[1] <= BucketCount_State[1] + 1'b1;
    endcase
    end
    default:
    begin
        BucketCount <= 6'b0;
        BucketCount_State[1] <= 6'b0;
    end
endcase
end

/*-------------------- Multiplier -------------------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex(CalculateMulFlag)
        1'b1:
        begin
            if(CDF0_State[4]!=0)
                Multiplicant_1_0   <= CDF0_State[4]-Const_CDFMin;
            else
                Multiplicant_1_0   <= 100'b0; 

            if(CDF1_State[4]!=0)
                Multiplicant_1_1   <= CDF1_State[4]-Const_CDFMin;
            else
                Multiplicant_1_1   <= 100'b0;

            if(CDF2_State[4]!=0)
                Multiplicant_1_2   <= CDF2_State[4]-Const_CDFMin;
            else
                Multiplicant_1_2   <= 100'b0;

            if(CDF3_State[4]!=0)
                Multiplicant_1_3   <= CDF3_State[4]-Const_CDFMin;
            else
                Multiplicant_1_3   <= 100'b0;

          Multiplicant_2_0 <= Constant;
          Multiplicant_2_1 <= Constant;
          Multiplicant_2_2 <= Constant;
          Multiplicant_2_3 <= Constant;
        end
        1'b0:
        begin
            Multiplicant_1_0 <= 100'b0;
            Multiplicant_1_1 <= 100'b0;
            Multiplicant_1_2 <= 100'b0;
            Multiplicant_1_3 <= 100'b0;
            Multiplicant_2_0 <= 100'b0;
            Multiplicant_2_1 <= 100'b0;
            Multiplicant_2_2 <= 100'b0;
            Multiplicant_2_3 <= 100'b0;
        end 
    endcase
    default:
    begin
    Multiplicant_1_0 <= 100'b0;
    Multiplicant_1_1 <= 100'b0;
    Multiplicant_1_2 <= 100'b0;
    Multiplicant_1_3 <= 100'b0;
    Multiplicant_2_0 <= 100'b0;
    Multiplicant_2_1 <= 100'b0;
    Multiplicant_2_2 <= 100'b0;
    Multiplicant_2_3 <= 100'b0;   
    end    
endcase
end

/*----------------------Equalized Values------------------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex(StoreEquFlag)
        1'b1:
        begin
            EquValue0_State[9]   <= (Mul_product_0)>>`Shift;
            EquValue1_State[9]   <= (Mul_product_1)>>`Shift;
            EquValue2_State[9]   <= (Mul_product_2)>>`Shift;
            EquValue3_State[9]   <= (Mul_product_3)>>`Shift;
        end
    endcase 
    default:
    begin 
        EquValue0_State[9] <= 32'b0;
        EquValue1_State[9] <= 32'b0;
        EquValue2_State[9] <= 32'b0;
        EquValue3_State[9] <= 32'b0;
    end    
endcase
end

/*------------------ Calculate Constant Value --------------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
        casex(ConstCalcFlag)
            1'b1:
                begin
                    casex(CDFMinFlag)
                        4'bxxx1:
                            begin   
                                 constant_mul(CountRegister[0]);
                                 CDFMinPos <= {BucketCount-1'b1,2'b00};
                            end
                        4'bxx10:
                            begin
                                 constant_mul(CountRegister[1]);
                                 CDFMinPos <= {BucketCount-1'b1,2'b01}; 
                            end
                        4'bx100:
                            begin
                                constant_mul(CountRegister[2]);
                                CDFMinPos <= {BucketCount-1'b1,2'b10};  
                            end
                        4'b1000:
                            begin
                                constant_mul(CountRegister[3]); 
                                CDFMinPos <= {BucketCount-1'b1,2'b11};
                            end
                    endcase
                end
        endcase
    default:
    begin
        CDFMinPos <= 8'b0;
    end    
endcase
end


/*------------------Store Const values ------------------------*/
always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex({ConstDivFlag})
        1'b1:
        begin
            Constant <= (Div_quotient+1'b1);
        end
    endcase
    default:
    begin
        Constant      <=  100'b0;
    end
endcase
end

/*----------------Write to ReadAddressScratch1-----------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex({Scratch1AddressFlag,Scratch1AddressFlagReg})
        2'b10: ReadAddressScratch1 <= BucketCount          + {Control[1],CountBaseAddress};
        2'b01: ReadAddressScratch1 <= BucketCount_State[1] + {Control[1],CountBaseAddress};
    endcase
    default:
    begin
        ReadAddressScratch1 <= 16'b0;
    end
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
    flag <= Completeflag;
    Stop <= Completeflag;
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

/*------------------ Temp Write Equ value ------------------------*/

always@(posedge clock)
begin
casex({reset,Clear})
    2'b00:
    casex({TempWriteEquFlag})
    1'b1:
            begin
             casex(BucketCount_State[10][1:0])
             2'b00:
                begin
                    TempWriteBusScratch2[7: 0]  <= EquValue0_State[9];
                    TempWriteBusScratch2[15:8]  <= EquValue1_State[9];
                    TempWriteBusScratch2[23:16] <= EquValue2_State[9];
                    TempWriteBusScratch2[31:24] <= EquValue3_State[9];
                    WriteEquFinal <= 1'b0;
                end
             2'b01:
                begin
                    TempWriteBusScratch2[39:32] <= EquValue0_State[9];
                    TempWriteBusScratch2[47:40] <= EquValue1_State[9];
                    TempWriteBusScratch2[55:48] <= EquValue2_State[9];
                    TempWriteBusScratch2[63:56] <= EquValue3_State[9];
                    WriteEquFinal <= 1'b0;
                end
             2'b10:
                begin
                    TempWriteBusScratch2[71:64] <= EquValue0_State[9];
                    TempWriteBusScratch2[79:72] <= EquValue1_State[9];
                    TempWriteBusScratch2[87:80] <= EquValue2_State[9];
                    TempWriteBusScratch2[95:88] <= EquValue3_State[9];
                    WriteEquFinal <= 1'b0;
                end
             2'b11:
                begin
                    TempWriteBusScratch2[103:96]  <= EquValue0_State[9];
                    TempWriteBusScratch2[111:104] <= EquValue1_State[9];
                    TempWriteBusScratch2[119:112] <= EquValue2_State[9];
                    TempWriteBusScratch2[127:120] <= EquValue3_State[9];
                    WriteEquFinal                 <= 1'b1;
                end
             endcase
            end
    default:
        WriteEquFinal <= 1'b0;
    endcase
    default:
    begin
        TempWriteBusScratch2 <= 128'b0;
        WriteEquFinal <= 1'b1;
    end
endcase
end

/*------------------ Write Counter values ------------------------*/

always@(posedge clock)
begin
  casex({reset,Clear})
    2'b00:
      casex({WriteEquFinal})
        1'b1:
        begin
            WriteAddressScratch2  <=  ((BucketCount_State[10]>>2)-1'b1) + {Control[1],EquBaseAddress};
            WriteBusScratch2      <=  TempWriteBusScratch2;
            WriteEnableScratch2   <=  1'b1;
        end
        1'b0: WriteEnableScratch2     <=  1'b0;
      endcase
    default: WriteEnableScratch2     <=  1'b0;
  endcase
end


/*--------------------------Pipelined States-------------------------------*/

/*-------------------------------State 0-----------------------------------*/


always@(*)
begin
Pipelined_NextState[0] = 1'b1;
Pipelined_NextState[2] = 1'b0;
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
                    Pipelined_NextState[0] = 1'b0;
                end
            endcase
            end
        1'b0:
        begin
            Pipelined_NextState[1] =1'b0;
        end
    endcase
end 

/*-------------------------------State 1-----------------------------------*/

always@(*) 
begin
    casex(Pipelined_State[1])
        1'b1:
            begin
             $display("Pipelined_State 1");
            if(BucketCount_State[1] <= (NumCounterVals>>2))
            begin
                Scratch1AddressFlagReg  = 1'b1;
                BucketInc_State[1]      = 1'b1;
                Pipelined_NextState[3]  = 1'b1;               
                Completeflag_State[1]   = 1'b0;
            end
            else 
            begin
                Scratch1AddressFlagReg  = 1'b0;
                BucketInc_State[1]      = 1'b0;
                Completeflag_State[1]   = 1'b1;
                Pipelined_NextState[3]  = 1'b1;     
            end
           end
        default:
            begin
                Scratch1AddressFlagReg    = 1'b0;
                BucketInc_State[1]        = 1'b0;
                Pipelined_NextState[3]    = 1'b0;
                Completeflag_State[1]     = 1'b0;
            end
    endcase
end

/*-------------------------------State 2-----------------------------------*/


/*-------------------------------State 3-----------------------------------*/
always@(*)
begin
    casex(Pipelined_State[3])
        1'b1:
            begin
            $display("Pipelined_State 3");
            casex(Completeflag_State[3])
            1'b0:
            begin
                CountStore_State[3]    = 1'b1;
            end
            1'b1:
                CountStore_State[3]    = 1'b0;
            endcase
            Pipelined_NextState[4] = 1'b1;
            end
        default:
            begin
                CountStore_State[3]    = 1'b0;
                Pipelined_NextState[4] = 1'b0;
            end
    endcase
end

/*-------------------------------State 4-----------------------------------*/
always@(*)
begin
casex(Pipelined_State[4])
    1'b1:
        begin
        $display("Pipelined_State 4");
        casex(Completeflag_State[4])
        1'b0:
            begin
                CalculateCDFFlag = 1'b1;       
            end
        1'b1:
        begin
            CalculateCDFFlag = 1'b0;  
        end
        endcase
        Pipelined_NextState[5] = 1'b1;
        end
    default:
        begin
            CalculateCDFFlag = 1'b0;  
            Pipelined_NextState[5] = 1'b0;
        end
endcase
end

/*-------------------------------State 5-----------------------------------*/
always@(*)
begin
casex(Pipelined_State[5])
    1'b1:
        begin
        $display("Pipelined_State 5");
        casex(Completeflag_State[5])
        1'b0:
        begin
            CalculateMulFlag  = 1'b1;  
        end
        1'b1:
            CalculateMulFlag = 1'b0;
        endcase
        Pipelined_NextState[6] = 1'b1;
        end
    default:
        begin
            Pipelined_NextState[6] = 1'b0;
            CalculateMulFlag = 1'b0;
        end
endcase
end

/*-------------------------------State 6-----------------------------------*/
always@(*)
begin
    casex(Pipelined_State[6])
        1'b1:
            begin
                $display("Pipelined_State 6");
                Pipelined_NextState[7] = 1'b1;
            end
        default:
            begin
                Pipelined_NextState[7] = 1'b0;
            end
    endcase
end

/*-------------------------------State 7-----------------------------------*/
always@(*)
begin
    casex(Pipelined_State[7])
        1'b1:
            begin
                $display("Pipelined_State 7");
                Pipelined_NextState[8] = 1'b1;
            end
        default:
            begin
                Pipelined_NextState[8] = 1'b0;
            end
    endcase
end

/*-------------------------------State 8-----------------------------------*/
always@(*)
begin
    casex(Pipelined_State[8])
        1'b1:
            begin
                 $display("Pipelined_State 8");
                Pipelined_NextState[9] = 1'b1;
            end
        default:
            begin
                Pipelined_NextState[9] = 1'b0;
            end
    endcase
end


/*-------------------------------State 9-----------------------------------*/
always@(*)
begin
casex(Pipelined_State[9])
    1'b1:
        begin
        $display("Pipelined_State 9");
        casex(Completeflag_State[9])
        1'b0:
        begin
            StoreEquFlag  = 1'b1;  
        end
        1'b1:
            StoreEquFlag = 1'b0;
        endcase
        Pipelined_NextState[10] = 1'b1;
        end
    default:
        begin
            StoreEquFlag  = 1'b0;
            Pipelined_NextState[10] = 1'b0;
        end
endcase
end

/*-------------------------------State 10-----------------------------------*/
always@(*)
begin
casex(Pipelined_State[10])
    1'b1:
        begin
        $display("Pipelined_State 10");
        casex(Completeflag_State[10])
        1'b0:
        begin
            Completeflag      = 1'b0;
            TempWriteEquFlag  = 1'b1;
        end
        1'b1:
        begin
            Completeflag      = 1'b1;
            TempWriteEquFlag  = 1'b0;
        end
        endcase 
        end
    default:
        begin
            Completeflag      = 1'b0;
            TempWriteEquFlag  = 1'b0; 
        end
endcase
end


/*=========================Combinational Logic============================*/


/*--------------------------PixelCounter Calc-----------------------------*/





/*---------------------------------FSM-----------------------------------*/

always@(*)
begin
ConstCalcFlag  = 1'b0;
BucketInc      = 1'b0;
BucketReset    = 1'b0;
ConstDivFlag   = 1'b0;
Pipelined      = 1'b0;
CountStore     = 1'b0;
ConstStoreFlag = 1'b0;
Scratch1AddressFlag = 1'b0;
Clear          = 1'b0;
Next_State     = State0;
casex(State)
/*-------------------------------State 0-----------------------------------*/
    State0:
    begin
         $display("FSM State0");
        casex(Control[0])
            1'b1:
            begin
                Next_State = State1;
                Clear      = 1'b1;
            end
            default :
            begin
                Next_State = State0;
                Clear      = 1'b0;
            end
        endcase
    end
/*-------------------------------State 1------------------------------------*/
    State1:
    begin
        $display("FSM State1");
        Scratch1AddressFlag  = 1'b1;
        Next_State           = State2;
        BucketInc            = 1'b1;
    end
/*-------------------------------State 2------------------------------------*/
    State2:
    begin
        $display("FSM State2");
        Next_State     = State3;
    end
/*-------------------------------State 3------------------------------------*/
    State3:
    begin
        $display("FSM State3");
        Next_State     = State4;
        CountStore      = 1'b1;
    end
/*-------------------------------State 4------------------------------------*/
    State4:
    begin
    $display("FSM State4");
    for(i=0;i<4;i=i+1)
    begin
        if(CountRegister[i] != 0)
            begin 
                CDFMinFlag[i] =  1'b1;
                ConstCalcFlag =  1'b1;
            end
    end
        if(ConstCalcFlag == 1'b1)
            Next_State  = State5;
        else
            Next_State  = State1;
    end
/*-------------------------------State 5------------------------------------*/
    State5:
    begin
        $display("FSM State5");
        Next_State     = State6;
    end
/*-------------------------------State 6------------------------------------*/
    State6:
    begin
        $display("FSM State6");
        Next_State     = State7;
    end
/*-------------------------------State 7------------------------------------*/
    State7:
    begin
        $display("FSM State7");
        Next_State     = State8;
    end

/*-------------------------------State 8------------------------------------*/
    State8:
    begin
    $display("FSM State8");
        begin  
            ConstDivFlag = 1'b1;
            Next_State   = State9;
        end 
    end
/*-------------------------------State 9------------------------------------*/  
    State9:
    begin
    $display("FSM State9");
            BucketReset     = 1'b1;  
            Next_State       = State10;            
    end
/*-----------------------------State 10------------------------------------*/
    State10:
    begin
    $display("FSM State10");
        casex(Completeflag)
        1'b1:
        begin
            Pipelined     = 1'b0;
            Next_State    = State0;
        end
        1'b0: 
        begin
            Pipelined      = 1'b1;
            Next_State     = State10;        
         end 
        endcase   
    end
endcase
end
endmodule


