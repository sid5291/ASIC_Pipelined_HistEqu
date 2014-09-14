/*************************************
*
* NAME:  Control Block
*
* DESCRIPTION:
*  Control Block as Branched FSM
*
* NOTES:
*
* REVISION HISTORY*
*  Revision     Date       Programmer    Description
*  1.0          3/7/2014   SK15          Control Block
*   
*M*/

/*=============================Declarations===============================*/

module Control (clock, reset, HistFlag, EquFlag, OutputFlag, StartSignal,
                        HistControl,EquControl,OutputControl,FinalFlag);

/*-------------------------------Inputs-----------------------------------*/

input        clock;            /* clock                                 */
input        HistFlag;         /* Histogram Module's completion Flag    */
input        EquFlag;          /* Equalization Module's completion Flag */
input        OutputFlag;       /* Output Module's completion Flag       */
input        reset;            /* reset                                 */
input        StartSignal;      /* External Signal to Start              */

/*-------------------------------Outputs----------------------------------*/

output [1:0]      HistControl;           /* Signal to Start Histogram Module     */
output [1:0]      EquControl;            /* Signal to Start Equalization Module  */    
output [1:0]      OutputControl;            /* Signal to Start Output Control       */
output [1:0]      FinalFlag;

/*-------------------------Nets and Registers-----------------------------*/

reg [4:0]  State;                   /* Current State                    */ 
reg [4:0]  next_state;              /* Next State                       */
reg [2:0]  ImageFlag;
reg [2:0]  ControlFlag;
reg [1:0]  HistControl;             /* Signal to Start Histogram Module     */
reg [1:0]  EquControl;              /* Signal to Start Equalization Module  */    
reg [1:0]  OutputControl;           /* Signal to Start Output Control       */  
reg [1:0]  FinalFlag;

/*-----------------------------Parameters---------------------------------*/

parameter [4:0]           State0             =  5'b00000;     /* State 0 */
parameter [4:0]           State1             =  5'b00001;     /* State 1 */
parameter [4:0]           State2             =  5'b00011;     /* State 2 */
parameter [4:0]           State3             =  5'b00010;     /* State 3 */
parameter [4:0]           State4             =  5'b00110;     /* State 4 */
parameter [4:0]           State5             =  5'b00100;     /* State 5 */
parameter [4:0]           State6             =  5'b00101;     /* State 6 */
parameter [4:0]           State7             =  5'b00111;     /* State 7 */
parameter [4:0]           State8             =  5'b01111;     /* State 7 */
parameter [4:0]           State9             =  5'b01110;     /* State 7 */
parameter [4:0]           State10            =  5'b01100;     /* State 7 */
parameter [4:0]           State11            =  5'b01000;     /* State 7 */
parameter [4:0]           State12            =  5'b01001;     /* State 7 */
parameter [4:0]           State13            =  5'b01011;     /* State 7 */
parameter [4:0]           State14            =  5'b01010;     /* State 7 */
parameter [4:0]           State15            =  5'b11010;     /* State 7 */
parameter [4:0]           State16            =  5'b11110;     /* State 7 */
parameter [4:0]           State17            =  5'b11111;     /* State 7 */
parameter [4:0]           State18            =  5'b11110;     /* State 7 */


/*=============================Flip-Flops=================================*/

always@(posedge clock)
begin
    casex(reset)
        1'b1:
             State <= State0;
        1'b0:
             State <= next_state;
    endcase
end

/*-----------------------------Image Number-------------------------------*/
always@(posedge clock)
begin
    casex(reset)
        1'b0:
            {HistControl[1],EquControl[1],OutputControl[1]} <= ImageFlag;
        default:
             {HistControl[1],EquControl[1],OutputControl[1]} <= 3'b0;
    endcase
end


/*-----------------------------Control-------------------------------*/
always@(posedge clock)
begin
    casex(reset)
        1'b0:
            {HistControl[0],EquControl[0],OutputControl[0]} <= ControlFlag;
        default:
            {HistControl[0],EquControl[0],OutputControl[0]} <= 3'b0;
    endcase
end

