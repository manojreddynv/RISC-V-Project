
`timescale 1ns/1ps

// IEEE-754 binary32 floating-point multiplier
// Round-to-nearest, ties-to-even
module fpu_mul (
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] result
);

    reg sign_r;
    reg [7:0] ea, eb;
    reg [22:0] fa, fb;
    reg [23:0] mA, mB;
    reg [47:0] product;
    reg [23:0] sig24;
    reg [24:0] rounded_sig;
    reg g, r, s;
    reg [7:0] exp_encoded;

    integer expa, expb;
    integer unbiased;
    integer shift;
    integer i, k;

    reg [47:0] shifted_product;
    reg sticky;
    reg [24:0] rnd;

    always @* begin
        // Default values
        result          = 32'h00000000;
        sign_r          = A[31] ^ B[31];
        ea              = A[30:23];
        eb              = B[30:23];
        fa              = A[22:0];
        fb              = B[22:0];

        mA              = 24'b0;
        mB              = 24'b0;
        product         = 48'b0;
        sig24           = 24'b0;
        rounded_sig     = 25'b0;
        g               = 1'b0;
        r               = 1'b0;
        s               = 1'b0;
        exp_encoded     = 8'b0;
        expa            = 0;
        expb            = 0;
        unbiased        = 0;
        shift           = 0;
        shifted_product = 48'b0;
        sticky          = 1'b0;
        rnd             = 25'b0;

        if ((ea == 8'hFF && fa != 0) ||
            (eb == 8'hFF && fb != 0)) begin

            // NaN
            result = 32'h7FC00000;

        end else if (
            (ea == 8'hFF && fa == 0 && eb == 0 && fb == 0) ||
            (eb == 8'hFF && fb == 0 && ea == 0 && fa == 0)
        ) begin

            // Infinity multiplied by zero
            result = 32'h7FC00000;

        end else if (ea == 8'hFF || eb == 8'hFF) begin

            // Infinity
            result = {sign_r, 8'hFF, 23'b0};

        end else if (
            (ea == 0 && fa == 0) ||
            (eb == 0 && fb == 0)
        ) begin

            // Zero
            result = {sign_r, 31'b0};

        end else begin

            // Normalize operand A
            if (ea == 0) begin
                mA   = {1'b0, fa};
                expa = -126;

                for (i = 0; i < 24; i = i + 1) begin
                    if (mA[23] == 1'b0) begin
                        mA   = mA << 1;
                        expa = expa - 1;
                    end
                end
            end else begin
                mA   = {1'b1, fa};
                expa = ea - 127;
            end

            // Normalize operand B
            if (eb == 0) begin
                mB   = {1'b0, fb};
                expb = -126;

                for (i = 0; i < 24; i = i + 1) begin
                    if (mB[23] == 1'b0) begin
                        mB   = mB << 1;
                        expb = expb - 1;
                    end
                end
            end else begin
                mB   = {1'b1, fb};
                expb = eb - 127;
            end

            // 24 x 24 bit significand multiplication
            product = mA * mB;
            unbiased = expa + expb;

            // Normalize product and extract rounding bits
            if (product[47]) begin
                sig24   = product[47:24];
                g       = product[23];
                r       = product[22];
                s       = |product[21:0];
                unbiased = unbiased + 1;
            end else begin
                sig24 = product[46:23];
                g     = product[22];
                r     = product[21];
                s     = |product[20:0];
            end

            // Round to nearest, ties to even
            rounded_sig = {1'b0, sig24};

            if (g && (r || s || sig24[0]))
                rounded_sig = rounded_sig + 25'd1;

            // Handle rounding overflow
            if (rounded_sig[24]) begin
                rounded_sig = rounded_sig >> 1;
                unbiased = unbiased + 1;
            end

            sig24 = rounded_sig[23:0];

            // Overflow to infinity
            if (unbiased > 127) begin
                result = {sign_r, 8'hFF, 23'b0};

            end else if (unbiased >= -126) begin

                // Normal result
                exp_encoded = unbiased + 127;
                result = {sign_r, exp_encoded, sig24[22:0]};

            end else begin

                // Subnormal result
                shift = -126 - unbiased;

                if (shift >= 25) begin
                    result = {sign_r, 31'b0};
                end else begin

                    shifted_product = {sig24, 24'b0};
                    sticky = 1'b0;

                    for (k = 0; k < 24; k = k + 1) begin
                        if (k < shift) begin
                            sticky = sticky | shifted_product[0];
                            shifted_product = shifted_product >> 1;
                        end
                    end

                    rnd = {1'b0, shifted_product[24:1]};

                    if (shifted_product[0] &&
                        (sticky || shifted_product[1]))
                        rnd = rnd + 25'd1;

                    if (rnd[24])
                        result = {sign_r, 8'h01, rnd[22:0]};
                    else if (rnd[23])
                        result = {sign_r, 8'h01, rnd[22:0]};
                    else
                        result = {sign_r, 8'h00, rnd[22:0]};

                end
            end
        end
    end

endmodule
