
`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// FPU Special Case Handler
//
// Operation:
// 00 = ADD
// 01 = SUB
// 10 = MUL
// 11 = DIV
//
// IEEE-754 special cases:
// Zero
// Infinity
// NaN
//////////////////////////////////////////////////////////////////////////////////

module fpu_special_handler (

    input  [31:0] A,
    input  [31:0] B,

    input         sub,
    input  [1:0]  operation,

    input         A_is_zero,
    input         B_is_zero,

    input         A_is_inf,
    input         B_is_inf,

    input         A_is_nan,
    input         B_is_nan,

    output reg        special_valid,
    output reg [31:0] special_result
);


    // ============================================================
    // SPECIAL CASE LOGIC
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // Default
        // --------------------------------------------------------

        special_valid  = 1'b0;
        special_result = 32'b0;


        // ========================================================
        // 1. NaN
        // ========================================================

        if (A_is_nan || B_is_nan) begin

            special_valid  = 1'b1;
            special_result = 32'h7FC00000;

        end


        // ========================================================
        // 2. ADD / SUB
        // ========================================================

        else if ((operation == 2'b00) ||
                 (operation == 2'b01)) begin


            // ----------------------------------------------------
            // A = Infinity
            // ----------------------------------------------------

            if (A_is_inf) begin

                // A = Inf, B = Inf
                if (B_is_inf) begin

                    // ADD
                    if (operation == 2'b00) begin

                        // +Inf + +Inf = +Inf
                        // -Inf + -Inf = -Inf

                        if (A[31] == B[31]) begin
                            special_result = A;
                        end

                        // +Inf + -Inf = NaN
                        else begin
                            special_result = 32'h7FC00000;
                        end

                    end

                    // SUB
                    else begin

                        // Inf - Inf with same sign = NaN
                        if (A[31] == B[31]) begin
                            special_result = 32'h7FC00000;
                        end

                        // Inf - (-Inf) = Inf
                        else begin
                            special_result = A;
                        end

                    end

                    special_valid = 1'b1;

                end

                // A = Inf, B = finite
                else begin

                    special_valid  = 1'b1;
                    special_result = A;

                end

            end


            // ----------------------------------------------------
            // B = Infinity
            // ----------------------------------------------------

            else if (B_is_inf) begin

                special_valid = 1'b1;

                // A + Inf = Inf
                // A - Inf = -Inf
                if (operation == 2'b01) begin

                    special_result = {
                        ~B[31],
                        B[30:0]
                    };

                end
                else begin

                    special_result = B;

                end

            end


            // ----------------------------------------------------
            // A = Zero
            // ----------------------------------------------------

            else if (A_is_zero) begin

                special_valid = 1'b1;

                // 0 + B = B
                // 0 - B = -B
                if (B_is_zero) begin

                    special_result = 32'b0;

                end
                else begin

                    if (operation == 2'b01) begin

                        special_result = {
                            ~B[31],
                            B[30:0]
                        };

                    end
                    else begin

                        special_result = B;

                    end

                end

            end


            // ----------------------------------------------------
            // B = Zero
            // ----------------------------------------------------

            else if (B_is_zero) begin

                special_valid = 1'b1;

                // A + 0 = A
                // A - 0 = A

                special_result = A;

            end

        end


        // ========================================================
        // 3. MULTIPLICATION
        // ========================================================

        else if (operation == 2'b10) begin


            // ----------------------------------------------------
            // Infinity × Zero = NaN
            // ----------------------------------------------------

            if ((A_is_inf && B_is_zero) ||
                (A_is_zero && B_is_inf)) begin

                special_valid  = 1'b1;
                special_result = 32'h7FC00000;

            end


            // ----------------------------------------------------
            // Infinity × finite = Infinity
            // ----------------------------------------------------

            else if (A_is_inf || B_is_inf) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    8'hFF,
                    23'b0
                };

            end


            // ----------------------------------------------------
            // Zero × finite = Zero
            // ----------------------------------------------------

            else if (A_is_zero || B_is_zero) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    31'b0
                };

            end

        end


        // ========================================================
        // 4. DIVISION
        // ========================================================

        else if (operation == 2'b11) begin


            // ----------------------------------------------------
            // Zero / Zero = NaN
            // ----------------------------------------------------

            if (A_is_zero && B_is_zero) begin

                special_valid  = 1'b1;
                special_result = 32'h7FC00000;

            end


            // ----------------------------------------------------
            // Infinity / Infinity = NaN
            // ----------------------------------------------------

            else if (A_is_inf && B_is_inf) begin

                special_valid  = 1'b1;
                special_result = 32'h7FC00000;

            end


            // ----------------------------------------------------
            // Infinity / finite = Infinity
            // ----------------------------------------------------

            else if (A_is_inf) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    8'hFF,
                    23'b0
                };

            end


            // ----------------------------------------------------
            // finite / Infinity = Zero
            // ----------------------------------------------------

            else if (B_is_inf) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    31'b0
                };

            end


            // ----------------------------------------------------
            // finite / Zero = Infinity
            // ----------------------------------------------------

            else if (B_is_zero) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    8'hFF,
                    23'b0
                };

            end


            // ----------------------------------------------------
            // Zero / finite = Zero
            // ----------------------------------------------------

            else if (A_is_zero) begin

                special_valid = 1'b1;

                special_result = {
                    A[31] ^ B[31],
                    31'b0
                };

            end

        end

    end

endmodule
