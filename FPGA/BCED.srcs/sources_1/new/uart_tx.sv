`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2026 10:12:16 PM
// Design Name: UART Transmitter Module
// Module Name: uart_tx
// Project Name: BCED
// Target Devices: 
// Tool Versions: 
// Description: This module implements a 8-N-1 UART Transmitter for the FPGA.
// It operates with the system 100MHz system clock and operates at a 115200 baud rate.
// Bitstream is transmitted in the following order: 1 start bit, 8 data bits (LSB first), and 1 stop bit.
// Bit timing: 100 MHz / 115200 baud = 868 cycles per bit
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Inital draft version, values subject to change if different CLK or baud rate changed
//////////////////////////////////////////////////////////////////////////////////


module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input clk, // 100 MHz system clock
    input rst_n, // Active-low reset (pin c12 on Nexys A7-100T)
    input tx_start, //1 cycle pulse to start transmission
    input [7:0] tx_data, // 8-bit data to be transmitted
    input tx_pin,   // UART TX output pin (pin d4 on FPGA, d14 on pmod header)
    input tx_busy,  // UART TX busy signal; HIGH while transmission is in progress
    input tx_done   // UART TX done signal; HIGH for 1 cycle when transmission is complete
    );

    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE; //863 cycles per bit

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        START = 2'b01,
        DATA= 2'b10,
        STOP= 2'b11
    } state_t;

    state_t state;

    logic [15:0] clk_count; // Counter for clock cycles per bit (min amount of bits needed is 10 bits to handle 868)
    logic [2:0] bit_idx; // Counter for the number of bits transmitted (0-7 for 8 data bits)
    logic [7:0] data_reg; // Register to hold the data to be transmitted (Prevent against metasbtability for when tx_data changes while transmitting)

    //Sequential logic for UART transmission
    always_ff @(posedge clk or negedge rst_n) begin //
            
            // Initialize all registers values to prevent inferred latches
            clk_count <= 16'd0;
            bit_idx <= 3'd0;
            data_reg <= 8'd0;
            tx_pin <= 1'b1; // UART IDLE is high
            tx_busy <= 1'b0;
            tx_done <= 1'b0; 

        if (!rst_n) begin // Active-low reset
            state <= IDLE;
            clk_count <= 16'd0;
            bit_idx <= 3'd0;
            data_reg <= 8'd0;
            tx_pin <= 1'b1; // UART IDLE is high
            tx_busy <= 1'b0;
            tx_done <= 1'b0; 
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    clk_count <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        tx_busy <= 1'b1;
                        state <= START;
                    end else begin  
                        tx_busy <= 1'b0;
                    end
                end

                START: begin
                    tx_pin <= 1'b0; // Start bit is low this (RTS - active low)
                    if (clk_cnt < CLKS_PER_BIT - 1) begin //For loop for counting down clocks cycles
                        clk_cnt <= clk_cnt + 1'd1;
                    end else begin  
                        clk_cnt <= clk_cnt + 1'b1;
                        state <= DATA; 
                    end
                end

                DATA: begin
                    tx_pin <= data_reg[bit_idx]; //LSB (first) - > MSB (last) by RS232/Uart protocol
                    if(clk_cnt < CLKS_PER_BIT - 1)begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0; 
                        if(bit_idx < 3'd7;) begin
                        bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_pin <= 1'b1;
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        tx_busy <= 1'b0; 
                        tx_done <= 1'b1; //Byte has been transmitted
                        state <= IDLE; 
                    end
                end

                default: begin
                    state <= IDLE; 
                end
                
            endcase
        end
    end
endmodule
