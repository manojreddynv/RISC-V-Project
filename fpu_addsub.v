
module fpu_addsub (
    input  [31:0] A,
    input  [31:0] B,
    input         sub,       // 0 = ADD, 1 = SUB
    output reg [31:0] result
);

    // =========================================================
        // IEEE-754 fields
        // =========================================================

    wire sign_A;
    wire sign_B;

    wire [7:0] exp_A;
    wire [7:0] exp_B;

    wire [22:0] frac_A;
    wire [22:0] frac_B;

    assign sign_A = A[31];
    assign sign_B = B[31];

    assign exp_A  = A[30:23];
    assign exp_B  = B[30:23];

    assign frac_A = A[22:0];
    assign frac_B = B[22:0];


    // =========================================================
    // Special values
    // =========================================================

    wire A_zero;
    wire B_zero;

    wire A_inf;
    wire B_inf;

    wire A_nan;
    wire B_nan;

    assign A_zero = (exp_A == 8'h00) &&
                    (frac_A == 23'h000000);

    assign B_zero = (exp_B == 8'h00) &&
                    (frac_B == 23'h000000);

    assign A_inf = (exp_A == 8'hFF) &&
                   (frac_A == 23'h000000);

    assign B_inf = (exp_B == 8'hFF) &&
                   (frac_B == 23'h000000);

    assign A_nan = (exp_A == 8'hFF) &&
                   (frac_A != 23'h000000);

    assign B_nan = (exp_B == 8'hFF) &&
                   (frac_B != 23'h000000);


    // =========================================================
    // Internal signals
    // =========================================================

    reg [26:0] mant_A;
    reg [26:0] mant_B;

    reg [26:0] mant_large;
    reg [26:0] mant_small;

    reg [26:0] mant_small_shifted;

    reg [27:0] mant_result;

    reg [7:0] exponent_large;

    reg [7:0] exponent_result;

    reg sign_B_effective;

    reg result_sign;

    reg [7:0] exponent_difference;

    reg [23:0] significand;

    reg [24:0] rounded_significand;

    reg guard_bit;
    reg round_bit;
    reg sticky_bit;

    integer i;


    // =========================================================
    // Main operation
    // =========================================================

    always @(*) begin

        // -----------------------------------------------------
        // Default values
        // -----------------------------------------------------

        result = 32'b0;

        mant_A = 27'b0;
        mant_B = 27'b0;

        mant_large = 27'b0;
        mant_small = 27'b0;

        mant_small_shifted = 27'b0;

        mant_result = 28'b0;

        exponent_large = 8'b0;
        exponent_result = 8'b0;

        sign_B_effective = sign_B ^ sub;

        result_sign = 1'b0;

        exponent_difference = 8'b0;

        significand = 24'b0;
        rounded_significand = 25'b0;

        guard_bit = 1'b0;
        round_bit = 1'b0;
        sticky_bit = 1'b0;


        // =====================================================
        // NaN
        // =====================================================

        if (A_nan || B_nan) begin

            result = 32'h7FC00000;

        end


        // =====================================================
        // Infinity
        // =====================================================

        else if (A_inf || B_inf) begin

            // Inf + (-Inf) = NaN

            if (A_inf &&
                B_inf &&
                (sign_A != sign_B_effective)) begin

                result = 32'h7FC00000;

            end

            else if (A_inf) begin

                result = {
                    sign_A,
                    8'hFF,
                    23'b0
                };

            end

            else begin

                result = {
                    sign_B_effective,
                    8'hFF,
                    23'b0
                };

            end

        end


        // =====================================================
        // A = 0
        // =====================================================

        else if (A_zero) begin

            if (B_zero) begin

                result = 32'b0;

            end
            else begin

                result = {
                    sign_B_effective,
                    B[30:0]
                };

            end

        end


        // =====================================================
        // B = 0
        // =====================================================

        else if (B_zero) begin

            result = A;

        end


        // =====================================================
        // NORMAL NUMBERS
        // =====================================================

        else begin

            // -------------------------------------------------
            // Create 27-bit mantissas
            //
            // [26:3] = 24-bit significand
            // [2]    = Guard
            // [1]    = Round
            // [0]    = Sticky
            // -------------------------------------------------

            if (exp_A == 0) begin

                mant_A = {
                    1'b0,
                    frac_A,
                    3'b000
                };

            end
            else begin

                mant_A = {
                    1'b1,
                    frac_A,
                    3'b000
                };

            end


            if (exp_B == 0) begin

                mant_B = {
                    1'b0,
                    frac_B,
                    3'b000
                };

            end
            else begin

                mant_B = {
                    1'b1,
                    frac_B,
                    3'b000
                };

            end


            // =================================================
            // Find larger magnitude
            // =================================================
            //
            // IMPORTANT:
            // Compare exponent first.
            // If exponent is equal, compare mantissa.
            // =================================================

            if (exp_A > exp_B) begin

                mant_large = mant_A;
                mant_small = mant_B;

                exponent_large = exp_A;

                result_sign = sign_A;

            end

            else if (exp_B > exp_A) begin

                mant_large = mant_B;
                mant_small = mant_A;

                exponent_large = exp_B;

                result_sign = sign_B_effective;

            end

            else begin

                // Same exponent

                if (mant_A >= mant_B) begin

                    mant_large = mant_A;
                    mant_small = mant_B;

                    exponent_large = exp_A;

                    result_sign = sign_A;

                end
                else begin

                    mant_large = mant_B;
                    mant_small = mant_A;

                    exponent_large = exp_B;

                    result_sign = sign_B_effective;

                end

            end


            // =================================================
            // Calculate exponent difference
            // =================================================

            if (exp_A >= exp_B)
                exponent_difference = exp_A - exp_B;
            else
                exponent_difference = exp_B - exp_A;


            // =================================================
            // Align smaller mantissa
            // =================================================

            if (exponent_difference >= 27) begin

                mant_small_shifted = 27'b0;

                if (mant_small != 0)
                    mant_small_shifted[0] = 1'b1;

            end

            else begin

                mant_small_shifted =
                    mant_small >> exponent_difference;

                // ---------------------------------------------
                // Sticky bit
                // ---------------------------------------------

                sticky_bit = 1'b0;

                for (i = 0; i < 27; i = i + 1) begin

                    if ((i < exponent_difference) &&
                        mant_small[i]) begin

                        sticky_bit = 1'b1;

                    end

                end

                if (sticky_bit)
                    mant_small_shifted[0] = 1'b1;

            end


            // =================================================
            // ADD or SUBTRACT
            // =================================================

            if (sign_A == sign_B_effective) begin

                // Same signs
                //
                // +2.5 + +5.5
                // -2.5 + -5.5

                mant_result =
                    {1'b0, mant_large} +
                    {1'b0, mant_small_shifted};

            end

            else begin

                // Different signs
                //
                // +2.5 + -5.5
                //
                // = 5.5 - 2.5
                // = 3.0

                mant_result =
                    {1'b0, mant_large} -
                    {1'b0, mant_small_shifted};

            end


            // =================================================
            // Initial exponent
            // =================================================

            exponent_result = exponent_large;


            // =================================================
            // Exact zero
            // =================================================

            if (mant_result == 0) begin

                result = 32'b0;

            end

            else begin

                // =================================================
                // Addition normalization
                // =================================================

                if (mant_result[27]) begin

                    mant_result =
                        mant_result >> 1;

                    exponent_result =
                        exponent_result + 1'b1;

                end


                // =================================================
                // Subtraction normalization
                // =================================================

               for (i = 0; i < 27; i = i + 1) begin

    if ((mant_result[26] == 1'b0) &&
        (mant_result != 0) &&
        (exponent_result > 0)) begin

        mant_result = mant_result << 1;

        exponent_result = exponent_result - 1'b1;

    end

end


                // =================================================
                // Extract GRS bits
                // =================================================

                guard_bit =
                    mant_result[2];

                round_bit =
                    mant_result[1];

                sticky_bit =
                    mant_result[0];


                // =================================================
                // 24-bit significand
                // =================================================

                significand =
                    mant_result[26:3];


                // =================================================
                // Round to nearest even
                // =================================================

                rounded_significand =
                    {1'b0, significand};


                if (guard_bit &&
                    (round_bit ||
                     sticky_bit ||
                     significand[0])) begin

                    rounded_significand =
                        rounded_significand + 1'b1;

                end


                // =================================================
                // Rounding overflow
                // =================================================

                if (rounded_significand[24]) begin

                    rounded_significand =
                        rounded_significand >> 1;

                    exponent_result =
                        exponent_result + 1'b1;

                end


                // =================================================
                // Exponent overflow
                // =================================================

                if (exponent_result >= 8'hFF) begin

                    result = {
                        result_sign,
                        8'hFF,
                        23'b0
                    };

                end


                // =================================================
                // Normal result
                // =================================================

                else if (exponent_result != 0) begin

                    result = {
                        result_sign,
                        exponent_result,
                        rounded_significand[22:0]
                    };

                end


                // =================================================
                // Subnormal result
                // =================================================

                else begin

                    result = {
                        result_sign,
                        8'h00,
                        rounded_significand[22:0]
                    };

                end

            end

        end

    end

endmodule
