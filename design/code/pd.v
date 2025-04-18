module pd(
  input clock,
  input reset
);

//Instrution fetch registers----------------
//(didn't have i_ prefix in pd1)
reg i_read_write;
reg [31:0] i_address;
reg [31:0] i_data_in;
wire [31:0] i_data_out;
reg i_mem_enable;

//Instruction Decode registers--------------
reg [31:0] d_pc;
reg [31:0] d_instr;

wire [6:0] d_opcode;
wire [4:0] d_rd;
wire [4:0] d_rs1;
wire [4:0] d_rs2;
wire [2:0] d_funct3;
wire [6:0] d_funct7;
wire [31:0] d_imm; //Immediate value is 32-bit (sign extended) to allow arithmetic with pc/registers
wire [4:0] d_shamt;

//Register file registers
reg [31:0] d_data_rd;
wire [31:0] d_data_rs1;
wire [31:0] d_data_rs2;

wire d_reg_write_enable;
wire d_mem_read_write;
wire d_mem_or_alu;

reg stalling;

reg d_nop;      //1 if NOP will be inserted in D at the next clock cycle

//Execute Registers--------------------------
reg [31:0] x_pc;

wire [31:0] x_alu_out;
wire x_b_taken;
wire [31:0] x_alu_pc_out;

reg [6:0] x_opcode;
reg [4:0] x_rd;
reg [4:0] x_rs1;
reg [4:0] x_rs2;
reg [2:0] x_funct3;
reg [6:0] x_funct7;
reg [31:0] x_imm; 
reg [4:0] x_shamt;
wire [31:0] x_data_rs1;
wire [31:0] x_data_rs2;

(* dont_touch = "true" *) reg [31:0] x_data_rs1_f;  //Forwarded/Bypassed rs1
(* dont_touch = "true" *) reg [31:0] x_data_rs2_f;  //Forwarded rs2

reg x_reg_write_enable;
reg x_mem_read_write;
reg x_mem_or_alu;

reg x_nop;    //1 if NOP will be insterted in X at the next clock cycle

//Memory Registers---------------------------
reg [31:0] m_pc;
reg [1:0] m_access_size;
wire [31:0] m_data_in;
wire [31:0] m_data_out;
//Output of memory register with proper sign-extension
reg [31:0] m_data_out_sign;
reg [2:0] m_funct3; //Needed for sign extension logic

reg m_reg_write_enable;
reg m_mem_read_write;
reg m_mem_or_alu;
reg [31:0] m_alu_out;

reg [4:0] m_rs1;  //May need to be forwarded
reg [4:0] m_rs2;

reg [31:0] m_data_rs2;

(* dont_touch = "true" *) reg [31:0] m_data_rs1_f;
(* dont_touch = "true" *) reg [31:0] m_data_rs2_f;

reg [4:0] m_rd; //rd #/address attributed to m stage (for bypassing) 
reg [31:0] m_data_rd; //From the memory stage, this can only be the ALU output

//Writeback Register(s)-----------------------
//reg [31:0] wb_out;
(* dont_touch = "true" *) reg [31:0] w_pc;
reg [31:0] w_alu_out;
reg [31:0] w_m_data_out_sign;

(* dont_touch = "true" *) reg w_reg_write_enable;
reg w_mem_read_write;
reg w_mem_or_alu;

reg [2:0] w_funct3; //Needed for sign extension logic
wire [31:0] w_mem_data_out;
reg [31:0] w_mem_data_out_sign;

(* dont_touch = "true" *) reg [4:0] w_rd; //rd #/address attributed to w stage
(* dont_touch = "true" *) reg [31:0] w_data_rd; //From the w stage, this can either be alu_out or m_data
                      //which is specified by w_mem_or_alu

//Instantiate imemory module
imemory imemory_0 (
  .clock(clock),
  .enable(i_mem_enable),
  .read_write(i_read_write),
  .address(i_address),
  .data_in(i_data_in),
  .data_out(i_data_out)     // Used to be i_data_out, but this needs to be d_instr due to the 1 cycle imem read penalty
);

dmemory dmemory_0 (
  .clock(clock),
  .read_write(m_mem_read_write),
  .access_size(m_access_size),    
  .address(m_alu_out),       //Memory address is always ALU output          
  .data_in(m_data_rs2_f),    //Data in is always rs2
  .data_out(w_mem_data_out)
);

