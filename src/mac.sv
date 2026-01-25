module mac # (
    parameter  int DATA_W = 16,                            // size of the scalars to be multiplied and accumulated 
    parameter  int K = 4,                                  // maximum amount of dot product terms. For two 4x4 matrices, K would be 4. for a 5x2 and 2x10 matrix, K=2. The f parameter sets a bound on this so that we can properly size the accumulator output
    localparam int ACC_W = 2*DATA_W + $clog2(K) + 1    // with two 4x4 matrices of 16-bit numbers, each dot product has four 32-bit (worst case) terms added together (34 bits total, +1 to be safe). 2*DATA_W + $clog2(K) generalizes this formula.
)(
    input  logic clk,
    input  logic rst,                               // active-high reset
    input  logic signed [DATA_W-1:0] a_in,          // scalar from matA
    input  logic signed [DATA_W-1:0] b_in,          // scalar from matB
    input  logic acc_clear,                         // control signal used to mark the first product of a new dot product. Instead of adding mult_reg contents to the current sum, it erases the sum by loading the value of mult_reg.
    output logic acc_out_valid,                     // high when acc_out is safe to read
    output logic signed [ACC_W-1:0]  acc_out        // accumulator output. see definition of ACC_W above.  
); 

localparam int KCNT_W  = (K <= 1) ? 1 : $clog2(K+1);        // counter must be able to represent values up to K (and avoid zero width when K=1)

logic signed [ACC_W-1: 0] mult_reg;  // The register holding the a_in, b_in product does not need ACC_W bits to store the worst case value. I chose a width of ACC_W because I want to avoid any potential issues that might (or might not) arise if mult_reg and acc_out are of different sizes.
logic [KCNT_W:0] k_sum;                  // num of terms added in current dot product


always_ff @(posedge clk) begin
    if (rst) begin
        mult_reg <= '0;  
        acc_out  <= '0;  
        acc_out_valid <= 0;
        k_sum <= '0;
    end
    else if (acc_clear) begin
        acc_out <= mult_reg;        // notice the absence of a sum term. When acc_clear is high, we begin new dot product, so we do not care about the accumulated sum from the previous matrix multiplication\
        mult_reg <= a_in * b_in;

        // acc_clear marks the first product of the new dot product (the product currently in mult_reg).
        // So we have consumed 1 term as of this clock edge.
        k_sum <= {{(KCNT_W-1){1'b0}}, 1'b1};        // this syntax concatenates 00..0 (KCNT-1 bits) with 1'b1. Thus we set k_sum <= 000...01, where there are KCNT-1 0s. 

        // If K==1, the dot product is complete immediately after loading the first term.
        acc_out_valid <= (K == 1);
    end
    else begin
        
        mult_reg <= a_in * b_in;    // we want to keep the multiply pipeline running every cycle

        // only accumulate up to K terms. Once we reach K, hold acc_out and keep valid high.
        if (!acc_out_valid) begin
            acc_out <= mult_reg + acc_out;

            k_sum <= k_sum + {{(KCNT_W-1){1'b0}}, 1'b1}; // we consumed one more term this cycle, so increment the term counter.

            // acc_out becomes the FINAL dot-product result when we have just consumed the K-th term.
            // Since k_sum is the pre-clock value here, "just consumed the K-th term" means (k_sum + 1 == K).
            if (k_sum + {{(KCNT_W-1){1'b0}}, 1'b1} == K[KCNT_W-1:0]) begin
                acc_out_valid <= 1;
            end
            else begin
                acc_out_valid <= 0;
            end
        end
        else begin
            // Once valid, we hold the result until the controller asserts acc_clear to begin the next dot product.
            acc_out_valid <= 1;
        end
    end
end

endmodule