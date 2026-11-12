`timescale 1ns/1ps

module core_top (
    input  wire clk,
    input  wire rst_n,
    output wire [7:0] dbg_status
);

    // ============================================================
    // IF STAGE
    // ============================================================
    reg  [31:0] pc_if;
    wire [31:0] instr_if;

    wire stall;
    wire pc_redirect;
    wire [31:0] redirect_target;

    imem u_imem (
        .addr  (pc_if),
        .rdata (instr_if)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_if <= 32'h00000000;
        else if (pc_redirect)
            pc_if <= redirect_target;
        else if (!stall)
            pc_if <= pc_if + 32'd4;
    end

    // ============================================================
    // IF / ID PIPELINE REGISTER
    // ============================================================
    reg [31:0] pc_id;
    reg [31:0] instr_id;
    reg        valid_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_id    <= 32'b0;
            instr_id <= 32'h00000013;
            valid_id <= 1'b0;
        end else if (pc_redirect) begin
            pc_id    <= 32'b0;
            instr_id <= 32'h00000013;
            valid_id <= 1'b0;
        end else if (!stall) begin
            pc_id    <= pc_if;
            instr_id <= instr_if;
            valid_id <= (pc_if < 32'd112);
        end
    end

    // ============================================================
    // ID STAGE / DECODER
    // ============================================================
    wire [6:0] opcode_id;
    wire [4:0] rd_id, rs1_id, rs2_id;
    wire [2:0] funct3_id;
    wire [6:0] funct7_id;
    wire [31:0] imm_id;

    wire reg_write_id;
    wire mem_read_id;
    wire mem_write_id;
    wire mem_to_reg_id;
    wire alu_src_id;
    wire branch_id;
    wire is_jal_id;
    wire is_jalr_id;
    wire is_lui_id;
    wire is_auipc_id;
    wire [3:0] alu_op_id;
    wire [2:0] branch_type_id;

    wire is_fp_id;
    wire fp_reg_write_id;
    wire [2:0] fp_op_id;
    wire fp_load_id;
    wire fp_store_id;

    decoder u_decoder (
        .instr       (instr_id),
        .opcode      (opcode_id),
        .rd          (rd_id),
        .rs1         (rs1_id),
        .rs2         (rs2_id),
        .funct3      (funct3_id),
        .funct7      (funct7_id),
        .imm         (imm_id),

        .reg_write   (reg_write_id),
        .mem_read    (mem_read_id),
        .mem_write   (mem_write_id),
        .mem_to_reg  (mem_to_reg_id),
        .alu_src     (alu_src_id),
        .branch      (branch_id),
        .is_jal      (is_jal_id),
        .is_jalr     (is_jalr_id),
        .is_lui      (is_lui_id),
        .is_auipc    (is_auipc_id),
        .alu_op      (alu_op_id),
        .branch_type (branch_type_id),

        .is_fp        (is_fp_id),
        .fp_reg_write (fp_reg_write_id),
        .fp_op        (fp_op_id),
        .fp_load      (fp_load_id),
        .fp_store     (fp_store_id)
    );

    // ============================================================
    // INTEGER REGISTER FILE
    // ============================================================
    wire [31:0] rs1_data_id;
    wire [31:0] rs2_data_id;

    wire        rf_write_wb;
    wire [4:0]  rf_rd_wb;
    wire [31:0] rf_wdata_wb;

    regfile u_regfile (
        .clk      (clk),
        .we       (rf_write_wb),
        .rs1_addr (rs1_id),
        .rs2_addr (rs2_id),
        .rd_addr  (rf_rd_wb),
        .rd_data  (rf_wdata_wb),
        .rs1_data (rs1_data_id),
        .rs2_data (rs2_data_id)
    );

    // ============================================================
    // FLOATING-POINT REGISTER FILE
    // ============================================================
    wire [31:0] fp_rs1_data_id;
    wire [31:0] fp_rs2_data_id;

    reg        fp_reg_write_wb;
    reg [4:0]  fp_rd_wb;
    reg [31:0] fp_wdata_wb;

    fp_regfile u_fp_regfile (
        .clk      (clk),
        .we       (fp_reg_write_wb),
        .rs1_addr (rs1_id),
        .rs2_addr (rs2_id),
        .rd_addr  (fp_rd_wb),
        .rd_data  (fp_wdata_wb),
        .rs1_data (fp_rs1_data_id),
        .rs2_data (fp_rs2_data_id)
    );

    // ============================================================
    // ID / EX PIPELINE REGISTER
    // ============================================================
    reg [31:0] pc_ex;
    reg [31:0] rs1_data_ex, rs2_data_ex, imm_ex;
    reg [4:0]  rs1_ex, rs2_ex, rd_ex;

    reg reg_write_ex;
    reg mem_read_ex;
    reg mem_write_ex;
    reg mem_to_reg_ex;
    reg alu_src_ex;
    reg branch_ex;
    reg is_jal_ex;
    reg is_jalr_ex;
    reg is_auipc_ex;

    reg [3:0] alu_op_ex;
    reg [2:0] branch_type_ex;
    reg valid_ex;

    // FP pipeline state
    reg [31:0] fp_rs1_data_ex;
    reg [31:0] fp_rs2_data_ex;
    reg [2:0]  fp_op_ex;
    reg [4:0]  fp_rd_ex;
    reg        fp_reg_write_ex;

    // NEW: FP instruction-type tracking in EX
    reg is_fp_ex;

    // NEW: Dynamic execution-unit selection
    wire alu_enable_ex =
        valid_ex && !is_fp_ex;

    wire fpu_enable_ex =
        valid_ex && is_fp_ex && fp_reg_write_ex;

    // ============================================================
    // HAZARD TRACKING
    // ============================================================
    reg mem_read_ex_r;
    reg [4:0] rd_ex_r;

    reg [4:0] fp_rd_mem;
    reg       fp_reg_write_mem;
    reg [4:0] fp_rd_wb_track;
    reg       fp_reg_write_wb_track;

    wire int_load_hazard =
        mem_read_ex_r &&
        (rd_ex_r != 5'd0) &&
        ((rd_ex_r == rs1_id) || (rd_ex_r == rs2_id)) &&
        valid_id &&
        !is_fp_id;

    wire fp_hazard =
        is_fp_id &&
        valid_id &&
        (
            fp_reg_write_ex ||
            fp_reg_write_mem ||
            fp_reg_write_wb_track
        );

    assign stall = int_load_hazard || fp_hazard;

    wire bubble_ex = pc_redirect || stall || !valid_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_ex             <= 32'b0;
            rs1_data_ex       <= 32'b0;
            rs2_data_ex       <= 32'b0;
            imm_ex            <= 32'b0;
            rs1_ex            <= 5'b0;
            rs2_ex            <= 5'b0;
            rd_ex             <= 5'b0;

            reg_write_ex      <= 1'b0;
            mem_read_ex       <= 1'b0;
            mem_write_ex      <= 1'b0;
            mem_to_reg_ex     <= 1'b0;
            alu_src_ex        <= 1'b0;
            branch_ex         <= 1'b0;
            is_jal_ex         <= 1'b0;
            is_jalr_ex        <= 1'b0;
            is_auipc_ex       <= 1'b0;
            alu_op_ex         <= 4'b0;
            branch_type_ex    <= 3'b0;
            valid_ex          <= 1'b0;

            is_fp_ex          <= 1'b0;

            fp_rs1_data_ex    <= 32'b0;
            fp_rs2_data_ex    <= 32'b0;
            fp_op_ex          <= 3'b0;
            fp_rd_ex          <= 5'b0;
            fp_reg_write_ex   <= 1'b0;

            mem_read_ex_r     <= 1'b0;
            rd_ex_r           <= 5'b0;
        end else if (bubble_ex) begin
            reg_write_ex      <= 1'b0;
            mem_read_ex       <= 1'b0;
            mem_write_ex      <= 1'b0;
            mem_to_reg_ex     <= 1'b0;
            branch_ex         <= 1'b0;
            is_jal_ex         <= 1'b0;
            is_jalr_ex        <= 1'b0;
            valid_ex          <= 1'b0;

            is_fp_ex          <= 1'b0;
            fp_reg_write_ex   <= 1'b0;

            mem_read_ex_r     <= 1'b0;
            rd_ex_r           <= 5'b0;
        end else begin
            pc_ex          <= pc_id;
            rs1_data_ex    <= rs1_data_id;
            rs2_data_ex    <= rs2_data_id;
            imm_ex         <= imm_id;
            rs1_ex         <= rs1_id;
            rs2_ex         <= rs2_id;
            rd_ex          <= rd_id;

            reg_write_ex   <= reg_write_id;
            mem_read_ex    <= mem_read_id;
            mem_write_ex   <= mem_write_id;
            mem_to_reg_ex  <= mem_to_reg_id;
            alu_src_ex     <= alu_src_id;
            branch_ex      <= branch_id;
            is_jal_ex      <= is_jal_id;
            is_jalr_ex     <= is_jalr_id;
            is_auipc_ex    <= is_auipc_id;
            alu_op_ex      <= alu_op_id;
            branch_type_ex <= branch_type_id;
            valid_ex       <= valid_id;

            // NEW: carry FP classification into EX
            is_fp_ex       <= is_fp_id && valid_id;

            fp_rs1_data_ex  <= fp_rs1_data_id;
            fp_rs2_data_ex  <= fp_rs2_data_id;
            fp_op_ex        <= fp_op_id;
            fp_rd_ex        <= rd_id;
            fp_reg_write_ex <= fp_reg_write_id && valid_id;

            mem_read_ex_r <= mem_read_id;
            rd_ex_r       <= rd_id;
        end
    end

    // ============================================================
    // EX STAGE: INTEGER ALU AND FORWARDING
    // ============================================================
    reg [31:0] alu_result_mem_r;
    reg [4:0]  rd_mem_r;
    reg        reg_write_mem_r;

    reg [31:0] wb_data_r;
    reg [4:0]  rd_wb_r;
    reg        reg_write_wb_r;

    reg [1:0] fwd_a, fwd_b;

    localparam FWD_NONE = 2'b00;
    localparam FWD_MEM  = 2'b01;
    localparam FWD_WB   = 2'b10;

    always @(*) begin
        if (reg_write_mem_r && (rd_mem_r != 5'd0) &&
            (rd_mem_r == rs1_ex))
            fwd_a = FWD_MEM;
        else if (reg_write_wb_r && (rd_wb_r != 5'd0) &&
                 (rd_wb_r == rs1_ex))
            fwd_a = FWD_WB;
        else
            fwd_a = FWD_NONE;

        if (reg_write_mem_r && (rd_mem_r != 5'd0) &&
            (rd_mem_r == rs2_ex))
            fwd_b = FWD_MEM;
        else if (reg_write_wb_r && (rd_wb_r != 5'd0) &&
                 (rd_wb_r == rs2_ex))
            fwd_b = FWD_WB;
        else
            fwd_b = FWD_NONE;
    end

    wire [31:0] op1 =
        (fwd_a == FWD_MEM) ? alu_result_mem_r :
        (fwd_a == FWD_WB)  ? wb_data_r :
                             rs1_data_ex;

    wire [31:0] op2 =
        (fwd_b == FWD_MEM) ? alu_result_mem_r :
        (fwd_b == FWD_WB)  ? wb_data_r :
                             rs2_data_ex;

    // Raw ALU operands
    wire [31:0] alu_in_a_raw =
        is_auipc_ex ? pc_ex : op1;

    wire [31:0] alu_in_b_raw =
        alu_src_ex ? imm_ex : op2;

    // NEW: ALU operand isolation
    wire [31:0] alu_in_a =
        alu_enable_ex ? alu_in_a_raw : 32'b0;

    wire [31:0] alu_in_b =
        alu_enable_ex ? alu_in_b_raw : 32'b0;

    wire [3:0] alu_op_active =
        alu_enable_ex ? alu_op_ex : 4'b0000;

    wire [31:0] alu_result_raw;
    wire alu_zero;

    alu u_alu (
        .a      (alu_in_a),
        .b      (alu_in_b),
        .alu_op (alu_op_active),
        .result (alu_result_raw),
        .zero   (alu_zero)
    );

    wire [31:0] alu_result_ex =
        (is_jal_ex || is_jalr_ex) ?
        (pc_ex + 32'd4) : alu_result_raw;

    reg branch_cond;

    always @(*) begin
        case (branch_type_ex)
            3'b000: branch_cond = (op1 == op2);
            3'b001: branch_cond = (op1 != op2);
            3'b100: branch_cond = ($signed(op1) < $signed(op2));
            3'b101: branch_cond = ($signed(op1) >= $signed(op2));
            3'b110: branch_cond = (op1 < op2);
            3'b111: branch_cond = (op1 >= op2);
            default: branch_cond = 1'b0;
        endcase
    end

    wire branch_taken = branch_ex && branch_cond;
    wire jump_taken = is_jal_ex || is_jalr_ex;

    assign pc_redirect =
        valid_ex && (branch_taken || jump_taken);

    assign redirect_target =
        is_jalr_ex ? ((op1 + imm_ex) & 32'hFFFFFFFE) :
                     (pc_ex + imm_ex);

    // ============================================================
    // EX STAGE: FLOATING-POINT UNIT
    // ============================================================
    wire [31:0] fp_result_ex;

    // NEW: FPU operand isolation
    wire [31:0] fpu_operand_a =
        fpu_enable_ex ? fp_rs1_data_ex : 32'b0;

    wire [31:0] fpu_operand_b =
        fpu_enable_ex ? fp_rs2_data_ex : 32'b0;

    wire [2:0] fpu_operation_active =
        fpu_enable_ex ? fp_op_ex : 3'b000;

    fpu_core u_fpu_core (
        .A         (fpu_operand_a),
        .B         (fpu_operand_b),
        .operation (fpu_operation_active),
        .result    (fp_result_ex)
    );

    // ============================================================
    // EX / MEM PIPELINE REGISTER
    // ============================================================
    reg [31:0] alu_result_ex_mem;
    reg [31:0] store_data_mem;
    reg [4:0]  rd_mem;
    reg valid_mem;

    reg reg_write_mem;
    reg mem_read_mem;
    reg mem_write_mem;
    reg mem_to_reg_mem;

    reg [31:0] fp_result_mem;
    reg [4:0]  fp_rd_mem_reg;
    reg        fp_write_mem_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_ex_mem <= 32'b0;
            store_data_mem    <= 32'b0;
            rd_mem            <= 5'b0;
            valid_mem <= 1'b0;

            reg_write_mem     <= 1'b0;
            mem_read_mem      <= 1'b0;
            mem_write_mem     <= 1'b0;
            mem_to_reg_mem    <= 1'b0;

            fp_result_mem     <= 32'b0;
            fp_rd_mem_reg     <= 5'b0;
            fp_write_mem_reg  <= 1'b0;

            fp_rd_mem         <= 5'b0;
            fp_reg_write_mem  <= 1'b0;
        end else begin
            alu_result_ex_mem <= alu_result_ex;
            store_data_mem    <= op2;
            rd_mem            <= rd_ex;
            valid_mem <= valid_ex;

            reg_write_mem  <= reg_write_ex && valid_ex;
            mem_read_mem   <= mem_read_ex && valid_ex;
            mem_write_mem  <= mem_write_ex && valid_ex;
            mem_to_reg_mem <= mem_to_reg_ex;

            fp_result_mem    <= fp_result_ex;
            fp_rd_mem_reg    <= fp_rd_ex;
            fp_write_mem_reg <= fp_reg_write_ex && valid_ex;

            fp_rd_mem        <= fp_rd_ex;
            fp_reg_write_mem <= fp_reg_write_ex && valid_ex;
        end
    end

    always @(*) begin
        alu_result_mem_r = alu_result_ex_mem;
        rd_mem_r         = rd_mem;
        reg_write_mem_r  = reg_write_mem;
    end

    // ============================================================
    // MEM STAGE
    // ============================================================
    wire [31:0] dmem_rdata;

    dmem u_dmem (
        .clk       (clk),
        .mem_read  (mem_read_mem),
        .mem_write (mem_write_mem),
        .addr      (alu_result_ex_mem),
        .wdata     (store_data_mem),
        .rdata     (dmem_rdata)
    );

    // ============================================================
    // MEM / WB PIPELINE REGISTER
    // ============================================================
    reg [31:0] alu_result_wb;
    reg [31:0] mem_data_wb;
    reg [4:0]  rd_wb;
    reg valid_wb;

    reg reg_write_wb;
    reg mem_to_reg_wb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_wb         <= 32'b0;
            mem_data_wb           <= 32'b0;
            rd_wb                 <= 5'b0;
            reg_write_wb          <= 1'b0;
            mem_to_reg_wb         <= 1'b0;
            valid_wb <= 1'b0;

            fp_wdata_wb           <= 32'b0;
            fp_rd_wb              <= 5'b0;
            fp_reg_write_wb       <= 1'b0;
            fp_rd_wb_track        <= 5'b0;
            fp_reg_write_wb_track <= 1'b0;
        end else begin
            alu_result_wb <= alu_result_ex_mem;
            mem_data_wb   <= dmem_rdata;
            rd_wb         <= rd_mem;
            reg_write_wb  <= reg_write_mem;
            mem_to_reg_wb <= mem_to_reg_mem;
            valid_wb <= valid_mem;

            fp_wdata_wb     <= fp_result_mem;
            fp_rd_wb        <= fp_rd_mem_reg;
            fp_reg_write_wb <= fp_write_mem_reg;

            fp_rd_wb_track        <= fp_rd_mem_reg;
            fp_reg_write_wb_track <= fp_write_mem_reg;
        end
    end

    always @(*) begin
        wb_data_r      = mem_to_reg_wb ? mem_data_wb : alu_result_wb;
        rd_wb_r        = rd_wb;
        reg_write_wb_r = reg_write_wb;
    end

    // ============================================================
    // INTEGER WRITEBACK
    // ============================================================
    assign rf_write_wb = reg_write_wb;
    assign rf_rd_wb    = rd_wb;
    assign rf_wdata_wb =
        mem_to_reg_wb ? mem_data_wb : alu_result_wb;

    // ============================================================
    // DEBUG OUTPUT
    // ============================================================
    wire [31:0] probe_pc    = pc_if;
    wire [31:0] probe_instr = instr_id;
    wire [31:0] probe_alu   = alu_result_ex;
    wire [31:0] probe_wb    = rf_wdata_wb;

    assign dbg_status[0] = ^probe_pc;
    assign dbg_status[1] = ^probe_instr;
    assign dbg_status[2] = ^probe_alu;
    assign dbg_status[3] = ^probe_wb;
    assign dbg_status[4] = rf_write_wb;
    assign dbg_status[5] = ^(probe_pc ^ probe_instr);
    assign dbg_status[6] = ^(probe_alu ^ probe_wb);
    assign dbg_status[7] = valid_ex ^ valid_id ^ pc_redirect ^ stall;

endmodule
