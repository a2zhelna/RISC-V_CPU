module alu #()
(
    input wire reset, 
    input [31:0] rs1,
    input [31:0] rs2,
    input [31:0] imm,
    input [31:0] pc,
    input [6:0] opcode,
    input [2:0] funct3,
    input [6:0] funct7,
    input [4:0] shamt,
    output reg[31:0] pc_out,
    output reg b_taken,
    output reg[31:0] out
);

reg[3:0] op;

//Signed registers for signed operators
reg signed [31:0] s_rs1;
reg signed [31:0] s_rs2;
reg signed [31:0] s_imm;

always @(*) begin
    
    if (reset) begin
        //Might reset some other signals here if need be, but golden traces haven't showed this to be necessary
        b_taken = 0;   
        s_rs1 = 0;
        s_rs2 = 0;
        s_imm = 0;
        pc_out = 0;           
        out = 0;   
    end
    else begin
        s_rs1 = rs1;
        s_rs2 = rs2;
        s_imm = imm;
        pc_out = pc;        //pc_out (set combinationally), is either pc or pc + some calculated offset
        b_taken = 0;        //TA says this signal is don't care for jal/jalr, but I see it as a control signal that's applicable for both branches AND jumps.
                            //  How else should you tell the processor to change the PC after a jump?

        case (opcode[6:2])
            5'b01100 : begin
                //R
                case(funct3)
                    3'h0:begin
                        //Add/Sub
                        case(funct7)
                            7'h00:begin
                                //ADD
                                out = rs1 + rs2;
                            end
                            7'h20:begin
                                //SUB
                                out = rs1 - rs2;
                            end
                            default:begin
                                //Do nothing
                            end
                        endcase
                    end
                    3'h1:begin
                        //SLL   
                        out = rs1 << rs2[4:0];
                    end
                    3'h2:begin
                        //SLT
                        out = (s_rs1 < s_rs2) ? 1 : 0;
                    end
                    3'h3:begin
                        //SLTU
                        out = (rs1 < rs2) ? 1 : 0;
                    end
                    3'h4:begin
                        //XOR
                        out = rs1 ^ rs2; 
                    end
                    3'h5:begin
                        //SRL/SRA
                        case(funct7)
                            7'h00:begin
                                //SRL
                                out = rs1 >> rs2[4:0];      //Interesting nuance where only lower 5 bits are used
                            end
                            default: begin
                                //SRA
                                out = s_rs1 >>> rs2[4:0];     //Same deal here with lower 5 bits
                            end
                        endcase
                    end
                    3'h6:begin
                        //OR
                        out = rs1 | rs2;
                    end
                    3'h7:begin
                        //AND
                        out = rs1 & rs2;
                    end
                    default: begin
                        //Do nothing
                    end
                endcase
            end
            5'b00100:begin
            //I (specific case involving instructions who's format is differentiated by funct3)
                case(funct3)
                    3'h1: begin
                        //SLLI
                        out = rs1 << imm[4:0];
                    end
                    3'h5: begin
                        //SRLI/SRAI
                        case(funct7)
                            7'h00:begin
                                //SRLI
                                out = s_rs1 >> imm[4:0];
                            end
                            7'h20:begin
                                //SRAI
                                out = s_rs1 >>> imm[4:0];
                            end
                            default:begin
                                out = 0;                           
                            end
                        endcase
                    end
                    3'h0: begin
                        //ADDI
                        out = rs1 + s_imm;
                    end
                    3'h2: begin
                        //SLTI
                        out = (s_rs1 < s_imm) ? 1 : 0;
                    end
                    3'h3: begin
                        //SLTIU
                        out = (rs1 < imm) ? 1 : 0;
                    end
                    3'h4: begin
                        //XORI
                        out = rs1 ^ imm;
                    end
                    3'h6: begin
                        //ORI
                        out = rs1 | imm;
                    end
                    3'h7: begin
                        //ANDI
                        out = rs1 & imm;
                    end
                    default : begin

                    end
                endcase
            end

            // TA on piazza: "In the project, we chose to implement the target address in the ALU
            // and used another component called the branch compare unit to determine the branch result."

            5'b11001:begin
            //I
                //JALR
                out = pc + 4;
                pc_out = (rs1 + imm) & 32'hFFFFFFFE;       //Set LSB to 0, as per specification
                b_taken = 1;
            end
            5'b00000:begin
                case(funct3)
                    3'h0: begin
                        //LB
                        out = rs1 + s_imm;
                    end
                    3'h1: begin
                        //LH
                        out = rs1 + s_imm;
                    end
                    3'h2: begin
                        //LW
                        out = rs1 + s_imm;
                    end
                    3'h4: begin
                        //LBU
                        out = rs1 + s_imm;
                    end
                    3'h5: begin
                        //LHU
                        out = rs1 + s_imm;
                    end
                    default : begin

                    end
                endcase
            end
            5'b11100:begin
                //I (ECALL)
                //Nothing happens?
                out = 0;
            end
            5'b01000 :begin
            //S
                case(funct3)
                    3'h0: begin
                        //SB
                        out = rs1 + s_imm;
                    end
                    3'h1: begin
                        //SH
                        out = rs1 + s_imm;
                    end
                    3'h2: begin
                        //SW
                        out = rs1 + s_imm;
                    end
                    default : begin
                        //Do nothing
                    end
                endcase
            end
            5'b11000 :begin
            //B
                case(funct3)
                    3'h0: begin
                        //BEQ
                        pc_out = (rs1 == rs2) ? pc + s_imm : pc + 4;
                        b_taken = (rs1 == rs2) ? 1 : 0;
                    end
                    3'h1: begin
                        //BNE
                        pc_out = (rs1 != rs2) ? pc + s_imm : pc + 4;
                        b_taken = (rs1 != rs2) ? 1 : 0;
                    end
                    3'h4: begin
                        //BLT
                        pc_out = (s_rs1 < s_rs2) ? pc + s_imm : pc + 4;
                        b_taken = (s_rs1 < s_rs2) ? 1 : 0;
                    end
                    3'h5: begin
                        //BGE
                        pc_out = (s_rs1 >= s_rs2) ? pc + s_imm : pc + 4;
                        b_taken = (s_rs1 >= s_rs2) ? 1 : 0;
                    end
                    3'h6: begin
                        //BLTU
                        pc_out = (rs1 < rs2) ? pc + s_imm : pc + 4;
                        b_taken = (rs1 < rs2) ? 1 : 0;
                    end
                    3'h7: begin
                        //BGEU
                        pc_out = (rs1 >= rs2) ? pc + s_imm : pc + 4;
                        b_taken = (rs1 >= rs2) ? 1 : 0;
                    end
                    default : begin

                    end
                endcase
            end
            5'b11011 :begin
            //J
                //JAL
                out = pc + 4;
                pc_out = pc + s_imm;
                b_taken = 1;
            end
            5'b01101:begin
            //U
                //LUI
                out = imm;
            end
            5'b00101 :begin
            //U
                //AUIPC
                out = imm + pc;
            end
            default : begin
            //Do nothing
            end
        endcase
    end
end

endmodule
