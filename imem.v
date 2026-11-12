`timescale 1ns / 1ps

module imem #(
    parameter DEPTH = 256
)(
    input  wire [31:0] addr,
    output wire [31:0] rdata
);

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h00000013;

        // =====================================
        // INTEGER OPERAND INITIALIZATION
        // =====================================
        mem[0] = 32'hFFB00093; // ADDI x1, x0, -5
        mem[1] = 32'h00300113; // ADDI x2, x0,  3

        // Pipeline spacing
        mem[2] = 32'h00000013; // NOP
        mem[3] = 32'h00000013; // NOP
        mem[4] = 32'h00000013; // NOP

        // =====================================
        // INTEGER ALU: REGISTER-REGISTER
        // =====================================
        mem[5]  = 32'h002081B3; // ADD  x3,  x1, x2
        mem[6]  = 32'h40208233; // SUB  x4,  x1, x2
        mem[7]  = 32'h0020F2B3; // AND  x5,  x1, x2
        mem[8]  = 32'h0020E333; // OR   x6,  x1, x2
        mem[9]  = 32'h0020C3B3; // XOR  x7,  x1, x2
        mem[10] = 32'h00209433; // SLL  x8,  x1, x2
        mem[11] = 32'h0020D4B3; // SRL  x9,  x1, x2
        mem[12] = 32'h4020D533; // SRA  x10, x1, x2
        mem[13] = 32'h0020A5B3; // SLT  x11, x1, x2
        mem[14] = 32'h0020B633; // SLTU x12, x1, x2

        // =====================================
        // INTEGER ALU: IMMEDIATE INSTRUCTIONS
        // =====================================
        mem[15] = 32'h0000A693; // SLTI  x13, x1, 0
        mem[16] = 32'h0000B713; // SLTIU x14, x1, 0
        mem[17] = 32'h00F0C793; // XORI  x15, x1, 15
        mem[18] = 32'h0100E813; // ORI   x16, x1, 16
        mem[19] = 32'h00F0F893; // ANDI  x17, x1, 15
        mem[20] = 32'h00211913; // SLLI  x18, x2, 2
        mem[21] = 32'h0020D993; // SRLI  x19, x1, 2
        mem[22] = 32'h4020DA13; // SRAI  x20, x1, 2
        mem[23] = 32'h12345AB7; // LUI   x21, 0x12345

        // =====================================
        // FLOATING-POINT OPERATIONS
        // Assumes f1 = 1.0 and f2 = 2.0
        // =====================================
        mem[24] = 32'h002081D3; // FADD.S f3, f1, f2
        mem[25] = 32'h08208253; // FSUB.S f4, f1, f2
        mem[26] = 32'h102082D3; // FMUL.S f5, f1, f2
        mem[27] = 32'h18208353; // FDIV.S f6, f1, f2

        // All remaining locations are NOPs
    end

    // Word-aligned instruction fetch
    assign rdata = mem[addr[$clog2(DEPTH)+1:2]];

endmodule
