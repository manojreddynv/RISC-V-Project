
`timescale 1ns / 1ps

module fp_regfile (
    input  wire        clk,
    input  wire        we,

    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,

    input  wire [31:0] rd_data,

    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [0:31];
    integer i;

    // Simulation initialization
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'h00000000;

        // IEEE-754 single-precision test operands
        regs[1] = 32'h3F800000; // f1 = 1.0
        regs[2] = 32'h40000000; // f2 = 2.0
    end

    // Write floating-point result
    // f0 is a writable FP register in RISC-V
    always @(posedge clk) begin
        if (we)
            regs[rd_addr] <= rd_data;
    end

    // Asynchronous reads with write-through forwarding
    assign rs1_data =
        (we && (rd_addr == rs1_addr))
        ? rd_data : regs[rs1_addr];

    assign rs2_data =
        (we && (rd_addr == rs2_addr))
        ? rd_data : regs[rs2_addr];

endmodule