decode decode_0 (
  .clock(clock),
  .reset(reset),
  .instr(d_instr),             //Using data directly outputted from instr. mem.
  .pc(d_pc),                 //Using PC used in instr. fetch stage (not pipelined)
  .opcode(d_opcode),  
  .rd(d_rd),
  .rs1(d_rs1),  
  .rs2(d_rs2),  
  .funct3(d_funct3),  
  .funct7(d_funct7),  
  .imm(d_imm),
  .shamt(d_shamt),
  .mem_read_write(d_mem_read_write),
  .reg_write_enable(d_reg_write_enable),
  .mem_or_alu(d_mem_or_alu)
);

//NOP Mux
//If NOP is inserted into D stage, make it decode the NOP instr instead of i_mem output
always @(*) begin
  if (d_nop) begin
    d_instr = 32'h13;  //ADDI X0,X0,0
  end
  else begin
    d_instr = i_data_out;
  end
end

register_file register_file_0(
  .clock(clock),
  .reset(reset),
  .addr_rs1(d_rs1),
  .addr_rs2(d_rs2),
  .data_rs1(x_data_rs1),  
  .data_rs2(x_data_rs2),
  .addr_rd(w_rd),         // Gets written back from the W stage
  .data_rd(w_data_rd),    // ^
  .write_enable(w_reg_write_enable)   // Determined by the W stage
);

//assign alu_input_b = alu_imm_select ? d_rs2 : d_imm;

alu alu_0(
  .reset(reset),
  .rs1(x_data_rs1_f),
  .rs2(x_data_rs2_f),
  .imm(x_imm),
  .pc(x_pc),
  .opcode(x_opcode),
  .funct3(x_funct3),
  .funct7(x_funct7),
  .shamt(x_shamt),
  .pc_out(x_alu_pc_out),
  .b_taken(x_b_taken),
  .out(x_alu_out)
);

initial begin
  //Set to default instruction address
  i_address = 32'h01000000;
end

