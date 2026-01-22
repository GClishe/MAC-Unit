`timescale 1ns/1ps

/*
  Testbench for mac.sv. Written with the help of ChatGPT.

    successful waveform simulation pictured in mac_tb.jpg

  - The multiply is pipelined by 1 cycle via mult_reg.
  - acc_clear is asserted aligned to the accumulator stage:
      when acc_clear==1 at a posedge, acc_out loads the CURRENT mult_reg
      (which should already contain the first product of the new dot product).
  - Therefore, to start a new dot product:
      Cycle N: present (a0,b0) with acc_clear=0 to seed mult_reg <= a0*b0 at posedge
      Cycle N+1: present (a1,b1) with acc_clear=1 so acc_out <= mult_reg (a0*b0) at posedge
      Then keep acc_clear=0 while feeding remaining terms.
  - One extra "flush" cycle is required after presenting the last (aK-1,bK-1)
    so the final product can be accumulated.
*/

module mac_tb;

  localparam int DATA_W = 16;
  localparam int K      = 4;                        // vectors to be multiplied are 4 elements, each 16 bits wide
  localparam int ACC_W  = 2*DATA_W + $clog2(K) + 1;

  logic clk;
  logic rst;

  // wires between the TB and the mac DUT
  logic signed [DATA_W-1:0] a_in;
  logic signed [DATA_W-1:0] b_in;
  logic acc_clear;

  logic acc_out_valid;
  logic signed [ACC_W-1:0] acc_out;

  // DUT
  mac #(
    .DATA_W(DATA_W),
    .K(K)
  ) dut (
    .clk(clk),
    .rst(rst),
    .a_in(a_in),
    .b_in(b_in),
    .acc_clear(acc_clear),
    .acc_out_valid(acc_out_valid),
    .acc_out(acc_out)
  );

  // 100 MHz clock
  initial clk = 1'b0;
  always  #5 clk = ~clk;

  // helper function to wait one full clock cycle. posedge triggers always_ff in the mac module; negedge ensures non-blocking updates (<=) are visible before checking outputs
  task automatic step_cycle;
    @(posedge clk);
    @(negedge clk);
  endtask

  // Helper function. It sets the tree testbench-driven outputs in one place. purely combinational and is entierly for readability and brevity purposes. 
  task automatic drive(input logic signed [DATA_W-1:0] a,
                       input logic signed [DATA_W-1:0] b,
                       input logic clr);
    a_in      = a;
    b_in      = b;
    acc_clear = clr;
  endtask

  
  // this is the meat of the tb. takes in two vectors of length K; has one expected dot product result
  task automatic run_dot(
      input logic signed [DATA_W-1:0] a_vec [0:K-1],
      input logic signed [DATA_W-1:0] b_vec [0:K-1],
      input logic signed [ACC_W-1:0]  expected_sum
  );
    int i;

    // Seed mult_reg with first product (a0*b0), while keeping acc_clear low. Loads the pipeline but does not touch the accumulator yet
    drive(a_vec[0], b_vec[0], 1'b0);
    step_cycle();

    // in this posedge, the accumulator will load the first product; hence the acc_clear rising (loading the accumulator with the value in the multiplier register (a_vec[0] * b_vec[0]) without adding to the previous accumulator value)
    drive(a_vec[1], b_vec[1], 1'b1);
    step_cycle();

    // middle terms (acc_clear low). presents next a_i and b_i, accumulates previous product, and advances multiply pipeline
    for (i = 2; i < K; i++) begin
      drive(a_vec[i], b_vec[i], 1'b0);
      step_cycle();
    end

    // Flush cycle: one extra cycle so the last product gets accumulated. the last multiply result is still in mult_reg, so we need one more cycle to add it to acc_out
    // Inputs here can be anything; keep acc_clear low.
    drive('0, '0, 1'b0);
    step_cycle();

    // Check result/valid
    if (acc_out_valid !== 1'b1) begin
      $fatal(1, "Expected acc_out_valid=1 after dot product, got %b. acc_out=%0d (0x%0h)",
             acc_out_valid, acc_out, acc_out);
    end

    // verifies that the output of the accumulator matches the expected dot product sum
    if (acc_out !== expected_sum) begin
      $fatal(1, "Dot product mismatch: expected %0d (0x%0h) but got %0d (0x%0h)",
             expected_sum, expected_sum, acc_out, acc_out);
    end

    // Hold behavior sanity check. result should be held stable and valid until the next acc_clear
    step_cycle();
    if (acc_out_valid !== 1'b1) begin
      $fatal(1, "Expected acc_out_valid to stay high while holding result. Got %b", acc_out_valid);
    end
    if (acc_out !== expected_sum) begin
      $fatal(1, "Expected acc_out to hold value %0d but changed to %0d", expected_sum, acc_out);
    end
  endtask

  // Test vectors. declaring arrays for two test cases.
  logic signed [DATA_W-1:0] a1 [0:K-1];
  logic signed [DATA_W-1:0] b1 [0:K-1];
  logic signed [DATA_W-1:0] a2 [0:K-1];
  logic signed [DATA_W-1:0] b2 [0:K-1];

  logic signed [ACC_W-1:0] exp1;
  logic signed [ACC_W-1:0] exp2;

  initial begin
    // Initialize inputs
    a_in      = '0;
    b_in      = '0;
    acc_clear = 1'b0;

    // Reset
    rst = 1'b1;
    step_cycle();
    step_cycle();
    rst = 1'b0;

    // -------------------------
    // Dot #1: [1 2 3 4] · [5 6 7 8] = 70
    // -------------------------
    a1[0]=16'sd1; a1[1]=16'sd2; a1[2]=16'sd3; a1[3]=16'sd4;
    b1[0]=16'sd5; b1[1]=16'sd6; b1[2]=16'sd7; b1[3]=16'sd8;
    exp1 = 70;

    run_dot(a1, b1, exp1);

    // -------------------------
    // Dot #2: [-1 10 -20 3] · [2 -3 4 5] = -97
    // -------------------------
    a2[0]=16'sd-1; a2[1]=16'sd10; a2[2]=16'sd-20; a2[3]=16'sd3;
    b2[0]=16'sd2;  b2[1]=16'sd-3; b2[2]=16'sd4;   b2[3]=16'sd5;
    exp2 = -97;

    // Start next dot product cleanly:
    // Your MAC clears/starts a new dot only when acc_clear is asserted, and acc_clear
    // is defined to align with the accumulator stage (mult_reg already holding first product).
    // run_dot() already follows that convention, so we can just call it again.
    run_dot(a2, b2, exp2);

    $display("PASS: mac_tb completed successfully.");
    $finish;
  end

endmodule
