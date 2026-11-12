
`timescale 1ns/1ps

module decoder (
    input  wire [31:0] instr,

    output wire [6:0] opcode,
    output wire [4:0] rd,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output reg  [31:0] imm,

    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg alu_src,
    output reg branch,
    output reg is_jal,
    output reg is_jalr,
    output reg is_lui,
    output reg is_auipc,
    output reg [3:0] alu_op,
    output reg [2:0] branch_type,

    output reg is_fp,
    output reg fp_reg_write,
    output reg [2:0] fp_op,
    output reg fp_load,
    output reg fp_store
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    localparam OP_IMM   = 7'b0010011;
    localparam OP_R     = 7'b0110011;
    localparam OP_LOAD  = 7'b0000011;
    localparam OP_STORE = 7'b0100011;
    localparam OP_BR    = 7'b1100011;
    localparam OP_JAL   = 7'b1101111;
    localparam OP_JALR  = 7'b1100111;
    localparam OP_LUI   = 7'b0110111;
    localparam OP_AUI   = 7'b0010111;

    localparam OP_FLW   = 7'b0000111;
    localparam OP_FSW   = 7'b0100111;
    localparam OP_FP    = 7'b1010011;

    wire [31:0] imm_i =
        {{20{instr[31]}}, instr[31:20]};

    wire [31:0] imm_s =
        {{20{instr[31]}}, instr[31:25], instr[11:7]};

    wire [31:0] imm_b =
        {{19{instr[31]}}, instr[31], instr[7],
         instr[30:25], instr[11:8], 1'b0};

    wire [31:0] imm_u = {instr[31:12], 12'b0};

    wire [31:0] imm_j =
        {{11{instr[31]}}, instr[31], instr[19:12],
         instr[20], instr[30:21], 1'b0};

    always @(*) begin
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        alu_src     = 1'b0;
        branch      = 1'b0;
        is_jal      = 1'b0;
        is_jalr     = 1'b0;
        is_lui      = 1'b0;
        is_auipc    = 1'b0;
        alu_op      = 4'b0000;
        branch_type = funct3;
        imm         = 32'b0;

        is_fp        = 1'b0;
        fp_reg_write = 1'b0;
        fp_op        = 3'b000;
        fp_load      = 1'b0;
        fp_store     = 1'b0;

        case (opcode)

            OP_R: begin
                reg_write = 1'b1;

                case ({funct7, funct3})
                    10'b0000000_000: alu_op = 4'b0000;
                    10'b0100000_000: alu_op = 4'b0001;
                    10'b0000000_111: alu_op = 4'b0010;
                    10'b0000000_110: alu_op = 4'b0011;
                    10'b0000000_100: alu_op = 4'b0100;
                    10'b0000000_001: alu_op = 4'b0101;
                    10'b0000000_101: alu_op = 4'b0110;
                    10'b0100000_101: alu_op = 4'b0111;
                    10'b0000000_010: alu_op = 4'b1000;
                    10'b0000000_011: alu_op = 4'b1001;
                    default: reg_write = 1'b0;
                endcase
            end

            OP_IMM: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm       = imm_i;

                case (funct3)
                    3'b000: alu_op = 4'b0000;
                    3'b111: alu_op = 4'b0010;
                    3'b110: alu_op = 4'b0011;
                    3'b100: alu_op = 4'b0100;
                    3'b010: alu_op = 4'b1000;
                    3'b011: alu_op = 4'b1001;
                    3'b001: alu_op = 4'b0101;
                    3'b101: alu_op =
                        instr[30] ? 4'b0111 : 4'b0110;
                    default: reg_write = 1'b0;
                endcase
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                imm        = imm_i;
            end

            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                imm       = imm_s;
            end

            OP_BR: begin
                branch = 1'b1;
                alu_op = 4'b0001;
                imm    = imm_b;
            end

            OP_JAL: begin
                reg_write = 1'b1;
                is_jal    = 1'b1;
                imm       = imm_j;
            end

            OP_JALR: begin
                reg_write = 1'b1;
                is_jalr   = 1'b1;
                alu_src   = 1'b1;
                imm       = imm_i;
            end

            OP_LUI: begin
                reg_write = 1'b1;
                is_lui    = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 4'b1010;
                imm       = imm_u;
            end

            OP_AUI: begin
                reg_write = 1'b1;
                is_auipc  = 1'b1;
                alu_src   = 1'b1;
                imm       = imm_u;
            end

            OP_FLW: begin
                fp_load = 1'b1;
                mem_read = 1'b1;
                alu_src = 1'b1;
                imm = imm_i;
            end

            OP_FSW: begin
                fp_store = 1'b1;
                mem_write = 1'b1;
                alu_src = 1'b1;
                imm = imm_s;
            end

            OP_FP: begin
                case (funct7)
                    7'b0000000: begin
                        is_fp = 1'b1;
                        fp_reg_write = 1'b1;
                        fp_op = 3'b000;
                    end

                    7'b0000100: begin
                        is_fp = 1'b1;
                        fp_reg_write = 1'b1;
                        fp_op = 3'b001;
                    end

                    7'b0001000: begin
                        is_fp = 1'b1;
                        fp_reg_write = 1'b1;
                        fp_op = 3'b010;
                    end

                    7'b0001100: begin
                        is_fp = 1'b1;
                        fp_reg_write = 1'b1;
                        fp_op = 3'b011;
                    end

                    default: begin
                        is_fp = 1'b0;
                        fp_reg_write = 1'b0;
                    end
                endcase
            end

            default: begin
            end

        endcase
    end

endmodule
