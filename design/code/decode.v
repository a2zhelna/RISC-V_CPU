module decode #() (
input wire reset, 
input wire clock,
input wire [31:0] instr,
input wire [31:0] pc,

//Should these be wires since "decode stage must be combinational" - pg. 22 ???
output reg [6:0] opcode,
output reg [4:0] rd,
output reg [4:0] rs1,
output reg [4:0] rs2,
output reg [2:0] funct3,
output reg [6:0] funct7,
output reg [31:0] imm, //Immediate value is 32-bit (sign extended) to allow arithmetic with pc/registers
output reg [4:0] shamt,

output reg mem_read_write,
output reg reg_write_enable,
output reg mem_or_alu       //0-MEM, 1-ALU

);

always @(*) begin

    if (reset) begin
    
        reg_write_enable = 0;
        mem_read_write = 0;

        rd = 0;
        rs1 = 0;
        rs2 = 0;
        funct3 = 0;
        funct7 = 0;
        shamt = 0;
    end

    else begin

    reg_write_enable = 0;   //no writes by default
    mem_read_write = 0;     // ^

    opcode = instr[6:0];
    
    rd = instr[11:7];
    rs1 = instr[19:15];
    rs2 = instr[24:20];
    funct3 = instr[14:12];
    funct7 = instr[31:25];
    shamt = instr[24:20];

    case (opcode[6:2])
        5'b01100 : begin
        //R
            // rd = instr[11:7];
            // funct3 = instr[14:12];
            // rs1 = instr[19:15];
            // rs2 = instr[24:20];
            // funct7 = instr[31:25];
        end
        5'b00100:begin
        //I (specific case involving instructions who's format is differentiated by funct3)
            rs2 = 0;    //DC set in golden
            case(instr[14:12])
                3'b001 , 3'b101 : begin
                //Case that it is a SLLI, SRLI or SRAI
                    // rd = instr[11:7];
                    // funct3 = instr[14:12];
                    // rs1 = instr[19:15];
                    shamt = instr[24:20];
                    imm = { {20{instr[31]}}, instr[31:20] };
                    // funct7 = instr[31:25];
                end
                default : begin
                    // rd = instr[11:7];
                    // funct3 = instr[14:12];
                    // rs1 = instr[19:15];
                    imm = { {20{instr[31]}}, instr[31:20] };     //Sign extension using Concatenation_Operator( Replication_Operator(MSB), VALUE )
                end
            endcase
        end
        5'b11001, 5'b00000:begin
        //I (remaining cases, excluding ECALL)
            rs2 = 0;    //DC set in golden
            // rd = instr[11:7];
            // funct3 = instr[14:12];
            // rs1 = instr[19:15];
            imm = { {20{instr[31]}}, instr[31:20] };
        end
        5'b11100:begin
        //I (ECALL)
        //This doesn't change anything; can remove this case
            // rd = 0;
            // funct3 = 0;
            // rs1 = 0;
            imm = 0;
            shamt = 0;
        end
        5'b01000 :begin
        //S
            imm = { {20{instr[31]}}, instr[31:25], instr[11:7] };
            rd = 0;     //Edge case where store imm value can be a register of a following instr, causing a stall
            // funct3 = instr[14:12];
            // rs1 = instr[19:15];
            // rs2 = instr[24:20];
        end
        5'b11000 :begin
        //B
            rd = 0;    //DC set in golden
            imm = { {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0 };
            // funct3 = instr[14:12];
            // rs1 = instr[19:15];
            // rs2 = instr[24:20];
        end
        5'b11011 :begin
        //J
            // rd = instr[11:7];
            rs2 = 0;
            imm = { {11{instr[31]}},  instr[31], instr[19:12], instr[20], instr[30:21], 1'b0 };
        end
        5'b01101, 5'b00101 :begin
        //U
            rs1 = 0;    //DC set in golden
            rs2 = 0;    // ^
            // rd = instr[11:7];
            imm = { instr[31:12], {12{1'b0}} };
        end
        default : begin
        //Do nothing
            rs2 = 0;
            rd = 0;

            reg_write_enable = 0;
            mem_read_write = 0;

            rd = 0;
            rs1 = 0;
            rs2 = 0;
            funct3 = 0;
            funct7 = 0;
            shamt = 0;
            imm = 0;
        end
    endcase

    //Memory/Register-file Access Logic + Stalling logic
    case(opcode[6:2])
      5'h00 : begin
        //Load instruction
        reg_write_enable = 1;
        mem_read_write = 0;
        mem_or_alu = 0;       //Specify that load writes back memory data to rd
      end
      5'b01101, 5'b00101, 5'b11011, 5'b11001, 5'b00100, 5'b01100, 5'b11100 : begin
        //If it is an instruction that requires a WB, enable WB
        //(Sidenote: I used to do this in the default case, but that would make all invalid instr to write)
        mem_or_alu = 1;  
        reg_write_enable = 1;
        //The ALU output of JAL/JALR is PC+4, for any other instruction (except loads) it is the result of the specified arithmetic operation, which should be writted to rd
        //For any other instructions (like stores, branches, ...) that don't write back to rd, the output of the WB stage is a don't care.
        mem_read_write = 0;
      end
      5'h8 : begin 
        //If the instruction is a store, disable write on the register file
        reg_write_enable = 0;
        //Store is the only instruction that writes to memory:
        mem_read_write = 1;
        mem_or_alu = 1;
      end
      5'h18 : begin
        //If the instruction is a branch, disable write on the register file
        reg_write_enable = 0;
        mem_read_write = 0;
        mem_or_alu = 1;
      end
      default : begin
        reg_write_enable = 0; 
        mem_read_write = 0;
        mem_or_alu = 1;         
      end
    endcase

    end

end

endmodule

