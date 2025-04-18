/* Your Code Below! Enable the following define's 
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                i_address
`define F_INSN              i_data_out

`define D_PC                d_pc   //Not yet pipelined PC
`define D_OPCODE            d_opcode
`define D_RD                d_rd
`define D_RS1               d_rs1
`define D_RS2               d_rs2
`define D_FUNCT3            d_funct3
`define D_FUNCT7            d_funct7
`define D_IMM               d_imm
`define D_SHAMT             d_shamt

`define R_WRITE_ENABLE      w_reg_write_enable
`define R_WRITE_DESTINATION w_rd
`define R_WRITE_DATA        w_data_rd
`define R_READ_RS1          d_rs1
`define R_READ_RS2          d_rs2
`define R_READ_RS1_DATA     x_data_rs1
`define R_READ_RS2_DATA     x_data_rs2

`define E_PC                x_pc           
`define E_ALU_RES           x_alu_out
`define E_BR_TAKEN          x_b_taken

`define M_PC                m_pc 
`define M_ADDRESS           m_alu_out  //assigned to alu_out
`define M_RW                m_mem_read_write
`define M_SIZE_ENCODED      m_access_size
`define M_DATA              m_data_rs2_f //input data to mem module assigned to m_data_rs2_f

`define W_PC                w_pc
`define W_ENABLE            w_reg_write_enable
`define W_DESTINATION       w_rd
`define W_DATA              w_data_rd

`define IMEMORY             imemory_0
`define DMEMORY             dmemory_0

// ----- signals -----

// ----- design -----
`define TOP_MODULE                 pd
// ----- design -----
