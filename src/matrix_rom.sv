/*
Matrices to be multiplied by the top.v module will be read from pre-programmed ROM. 

My first instinct was actually to use the UART interface to stream in matrices and then store them in 
registers, but I want to get some practice with using the FPGA's dedicated memory 
*/


module matrix_rom # (
    parameter int DATA_W = 16,                  // width of each stored number
    parameter int DEPTH = 16,                   // number of entries in the memory
    parameter string MEMFILE = "mem/A.mem"      // will read from the text file A.mem
)(
    input  logic clk,
    input  logic [$clog2(DEPTH)-1:0] addr,      // addr is the read address. If DEPTH=16, addr is of size [3:0]
    output logic signed [DATA_W-1:0] data       // value read from the ROM at that address. Signed indicates that the bits are treated asa signed 2's complement integer. 
);

    logic signed [DATA_W-1:0] mem [0:DEPTH-1];  // declares the storage array mem. Each element is DATA_W bits wide and signed; there are DEPTH elements, indexed from 0 to DEPTH-1

    initial begin                               // runs once at time 0 in simulation. These are the initial contents of the memory
        $readmemh(MEMFILE, mem);                // read text file "A.mem" as hex numbers. Fill mem[0], then mem[1], ...
    end                                         // Address mapping for a 4x4 matrix with elements listed in row-major order follows A[row][col] -> mem[row*4 + col]
    
    /*
    The code below describes how the memory is read into data. At rising edge of clk, data updates to addr's content. In some cases,
    we could instead use a purely combinational output (always_comb data = mem[addr];). However, this would be best only if the matrices are tiny,
    if we explicitly wanted the ROM implemented in LUTs, and if we are trying to minimize the latency at any cost. This last point might be something to keep in mind.

    With the synchronous ROM implemented below, the matmul loop must first (in cycle i) set addr for A[r,k] and B[k,c], then (in cycle i+1), receive A_val and B_val, do multiply-accumulate. 
    */
    always_ff @(posedge clk) begin              
        data <= mem[addr];                      // data updates on rising edge of clk. It samples whatever addr is at the clk edge. 
    end

endmodule