/*=========================Combinational Logic============================*/
always@(*)
begin
next_state = State0;
ControlFlag = 3'b0;
ImageFlag   = 3'b0;
    casex(State)
        State0:
            begin 
                ControlFlag = 3'b0;
            casex(StartSignal)
                1'b1:
                    next_state = State1;
                default :
                    next_state = State0;
            endcase
            end
        State1:  // Start Histogram For 1st Image
            begin
            ControlFlag        = 3'b100;
            ImageFlag          = 3'b000;  
            next_state         = State2;
            end
        State2:   // Wait for Histogram to finish
            begin
            ControlFlag       = 3'b100;
            ImageFlag         = 3'b000;
            casex(HistFlag)
                1'b1:
                    next_state  = State3;
                1'b0:
                    next_state  = State2;
            endcase  
            end
        State3:      // Turn on Equalizer Module and Switch Histogram to Image 2
            begin
            ControlFlag        = 3'b110;
            ImageFlag          = 3'b100;
            next_state         = State4;
            end
        State4:    // Wait for either Equalizer first image to finish or Histogram Second Image
            begin
            ControlFlag       = 3'b110;
            ImageFlag         = 3'b100;
            casex({HistFlag,EquFlag})
                2'b01:
                    next_state  = State5;
                2'b10:
                    next_state  = State6;
                2'b11:
                    next_state  = State7;
                2'b00:
                    next_state  = State4;
            endcase
            end
        State5:  // On Completion of Equalizer First Image Turn on Output Module for Image 1; Wait for Hist or Output Completion 
            begin
                ControlFlag = 3'b101;
                ImageFlag   = 3'b100;
            casex({HistFlag,OutputFlag})
                2'b10:
                    next_state  = State7;
                2'b01:
                    next_state  = State8;
                2'b11:
                    next_state  = State9;
                2'b00:
                    next_state  = State5;
                endcase
            end
        State6:  // On Completion of Hist module's second image wait for equ flag first image
            begin       
                ControlFlag = 3'b010;
                ImageFlag   = 3'b000;
                casex(EquFlag)
                    1'b1:
                        next_state = State7;
                    1'b0:
                        next_state = State6;
                endcase
            end
        State7:  // Completion of Hist second image and Equ flag ; start equ second image and output first image
            begin
                ControlFlag = 3'b011;
                ImageFlag   = 3'b010;
                casex({EquFlag,OutputFlag})
                    2'b10:
                        next_state = State10;
                    2'b01:
                        next_state = State11;
                    2'b11:
                        next_state = State12;
                    2'b00:
                        next_state = State7;
                endcase
            end
        State8: // Completion of Output First Image; Waiting for Hist Second Image
            begin
                ControlFlag = 3'b100;
                ImageFlag   = 3'b100;
                casex(HistFlag)
                    1'b1:
                        next_state = State9;
                    1'b0:
                        next_state = State8;
                endcase
            end
        State9:  // Completion of Hist second Image and Output first Image; Start Equ Flag Second Image 
            begin
                ControlFlag = 3'b010;
                ImageFlag   = 3'b010;
                casex(EquFlag)
                    1'b1:
                        next_state = State12;
                    1'b0:
                        next_state = State9;
                endcase
            end
        State10: // Completion of Equ for Second Image Wait for Output first image
            begin
                ControlFlag = 3'b001;
                ImageFlag   = 3'b000;
                casex(OutputFlag)
                1'b1:
                    next_state = State12;  
                1'b0:
                    next_state = State10;
                endcase
            end
        State11: // Completion of Ouput for First Image Wait for Equ Second image
            begin
                ControlFlag = 3'b001;
                ImageFlag   = 3'b000;
                casex(EquFlag)
                1'b1:
                    next_state = State12;  
                1'b0:
                    next_state = State11;
                endcase
            end
        State12:   // Begin Output for Second Image ask for Load of new first image
            begin
                ControlFlag = 3'b001;
                ImageFlag   = 3'b001;
                FinalFlag   = 2'b01;
                next_state  = State13;
            end 
        State13: // Continue Output Second Image and Start Hist First Image; Wait for HistFlag and OutputFlag
            begin
                ControlFlag = 3'b101;
                ImageFlag   = 3'b001;
                casex({HistFlag,OutputFlag})
                2'b10:
                    next_state  = State14;
                2'b01:
                    next_state  = State15;
                2'b11:
                    next_state  = State16;
                2'b00:
                    next_state  = State13;
                endcase
            end
        State14:  // Hist First Image Complete, Wait for Output Second Image Start Equ for first image
            begin
            ControlFlag = 3'b011;
            ImageFlag   = 3'b001;
            casex({EquFlag,OutputFlag})
            2'b10:
                next_state = State17;  
            2'b01:
                next_state = State18;        
            2'b00:
                next_state = State14;
            endcase
            end
        State15:  // Continue First Image Hist, Load new Second image
            begin
                ControlFlag = 3'b100;
                ImageFlag   = 3'b000;
                FinalFlag   = 2'b10;
                next_state  = State1;
            end
        State16:  // Load Second Image
            begin
                ControlFlag = 3'b000;
                ImageFlag   = 3'b000;
                FinalFlag   = 2'b10;
                next_state  = State3;
            end
        State17: // Completion of Equ for First Image Wait for Output Second image
            begin
                ControlFlag = 3'b001;
                ImageFlag   = 3'b001;
                casex(OutputFlag)
                1'b1:
                    next_state = State16;  
                1'b0:
                    next_state = State17;
                endcase
            end
        State18:   // Load Second Image and Continue EquControl for First Image 
            begin
                ControlFlag = 3'b010;
                ImageFlag   = 3'b000;
                FinalFlag   = 2'b10;
                next_state  = State4;
            end
    endcase
end
endmodule