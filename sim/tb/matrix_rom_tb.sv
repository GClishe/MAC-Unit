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
    .MEMFILE("mem/A.mem") 
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
  logic'(a+1); is a cast to `logic` type so that it fits the return type width 
  */
  function automatic logic signed [DATA_W-1:0] expected(input int unsigned a);
    return logic'(a + 1); // addr 0 -> 1, addr 15 -> 16
  endfunction

  int unsigned a;                           // a is a loop variable (0 thru 15)
  logic signed [DATA_W-1:0] exp_prev;       // holds the expected value for the previous cycle's address

  initial begin                             // starts main test sequence at time= 0
    $display("Starting matrix_rom_tb...");  // prints a message to the console

    addr = '0;                              // sets addr to 0 (the '0 means "all 0s, sized automatically")
    exp_prev = expected(0);                 // set's exp_prev to what we expect at address 0 (i.e., 1)

    
    @(posedge clk);     // waits until next rising edge of the clock because the ROM is synchronous. data <= mem[addr] happens at the rising edge, so we need at least one rising edge before data becomes meaningful


    // data at each posedge corresponds to the previous cycle's addr. at each rising edge, `data` is the content of the address that was present at that edge, which is the address set in the previous iteration.
    for (a = 1; a < DEPTH; a++) begin                   // we start at 1 because address 0 was already set before the first clock edge. After that first edge, data should now contain address 0's value

      if (data !== exp_prev) begin                      // compare actual output `data` to expected `exp_prev`
        $error("Mismatch: expected %0d (0x%0h) but got %0d (0x%0h)",        // if an error occurs, the error message prints with both decimal and hex forms. 
               exp_prev, exp_prev, data, data);
        $finish;
      end

      // Advance address and expected value for next check
      addr     <= a[ADDR_W-1:0];        // address is updated to next value `a`, truncated to the correct width
      exp_prev <= expected(a);          // updates `exp_prev` to the expected value for that new address

      @(posedge clk);                   // waits for next rising edge. At that edge, ROm will load mem[addr] into `data` where `addr` is the value just set
    end

    // Final check for last address. After the loop ends, still need to check the last value.
    if (data !== exp_prev) begin
      $error("Mismatch (final): expected %0d (0x%0h) but got %0d (0x%0h)",
             exp_prev, exp_prev, data, data);
      $finish;
    end

    $display("PASS: matrix_rom readback matches A.mem.");
    $finish;
  end

endmodule
