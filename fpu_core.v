`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2026 12:23:56
// Design Name: 
// Module Name: fpu_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fpu_core (
    input  [31:0] A,
    input  [31:0] B,
    input  [2:0]  operation,
    output [31:0] result
);

    // ============================================================
    // RESULTS FROM FPU UNITS
    // ============================================================

    wire [31:0] addsub_result;
    wire [31:0] mul_result;
    wire [31:0] div_result;


    // ============================================================
    // SPECIAL CASE HANDLER
    // ============================================================

    wire        special_valid;
    wire [31:0] special_result;


    // ============================================================
    // IEEE-754 SPECIAL CASE DETECTION
    // ============================================================

    wire A_is_zero;
    wire B_is_zero;

    wire A_is_inf;
    wire B_is_inf;

    wire A_is_nan;
    wire B_is_nan;


    // ------------------------------------------------------------
    // ZERO DETECTION
    // Exponent = 0
    // Fraction = 0
    // ------------------------------------------------------------

    assign A_is_zero =
        (A[30:23] == 8'h00) &&
        (A[22:0]  == 23'b0);

    assign B_is_zero =
        (B[30:23] == 8'h00) &&
        (B[22:0]  == 23'b0);


    // ------------------------------------------------------------
    // INFINITY DETECTION
    // Exponent = FF
    // Fraction = 0
    // ------------------------------------------------------------

    assign A_is_inf =
        (A[30:23] == 8'hFF) &&
        (A[22:0]  == 23'b0);

    assign B_is_inf =
        (B[30:23] == 8'hFF) &&
        (B[22:0]  == 23'b0);


    // ------------------------------------------------------------
    // NaN DETECTION
    // Exponent = FF
    // Fraction != 0
    // ------------------------------------------------------------

    assign A_is_nan =
        (A[30:23] == 8'hFF) &&
        (A[22:0]  != 23'b0);

    assign B_is_nan =
        (B[30:23] == 8'hFF) &&
        (B[22:0]  != 23'b0);


    // ============================================================
    // ADD / SUB UNIT
    // ============================================================

    fpu_addsub u_addsub (
        .A      (A),
        .B      (B),
        .sub    (operation == 3'b001),
        .result (addsub_result)
    );


    // ============================================================
    // MULTIPLICATION UNIT
    // ============================================================

    fpu_mul u_mul (
        .A      (A),
        .B      (B),
        .result (mul_result)
    );


    // ============================================================
    // DIVISION UNIT
    // ============================================================

    fpu_div u_div (
        .A      (A),
        .B      (B),
        .result (div_result)
    );


    // ============================================================
    // SPECIAL CASE HANDLER
    // ============================================================

    fpu_special_handler u_special (
        .A             (A),
        .B             (B),

        .sub           (operation == 3'b001),
        .operation     (operation[1:0]),

        .A_is_zero     (A_is_zero),
        .B_is_zero     (B_is_zero),

        .A_is_inf      (A_is_inf),
        .B_is_inf      (B_is_inf),

        .A_is_nan      (A_is_nan),
        .B_is_nan      (B_is_nan),

        .special_valid (special_valid),
        .special_result(special_result)
    );


    // ============================================================
    // FINAL RESULT SELECTION
    // ============================================================

    assign result =
        // Special cases have highest priority
        special_valid ? special_result :

        // ADD
        (operation == 3'b000) ? addsub_result :

        // SUB
        (operation == 3'b001) ? addsub_result :

        // MUL
        (operation == 3'b010) ? mul_result :

        // DIV
        (operation == 3'b011) ? div_result :

        // Invalid operation
        32'b0;


endmodule