//Drive PC using sequential logic
always @(posedge clock) begin
  if (reset) begin
    //Synchronous reset
    i_address <= 32'h01000000;
    //Don't allow a write instruction to write if at any point there had been a reset
    x_mem_read_write <= 0;
    x_reg_write_enable <= 0;
    m_mem_read_write <= 0;
    m_reg_write_enable <= 0;
    w_mem_read_write <= 0;
    w_reg_write_enable <= 0;
    d_nop <= 1;  //At the beginning, D shouldn't take F's imem output

    d_pc <= 0;
    x_pc <= 0;
    x_opcode <= 0;
    x_rd <= 0;
    x_rs1 <= 0;
    x_rs2 <= 0;
    x_funct3 <= 0;
    x_funct7 <= 0;
    x_imm <= 0; 

    m_pc <= 0;    
    m_alu_out <= 0;
    m_data_rs2 <= 0;
    m_access_size <= 0;   //It just so happens that those funct3 bits specify load/store access size
    m_funct3 <= 0;   //Needed for sign extension logic
    m_mem_read_write <= 0;
    m_reg_write_enable <= 0;
    m_mem_or_alu <= 0;
    m_rs1 <= 0;
    m_rs2 <= 0;
    m_rd <= 0;
    // -- from Memory to Writeback
    w_pc <= 0;
    w_alu_out <= 0;
    w_funct3 <= 0;
    w_rd <= 0;
  end
  else begin

    // ------- Pipelining
    
    // -- from Fetch to Decode
    if (x_b_taken) begin
      //Insert NOP
      //d_pc <= i_address;
      d_pc <= d_pc;   // <-- This is done in golden
      //d_instr <= 32'h13;  //ADDI X0,X0,0
      d_nop <= 1;
    end
    else if (stalling) begin
      d_pc <= d_pc;
      //d_instr <= d_instr;   //Doesn't change when stalling.
    end
    else begin
      d_pc <= i_address;
      d_nop <= 0;
    end

    // -- from Decode to Execute
    if (x_b_taken) begin
      x_pc <= d_pc;
      //Insert NOP: ADDI X0,X0,0 
      x_opcode <= 7'b0010011;
      x_rd <= 0;
      x_rs1 <= 0;
      x_rs2 <= 0;
      x_funct3 <= 0;
      x_funct7 <= 0;
      x_imm <= 0; 
      //x_data_rs1 <= 0;
      //x_data_rs2 <= 0;

      x_mem_read_write <= 0;
      x_reg_write_enable <= 0;
      x_mem_or_alu <= 1;
    end
    else if (stalling) begin
      x_pc <= d_pc;
      //Insert NOP: ADDI X0,X0,0 
      x_opcode <= 7'b0010011;
      x_rd <= 0;
      x_rs1 <= 0;
      x_rs2 <= 0;
      x_funct3 <= 0;
      x_funct7 <= 0;
      x_imm <= 0; 
      //x_data_rs1 <= 0;
      //x_data_rs2 <= 0;

      x_mem_read_write <= 0;
      x_reg_write_enable <= 0;
      x_mem_or_alu <= 1;
    end
    else begin
      x_pc <= d_pc;
      x_opcode <= d_opcode;
      x_rd <= d_rd;
      x_rs1 <= d_rs1;
      x_rs2 <= d_rs2;
      x_funct3 <= d_funct3;
      x_funct7 <= d_funct7;
      x_imm <= d_imm; 
      //x_data_rs1 <= d_data_rs1;
      //x_data_rs2 <= d_data_rs2;

      x_mem_read_write <= d_mem_read_write;     //Signals that tell mem & wb stage what to do
      x_reg_write_enable <= d_reg_write_enable;
      x_mem_or_alu <= d_mem_or_alu;
    end
    

    // -- from Execute to Memory
    m_pc <= x_pc;    
    m_alu_out <= x_alu_out;
    m_data_rs2 <= x_data_rs2_f;
    m_access_size <= x_funct3[1:0];   //It just so happens that those funct3 bits specify load/store access size

    m_funct3 <= x_funct3;   //Needed for sign extension logic

    m_mem_read_write <= x_mem_read_write;
    m_reg_write_enable <= x_reg_write_enable;
    m_mem_or_alu <= x_mem_or_alu;

    m_rs1 <= x_rs1;
    m_rs2 <= x_rs2;

    m_rd <= x_rd;


    // -- from Memory to Writeback
    w_pc <= m_pc;

    w_mem_read_write <= m_mem_read_write;
    w_reg_write_enable <= m_reg_write_enable;
    w_mem_or_alu <= m_mem_or_alu;

    w_alu_out <= m_alu_out;

    w_funct3 <= m_funct3;

    w_rd <= m_rd;
    
    // --------
    //Next steps: 
    //  Double check interconnections, 
    //  Implement Bypassing
    //    - forward register indices (as in piazza post)
    // --------



    //Ensure branch has priority over a stall!
    //A stall happens in D, branches occur in X (due to earlier instr)
    if (x_b_taken) begin
      i_address <= x_alu_pc_out;
    end
    else if (stalling) begin
      i_address <= i_address;
    end
    else begin
      //Increment PC
      i_address <= i_address + 4;         //
      //"Note that there is also a PC+4 component in the memory stage.
      //You should implement that here or in the writeback stage."
      //It's implemented here... we can consider this to be in the WB stage... 
      //though it doesn't really matter as its a single-cycle processor
    end
  end
end

//Combinational Logic used for accomodating stalling for 1 cycle reads
//If theres a stall needed, on the next clock cycle, the i_mem output shouldn't change
always @(*) begin
  if (stalling) begin
    i_mem_enable = 0; 
  end
  else begin
    i_mem_enable = 1;
  end
end


// --- Data Forwarding/Bypassing Logic (Combinational)
always @(*) begin
  // --- Bypassing to X stage
  if (x_rs1 == 0) begin
    //Do not forward data / (forwarded x0 value should always be zero; this code has that effect)
    x_data_rs1_f = 0;
  end
  else if ((x_rs1 == m_rd) && (m_reg_write_enable)) begin
      x_data_rs1_f = m_alu_out;   //The only data we should forward from M is the ALU output
      // Golden assumes we can't use data obtained from memory within the same clock cycle.
      // We need to wait for the loaded data to go into WB before allowing forwarding.
  end
  else if ((x_rs1 == w_rd) && (w_reg_write_enable)) begin
    x_data_rs1_f = w_data_rd;
  end
  else begin
    x_data_rs1_f = x_data_rs1;
  end

  if (x_rs2 == 0) begin
    //Do not forward data
    x_data_rs2_f = 0;
  end
  else if ((x_rs2 == m_rd) && (m_reg_write_enable)) begin
    x_data_rs2_f = m_alu_out;
  end
  else if ((x_rs2 == w_rd) && (w_reg_write_enable)) begin
    x_data_rs2_f = w_data_rd;
  end
  else begin
    x_data_rs2_f = x_data_rs2;
  end

  // --- Bypassing to M stage (might not be needed...)
  //Rs1 is part of the offset. It should only be forwarded to the X stage
  // if (m_rs1 == w_rd) begin
  //   m_data_rs1_f = w_data_rd;
  // end
  // else begin
  //   m_data_rs1_f = m_data_rs1;
  // end
  if (m_rs2 == 0) begin
    //Do not forward data
    m_data_rs2_f = 0;
  end
  else if ((m_rs2 == w_rd) && (w_reg_write_enable)) begin
    m_data_rs2_f = w_data_rd;
  end
  else begin
    m_data_rs2_f = m_data_rs2;
  end
  
