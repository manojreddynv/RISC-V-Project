`timescale 1ns / 1ps

module tb_core_verify;

reg clk;
    reg rst_n;

    wire [7:0] dbg_status;

integer errors;
    integer tests;

integer cycle_count;
integer retired_count;
real ipc;
// =====================================
    // DUT: RISC-V PROCESSOR
    // =====================================
    core_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .dbg_status (dbg_status)
    );

// =====================================
    // 100 MHz CLOCK: 10 ns PERIOD
    // =====================================
    initial clk = 1'b0;
    always #5 clk = ~clk;

initial begin
    cycle_count   = 0;
    retired_count = 0;
end
always @(posedge clk) begin
    if (!rst_n) begin
        cycle_count   <= 0;
        retired_count <= 0;
    end
    else begin
        cycle_count <= cycle_count + 1;

        if (dut.valid_wb)
            retired_count <= retired_count + 1;
    end
end
// =====================================
    // INTEGER REGISTER CHECK
    // =====================================
    task check_int;
        input [4:0]  reg_num;
        input [31:0] expected;
        reg   [31:0] actual;
        begin
            tests = tests + 1;
            actual = dut.u_regfile.regs[reg_num];

if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL x%0d: expected %h, got %h",
                    reg_num, expected, actual
                );
            end
            else begin
                $display("PASS x%0d = %h", reg_num, actual);
            end
        end
    endtask

// =====================================
    // FLOATING-POINT REGISTER CHECK
    // =====================================
    task check_fp;
        input [4:0]  reg_num;
        input [31:0] expected;
        reg   [31:0] actual;
        begin
            tests = tests + 1;
            actual = dut.u_fp_regfile.regs[reg_num];

if (actual !== expected) begin
                errors = errors + 1;
                $display(
                    "FAIL f%0d: expected %h, got %h",
                    reg_num, expected, actual
                );
            end
            else begin
                $display("PASS f%0d = %h", reg_num, actual);
            end
        end
    endtask

// =====================================
    // MAIN TEST SEQUENCE
    // =====================================
    initial begin
        errors = 0;
        tests  = 0;
        rst_n  = 1'b0;

// Hold reset for three clock cycles
        repeat (3) @(posedge clk);

// Release reset away from the rising edge
        @(negedge clk);
        rst_n = 1'b1;

// Allow instructions to execute and retire
        repeat (80) @(posedge clk);
        #1;

// =====================================
        // INTEGER ALU RESULTS
        // =====================================
        $display("\n========== INTEGER ALU TESTS ==========");

check_int(1,  32'hFFFFFFFB); // x1  = -5
        check_int(2,  32'h00000003); // x2  =  3
        check_int(3,  32'hFFFFFFFE); // ADD
        check_int(4,  32'hFFFFFFF8); // SUB
        check_int(5,  32'h00000003); // AND
        check_int(6,  32'hFFFFFFFB); // OR
        check_int(7,  32'hFFFFFFF8); // XOR
        check_int(8,  32'hFFFFFFD8); // SLL
        check_int(9,  32'h1FFFFFFF); // SRL
        check_int(10, 32'hFFFFFFFF); // SRA
        check_int(11, 32'h00000001); // SLT
        check_int(12, 32'h00000000); // SLTU
        check_int(13, 32'h00000001); // SLTI
        check_int(14, 32'h00000000); // SLTIU
        check_int(15, 32'hFFFFFFF4); // XORI
        check_int(16, 32'hFFFFFFFB); // ORI
        check_int(17, 32'h0000000B); // ANDI
        check_int(18, 32'h0000000C); // SLLI
        check_int(19, 32'h3FFFFFFE); // SRLI
        check_int(20, 32'hFFFFFFFE); // SRAI
        check_int(21, 32'h12345000); // LUI

// =====================================
        // FLOATING-POINT RESULTS
        // =====================================
        $display("\n========== FLOATING-POINT TESTS ==========");

check_fp(3, 32'h40400000); // 1.0 + 2.0 = 3.0
        check_fp(4, 32'hBF800000); // 1.0 - 2.0 = -1.0
        check_fp(5, 32'h40000000); // 1.0 * 2.0 = 2.0
        check_fp(6, 32'h3F000000); // 1.0 / 2.0 = 0.5

// =====================================
        // FINAL SUMMARY
        // =====================================
        $display("\n========== SUMMARY ==========");
        $display("Total checks: %0d", tests);
        $display("Passed:       %0d", tests - errors);
        $display("Failed:       %0d", errors);

if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("VERIFICATION FAILED");


#1;

ipc = retired_count * 1.0 / cycle_count;

$display("--------------------------------");
$display("Clock cycles          = %0d", cycle_count);
$display("Instructions retired  = %0d", retired_count);
$display("IPC                   = %0.3f", ipc);
$display("--------------------------------");
$finish;
    end

endmodule
