//Will need to add this attribute syntax for memory: (* ram_style = "block" *)

// Note: "In prior PDs, we assumed that imemory and dmemory have 1MB of storage.
//          We cannot map this much space on the FPGA.
//          Hence, in PD6, the MEM_DEPTH is reduced to 4KB.
//          Make sure your register file, especially the stack pointer, functions correctly under this assumption."

module register_file #()
(
    input wire clock,
    input wire reset,
    input [4:0] addr_rs1,
    input [4:0] addr_rs2,
    input [4:0] addr_rd,
    input [31:0] data_rd,
    output reg [31:0] data_rs1,
    output reg [31:0] data_rs2,
    input wire write_enable
);

(* ram_style = "block" *) reg [31:0] register [31:0];         //2^5=32 32-bit registers

//For loop variable
integer i;

initial begin
    //Initialize all registers to zero except x2
    for (i = 0; i < 32; i = i + 1) begin   
        //register[31:0][i] = 0;
        register[i] = 0;
    end
    //register[31:0][2] = 32'h01000000+`MEM_DEPTH;    //Set x2 to top of stack
    register[2] = 32'h01000000+`MEM_DEPTH;
end

//Combinational reads of register contents
// assign data_rs1 = register[31:0][addr_rs1];
// assign data_rs2 = register[31:0][addr_rs2];

always @(posedge clock) begin
    if (reset) begin
        //Do nothing on reset high! Don't write!
    end
    else begin
        if (write_enable) begin
            //Write to destination register
            if (addr_rd != 0) begin     //Ensure we aren't writing to x0, which stores 0 no matter what
                // register[31:0][addr_rd] <= data_rd;
                register[addr_rd] <= data_rd;
            end
        end
        else begin
            //Nothing should be done
        end
        // data_rs1 <= register[31:0][addr_rs1];
        // data_rs2 <= register[31:0][addr_rs2];
        data_rs1 <= register[addr_rs1];
        data_rs2 <= register[addr_rs2];
    end
end

endmodule
