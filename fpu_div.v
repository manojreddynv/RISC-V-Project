
`timescale 1ns/1ps

// IEEE-754 binary32 floating-point divider
// Round-to-nearest, ties-to-even
module fpu_div (
    input  [31:0] A,
    input  [31:0] B,
    output reg [31:0] result
);

    reg [7:0] ea, eb;
    reg [22:0] fa, fb;
    reg [23:0] mA, mB;

    reg [63:0] numerator;
    reg [63:0] q;
    reg [63:0] remn;

    reg [23:0] sig;
    reg [24:0] rounded_sig;
    reg [24:0] rnd;

    reg sign_r;
    reg g, r, s;

    integer expa, expb;
    integer unbiased;
    integer shift;
    integer i;

    reg [7:0] exp_encoded;

    always @* begin
        // Defaults
        result       = 32'h00000000;
        ea            = A[30:23];
        eb            = B[30:23];
        fa            = A[22:0];
        fb            = B[22:0];
        sign_r        = A[31] ^ B[31];

        mA            = 24'b0;
        mB            = 24'b0;
        numerator     = 64'b0;
        q             = 64'b0;
        remn          = 64'b0;
        sig           = 24'b0;
        rounded_sig   = 25'b0;
        rnd           = 25'b0;

        expa          = 0;
        expb          = 0;
        unbiased      = 0;
        shift         = 0;
        i             = 0;

        g             = 1'b0;
        r             = 1'b0;
        s             = 1'b0;
        exp_encoded   = 8'b0;

        // NaN input
        if ((ea == 8'hFF && fa != 0) ||
            (eb == 8'hFF && fb != 0)) begin
            result = 32'h7FC00000;
        end

        // Infinity / infinity
        else if ((ea == 8'hFF && fa == 0) &&
                 (eb == 8'hFF && fb == 0)) begin
            result = 32'h7FC00000;
        end

        // Zero / zero
        else if ((ea == 0 && fa == 0) &&
                 (eb == 0 && fb == 0)) begin
            result = 32'h7FC00000;
        end

        // Infinity / finite
        else if (ea == 8'hFF && fa == 0) begin
            result = {sign_r, 8'hFF, 23'b0};
        end

        // Finite / infinity
        else if (eb == 8'hFF && fb == 0) begin
            result = {sign_r, 31'b0};
        end

        // Finite nonzero / zero
        else if (eb == 0 && fb == 0) begin
            result = {sign_r, 8'hFF, 23'b0};
        end

        // Zero / finite nonzero
        else if (ea == 0 && fa == 0) begin
            result = {sign_r, 31'b0};
        end

        else begin
            // Normalize A
            if (ea == 0) begin
                mA = {1'b0, fa};
                expa = -126;

                for (i = 0; i < 24; i = i + 1) begin
                    if (mA[23] == 1'b0) begin
                        mA = mA << 1;
                        expa = expa - 1;
                    end
                end
            end
            else begin
                mA = {1'b1, fa};
                expa = ea - 127;
            end

            // Normalize B
            if (eb == 0) begin
                mB = {1'b0, fb};
                expb = -126;

                for (i = 0; i < 24; i = i + 1) begin
                    if (mB[23] == 1'b0) begin
                        mB = mB << 1;
                        expb = expb - 1;
                    end
                end
            end
            else begin
                mB = {1'b1, fb};
                expb = eb - 127;
            end

            unbiased = expa - expb;

            // Generate quotient with extra precision
            numerator = {40'b0, mA} << 27;
            q = numerator / mB;
            remn = numerator % mB;

            // Normalize quotient
            if (q[27]) begin
                sig = q[27:4];
                g = q[3];
                r = q[2];
                s = (|q[1:0]) || (remn != 0);
            end
            else begin
                sig = q[26:3];
                g = q[2];
                r = q[1];
                s = q[0] || (remn != 0);
                unbiased = unbiased - 1;
            end

            // Round to nearest, ties to even
            rounded_sig = {1'b0, sig};

            if (g && (r || s || sig[0]))
                rounded_sig = rounded_sig + 25'd1;

            // Rounding overflow
            if (rounded_sig[24]) begin
                rounded_sig = rounded_sig >> 1;
                unbiased = unbiased + 1;
            end

            sig = rounded_sig[23:0];

            // Overflow
            if (unbiased > 127) begin
                result = {sign_r, 8'hFF, 23'b0};
            end

            // Normal result
            else if (unbiased >= -126) begin
                exp_encoded = unbiased + 127;
                result = {sign_r, exp_encoded, sig[22:0]};
            end

            // Subnormal result
            else begin
                shift = -126 - unbiased;

                if (shift >= 25) begin
                    result = {sign_r, 31'b0};
                end
                else begin
                    q = {40'b0, sig} << 24;
                    remn = 64'b0;

                    for (i = 0; i < 24; i = i + 1) begin
                        if (i < shift) begin
                            remn[0] = remn[0] | q[0];
                            q = q >> 1;
                        end
                    end

                    rnd = {1'b0, q[24:1]};

                    if (q[0] && (remn[0] || q[1]))
                        rnd = rnd + 25'd1;

                    if (rnd[23])
                        result = {sign_r, 8'h01, rnd[22:0]};
                    else
                        result = {sign_r, 8'h00, rnd[22:0]};
                end
            end
        end
    end

endmodule
