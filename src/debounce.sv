module debounce (
    input logic pb_in,      // bouncy button press 
    input logic clk,
    output logic pb_out     // debounced button press
);

logic slow_clk_en;
logic q0, q1, q2;

clock_enable slow_clk_module (  
    .clk_100M    (clk),
    .slow_clk_en (slow_clk_en)          // slow_clk pulses high every 250k clk cycles
);

always_ff @(posedge clk) begin
    if (slow_clk_en) begin
       q0 <= pb_in;     // newest sample
       q1 <= q0;        // previous sample 
       q2 <= q1;        // older sample
    end
end

assign pb_pulse = q1 & ~q2;     // detects rising transition on q1
// the reason we look for a rising transition on q1 rather than a simple pb_in == 1 is because the latter would cause several pb_pulse signals if pb_in was held down for more than a few milliseconds. 

endmodule



module clock_enable (       
    input logic clk_100M,           // 100MHz clock
    output logic slow_clk_en        // 1-cycle pulse that goes high every 250k cycles
);

logic [26:0] counter;       // 27 bit counter register

localparam int unsigned MAX_COUNT = 249_999;    // the idea is to have slow_clk_en pulse once every 250k cycles (400 per second)

always_ff @(posedge clk_100M) begin
    
    if (counter >= MAX_COUNT) begin
        counter <= '0;                    // reset the counter when we reach MAX_COUNT
    end else begin
        counter <= counter + 27'd1;       // otherwise, increment counter
    end
end

always_comb begin
    slow_clk_en = (counter == MAX_COUNT); // slow_clk_en pulses when counter reaches max_count
end

endmodule

