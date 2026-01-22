module mac # (
    parameter int DATA_W = 16;                              // size of the scalars to be multiplied and accumulated 
    parameter int K_MAX = 4;                                // maximum amount of dot product terms. For two 4x4 matrices, K would be 4. for a 5x2 and 2x10 matrix, K=2. The K_MAX parameter sets a bound on this so that we can properly size the accumulator output
)(
    input  logic clk,
    input  logic rst,                               // active-high reset
    input  logic signed [DATA_W-1:0] a_in,          // scalar from matA
    input  logic signed [DATA_W-1:0] b_in,          // scalar from matB
    input  logic acc_clear,                         // control signal to clear the accumulator to 0. with a pipelined architecture, this needs to clear the accumulator after it receives the value in mult_reg one cycle later
    output logic signed [ACC_W-1:0]   acc_out       // accumulator output. see definition of ACC_W below.  
); 

localparam int ACC_W = 2*DATA_W + $clog2(K_MAX) + 1;    // with two 4x4 matrices of 16-bit numbers, each dot product has four 32-bit (worst case) terms added together (34 bits total, +1 to be safe). 2*DATA_W + $clog2(K_MAX) generalizes this formula.

initial begin
  if (K_MAX < 1)  $fatal(1, "K_MAX must be >= 1 (got %0d)", K_MAX);
  if (DATA_W < 1) $fatal(1, "DATA_W must be >= 1 (got %0d)", DATA_W);
end




endmodule 