end

//Decode Stage Logic -----------------------------------------------
always @(*) begin
  //Stalling Logic
  // basically, if the instr in W has an rd that is either rs1 or rs2 in D, we need to stall 
  // to allow the rd to be written to the register file (since there's no WD forwarding).
  // BUT, if the instructions in X or M (more recent intrs) write to that same rd, 
  // because rd in W is older, X/M should overwrite it, which is possible with their forwarding path to X
  // (after a clock cycle) and this is done without requiring a stall!
  // BUT ALSO, if only one of rs1 or rs2 is in the W/X stages, while the other is in W,
  // stalling is still required. 

  // We may also need a "load-use stall". If a preceeding instr is a load and the current instr
  // needs the data in X, in a physical implementation, loaded data will only be available in 
  // the W stage at the earliest.
  // An edge case is if the current instr is a store and its rs2 (mem_data_in) is the only
  // dependency. Since rs2 is only needed in M (when the load will be in W), don't stall 
  // for this reason.

  if (    (x_opcode[6:2] == 5'h00) && 
          ( (((d_opcode[6:2] == 5'b11001)||(d_opcode[6:2] == 5'b11000)||
              (d_opcode[6:2] == 5'b00000)||(d_opcode[6:2] == 5'b00100)||(d_opcode[6:2] == 5'b01100)) && 
              (((d_rs1 == x_rd)&&(d_rs1 != 0)) || ((d_rs2 == x_rd)&&(d_rs2 != 0)))) || 
            ( (d_opcode[6:2] == 5'h8) && (((d_rs1 == x_rd)&&(d_rs1 != 0)))) )    )  begin
    //If X instr is a load and either:
    //    - D instr is any instr (except store) that uses dependent data once in the X stage
    //            - this involves:  JALR (1100111), B (1100011), L (0000011), I (0010011), R (0110011)
    //    - D instr is a store and there is an rs1 dependency
    //  STALL!!!
    stalling = 1;
  end
  else if (( (d_rs1 == w_rd) && (d_rs1 != x_rd) && (d_rs1 != m_rd) && (d_rs1 != 0) ) || 
      ( (d_rs2 == w_rd) && (d_rs2 != x_rd) && (d_rs2 != m_rd) && (d_rs2 != 0) )     ) begin
    stalling = 1;
  end
  else begin
    stalling = 0;
  end
end

//Writeback Stage Logic -----------------------------------------------
always @(*) begin
  //Loaded Data from Memory Sign Extension Logic
  case(w_funct3)
    3'b000 : begin
      //Byte Signed
      w_mem_data_out_sign = { {24{w_mem_data_out[7]}}, w_mem_data_out[7:0] };
    end
    3'b001 : begin
      //Half-word Signed
      w_mem_data_out_sign = { {16{w_mem_data_out[15]}}, w_mem_data_out[15:0] };
    end
    3'b010 : begin
      //Word Signed
      //Stay as is
      w_mem_data_out_sign = w_mem_data_out;
    end
    3'b100 : begin
      //Byte Unsigned
      w_mem_data_out_sign = { 24'h000000, w_mem_data_out[7:0] };
    end
    3'b101 : begin
      //Half-word Unsigned
      w_mem_data_out_sign = { 16'h0000, w_mem_data_out[15:0] };
    end
    default : begin
      w_mem_data_out_sign = w_mem_data_out;
    end
  endcase

  // rd data selection logic (either w_mem_data_out or w_alu_out)
  if (!w_mem_or_alu) begin
    //Memory goes to rd
    w_data_rd = w_mem_data_out_sign;
  end
  else begin
    w_data_rd = w_alu_out;
  end

end

endmodule
