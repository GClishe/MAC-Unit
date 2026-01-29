`timescale 1ns/1ps

/*
 For this project, I will first store matrices written in A.mem and B.mem (potentially more later) to FPGA ROM.
 Then, upon a button press on the FPGA, matrices will be read and fed into 
*/
module matmul_top (
    input logic clk,            // 100 Mhz clock
    input logic btnD,           // active high reset
    input logic btnC,           // selects matrices
    input logic btnR,           // begins computation
    input logic [15:0] sw,      // switches for matrix selection 

    output logic ja4,           // UART TX (to Pi RXD)  --> JA[4]
    output logic [15:0] led,    // LEDs for debug
);

typedef enum logic [3:0] {          // defines a named type `state`
        S_IDLE      = 4'd0,         // wait for a switch to be active and btnC to be pressed
        S_SELA      = 4'd1,         // record which matrix is selected for matrix A (based on the switch that was switched on) and stream over UART TX (for debug)
        S_SELB      = 4'd2,         // record which matrix is selected for matrix B (based on the second switch that was on) and also stream over UART TX. Then wait for btnR to signal beginning of multiplication.
        S_MULTIPLY  = 4'd3,         // multiplies the matrices. may need internal state machine to generate addresses and read matrix data from ROM. not sure yet how that will be implemented.
        S_TRANSMIT  = 4'd4          // transmits result through UART (row major order)
    } state;




endmodule 