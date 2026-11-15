`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Hazael Magino
// 
// Create Date: 11/14/2026 10:18:20 AM
// Design Name: UART Reciever Module
// Module Name: uart_rx
// Project Name: BCED
// Target Devices: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Tool Versions: 
// Description: Asynchronous UART Receiver module configured for 8-N-1 framing.
// (1 start bit, 8 data bits (LSB (first) - MSB(last)), 1 stop bit, no parity). 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx#(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE = 115_200
)(
    input logic clk, //100 MHz system clock 
    input logic rst_n,  //Active-low asynchronous reset
    input logic rx_en,  //Reciever enable from controller FSM
    input logic rx_pin, //Serial UART input pin
    output logic [7:0] rx_data, //Recieved 8-bit byte
    output logic rx_byte_valid, //1-cycle pulse when rx_data is valid
    output logic rx_busy //High while receiving character frame
    );


    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE; //863 cycles per bit
    localparam int HALF_BIT_CLKS = CLKS_PER_BIT / 2; //434 Cycles

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        START = 2'b01,
        DATA = 2'b10, 
        STOP = 2'b11
    }state_t;
    
    state_t state;
    logic [15:0] clk_cnt;
    logic [2:0] bit_idx;
    logic [7:0] shift_reg;

    //2-stage synchronizer for rx_pin reciever process from USB - UART
    logic rx_sync_1, rx_sync_2;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= rx_pin; // Flop 1: Takes care of the asynchronous timing from physical pin (metastable data)
            rx_sync_2 <= rx_sync_1; //Flop 2: Flop 1 by the next clock cycle has settled, and Flop 2 can then pass a clean value
        end    
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; 
            clk_cnt <= 16'd0;
            bit_idx <= 3'd0;
            shift_reg <= 8'd0;
            rx_data <= 8'd0;
            rx_byte_valid <= 1'b0;
            rx_busy <= 1'b0;
        end else begin
            rx_byte_valid <= 1'b0; //1 cycle pulse

            case(state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    rx_busy <= 1'b0; 
                    
                    //Detect falling edge of start when reciever is enabled
                    if (rx_en && (rx_sync_2 == 1'b0)) begin
                        rx_busy <= 1'b1; 
                        state <= START;
                    end
                end

                START: begin
                    if (clk_cnt == HALF_BIT_CLKS) begin
                        if(rx_sync_2 == 1'b0) begin
                            clk_cnt <= 16'd0; // Valid start bit confirmed
                            state <= DATA;
                        end else begin
                            state <= IDLE; //False start glitch, return to IDLE
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin 
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= 16'd0;
                        shift_reg[bit_idx] <= rx_sync_2; // Sample in center of bit period (LSB first)
                        if(bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= 3'd0;
                            state <= STOP; 
                        end
                    end
                end

                STOP: begin
                    // Wait for stop bit center
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1; 
                    end else begin
                        clk_cnt <= 16'd0;
                        rx_busy <= 1'b0;
                        //Check if stop bit is high
                        if(rx_sync_2 == 1'b1) begin
                            rx_data <= shift_reg;
                            rx_byte_valid <= 1'b1; //1 cycle valid pulse
                        end
                        state <= IDLE; 
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule 