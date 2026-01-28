`timescale 1ns/1ps

module uart_tx #(
    parameter int unsigned CLKS_PER_BIT = 868       // num of FPGA clk cycles per UART bit time. If we want to change this number, size of clk_cnt should be dynamically sized. For now, i am not concerned with that.
)(
    input  logic        clk,            
    input  logic        rst,            // synchronous reset; only checked in @posedge(clk)
    input  logic        start_i,        // pulse requesting a transmit
    input  logic [7:0]  data_i,         // byte to sent 
    output logic        tx_o,           // UART tx line output (idle high)
    output logic        busy_o          // indicates transmitter is active/not ready
);

    typedef enum logic [2:0] {          // defines a named type `state_t`
        T_IDLE  = 3'd0,                 // state is encoded in 3 bits
        T_START = 3'd1,
        T_DATA  = 3'd2,
        T_STOP  = 3'd3
    } state_t;

    state_t state;                      // initializes state variable with type state_t

    logic [15:0] clk_cnt;               // counts clock cycles within a bit period. 
    logic [2:0]  bit_idx;               // which data bit we are outputting (0 thru 7)
    logic [7:0]  shreg;                 // shift register/latched copy of data_i

    always_ff @(posedge clk) begin
        if (rst) begin
            state   <= T_IDLE;
            clk_cnt <= 16'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
            tx_o    <= 1'b1;            // idle high
            busy_o  <= 1'b0;            // not transmitting
        end else begin
            unique case (state)         // `unique case` signals that exactly one of the case items should match
                T_IDLE: begin
                    tx_o    <= 1'b1;    // ensures we are driving the idle-high tx_o output. everything else set to 0
                    busy_o  <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;

                    if (start_i) begin      // upon receiving start signal, the next clock will begin feeding data_i into shift register, busy flag will rise, and we will enter start state
                        shreg  <= data_i;
                        busy_o <= 1'b1;
                        state  <= T_START;
                    end
                end

                T_START: begin              // in start state, we hold tx_o low for CLKS_PER_BIT cycles
                    tx_o <= 1'b0;           // lowering tx_o flag; no longer idle
                    if (clk_cnt == (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= 16'd0;   
                        state   <= T_DATA;  // after reaching CLKS_PER_BIT cycles, move to T_DATA state.
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                T_DATA: begin           // outputs bits in the shift register (LSB first). One bit per CLKS_PER_BIT clock cycles. After outputting 8 bits, move to T_STOP state.
                    tx_o <= shreg[bit_idx]; 
                    if (clk_cnt == (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= T_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                T_STOP: begin           // holds stop bit high for one period and then return to idle
                    tx_o <= 1'b1;           
                    if (clk_cnt == (CLKS_PER_BIT - 1)) begin
                        clk_cnt <= 16'd0;
                        state   <= T_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                default: begin          // if state is either corrupt or invalid, return to idle
                    state <= T_IDLE;
                end
            endcase
        end
    end

endmodule
