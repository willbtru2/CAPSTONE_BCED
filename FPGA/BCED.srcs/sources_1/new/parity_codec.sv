`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: CAPSTONE
// Engineer: Sumvritha Sunil
// Design Name: BCED Parity Encoder / Decoder
// Module Name: parity_codec
// Project Name: BCED
// Target Device: Digilent Nexys A7-100T (xc7a100tcsg324-1)

// Description:
// This module performs both EVEN PARITY encoding and parity checking for
// the BCED system.
//
// ENCODING:
// When enc_start is asserted by the main BCED FSM, the module calculates
// one even-parity bit from data_in. The parity bit is appended to the
// least-significant/right side of the original data.
//
// Example:
//      data_in      = 1011
//      parity bit   = 1
//      encoded_data = 10111
//
// The parity bit is chosen so that the total number of 1s in the complete
// encoded word is even.
//
// DECODING:
// When dec_start is asserted by the main BCED FSM, the module checks the
// entire received word returned from the channel simulator.
//
// If the XOR of all received bits is:
//      0 -> parity is valid; no error was detected
//      1 -> parity is invalid; an error was detected
//
// Simple parity can DETECT an odd number of bit errors, but it cannot
// determine which bit is incorrect and therefore cannot correct the data.
//
// The original data portion is also separated from the received parity bit
// and placed on decoded_data.
//
// FSM INTERFACE:
//      ENCODE_DATA state:
//          FSM asserts enc_start -> this module encodes the data
//          -> module asserts enc_done
//
//      DECODE_CORRUPT state:
//          FSM asserts dec_start -> this module checks received parity
//          -> module asserts dec_done
//
//////////////////////////////////////////////////////////////////////////////////

module parity_codec #(
    
    parameter DATA_WIDTH = 64
)(
    
    // Clock and Reset

    input logic clk, // 100 MHz FPGA system clock.
    input logic rst_n, // Active-low reset.


    // Control Inputs from the Main BCED FSM

    input logic enc_start, // Tells this module to calculate and append an even parity bit.
    input logic dec_start,  // Tells this module to check the parity of the word returned from the sink.


    // Encoder Data Input

    input logic [DATA_WIDTH-1:0] data_in, // Original source data that must be encoded.
   

    // Decoder 
    input logic [DATA_WIDTH:0] received_data, //Encoded word returned from the channel simulator. Contains [original data][parity bit]
    
    // Encoder  Outputs

    output logic [DATA_WIDTH:0] encoded_data, // Original data with one even-parity bit appended - 65 bits
    

    output logic enc_done, //  FSM uses this signal to leave ENCODE_DATA and move to TX_SNK_ENCODED.

    // Decoder Outputs

    output logic [DATA_WIDTH-1:0] decoded_data, // Original data portion of the received word after removing the parity bit - 64 bits
    

    output logic parity_error,
    // Error-detection flag:
    //
    //      parity_error = 0 -> parity check passed
    //      parity_error = 1 -> parity check failed
    //
    // Simple parity reliably detects an odd number of bit flips.
    // An even number of bit flips may not be detected.

    output logic dec_done // FSM uses this signal to leave DECODE_CORRUPT and move to TX_SRC.
);


    //
    // Sequential Encoding / Decoding Logic
    //
    // All parity operations are performed on the rising edge of the FPGA clock.
    //
    // enc_start and dec_start are expected to be one-clock pulses generated
    // by the main BCED FSM.
    //
    // The encoder/checker operation itself is simple enough to complete in
    // one FPGA clock cycle.
    //

    always_ff @(posedge clk or negedge rst_n) begin

        // Reset
        if (!rst_n) begin

            // Clear all stored outputs when reset is active.
            encoded_data <= '0;
            decoded_data <= '0;

            parity_error <= 1'b0;

            enc_done <= 1'b0;
            dec_done <= 1'b0;
        end

        else begin

            // Default values for completion signals
            //
            // enc_done and dec_done should only stay HIGH for one clock cycle.
            // Setting them LOW here ensures that they automatically return to
            // zero after an encoding or decoding operation is completed.
            //
            enc_done <= 1'b0;
            dec_done <= 1'b0;


            // ENCODING
            if (enc_start) begin

                // Generate the EVEN parity bit.
                // The concatenation operator { } joins the original data and
                // the generated parity bit into one encoded word.
                // The parity bit is stored as encoded_data[0].
                
                encoded_data <= {data_in, ^data_in};


                // Tell the FSM that the encoding operation is complete.
                enc_done <= 1'b1;
            end


            // DECODING 
            else if (dec_start) begin

                // Recover the original data portion.
                decoded_data <= received_data[DATA_WIDTH:1];

                // Check the received parity.
                parity_error <= ^received_data;

                // Tell the  FSM that parity checking has completed.
                dec_done <= 1'b1;
            end

        end
    end

endmodule
