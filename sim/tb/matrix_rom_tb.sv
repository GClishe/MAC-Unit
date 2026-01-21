`timescale 1ns/1ps

/*
 Testbench with the goal of testing if the matrix_rom module works as intended.
 Note that this testbench was generated with significant help from ChatGPT. Comments
 are all my own (to help me understand how the testbench and more broadly how SV works,
 since this is the first time i have used it). 
*/

module matrix_rom_tb;
  // compile-time constants that are local to this module
  localparam int DATA_W = 16;                       // each ROm word is 16 bits
  localparam int DEPTH  = 16;                       // ROM as 16 entires (addresses 0 thru 15)
  localparam int ADDR_W = $clog2(DEPTH);

  // declares the signals that connect to the ROM
  logic clk;
  logic [ADDR_W-1:0] addr;
  logic signed [DATA_W-1:0] data;

  // DUT; the module i am testing.
  matrix_rom #(
    .DATA_W(DATA_W),            // these three parameters are passed into the module
    .DEPTH(DEPTH),
    .MEMFILE("A.mem") 
  ) dut (                       // names this instance dut and wires the ports
    .clk (clk),
    .addr(addr),
    .data(data)
  );

  // 100 MHz clock (10 ns period)
  initial clk = 1'b0;           // clk set to 0 at time 0
  always #5 clk = ~clk;         // clk switches every 5ns; full period is 10ns --> 100MHz

  /*
  Below is a helper function called `expected`.
  Input a is an unsigned integer address. 
  It returns what we expect the ROM output to be for that address, based on the entries in A.mem.
  Address 0 contains 1, address 1 contains 2, ... , address 15 contains 16.
  `automatic` means that each call has its own local storage
  */
  function automatic logic signed [DATA_W-1:0] expected(input int unsigned a);
    return a + 1; // addr 0 -> 1, addr 15 -> 16
  endfunction

  int unsigned a;                           // a is a loop variable (0 thru 15)
  logic signed [DATA_W-1:0] exp_prev;       // holds the expected value for the previous cycle's address

  initial begin
    $display("Starting matrix_rom_tb...");

    // Start at address 0
    addr = '0;

    // First registered read happens on the first posedge
    @(posedge clk);
    @(negedge clk);


    if (data !== expected(0)) begin
      $error("Mismatch: addr=0 expected %0d (0x%0h) but got %0d (0x%0h)",
             expected(0), expected(0), data, data);
      $finish;
    end

    // Step through remaining addresses
    for (a = 1; a < DEPTH; a++) begin
      addr = a[ADDR_W-1:0];

      @(posedge clk);
      @(negedge clk);
      // needs to match the final address
      if (data !== expected(a)) begin
        $error("Mismatch: addr=%0d expected %0d (0x%0h) but got %0d (0x%0h)",
               a, expected(a), expected(a), data, data);
        $finish;
      end
    end

    $display("PASS: matrix_rom readback matches A.mem.");
    $finish;
  end

endmodule