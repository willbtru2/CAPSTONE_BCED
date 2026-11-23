//////////////////////////////////////////////////////////////////////////////////
// Company: CAPSTONE
// Engineer: Sumvritha Sunil
// Design Name: BCED Cyclic Hamming (7, 4) Encoder
// Module Name: cyclic_hamming_7_4_encoder
// Project Name: BCED
// Target Device: Digilent Nexys A7-100T (xc7a100tcsg324-1)

// Description:
//Implements a Cyclic Hamming (7, 4) emcoder using the generator polynomial 
// g(x) = x^3 + x + 1
//
////////////////////////////////////////////////////////////////////////////////////






module cyclic_hamming_7_4_encoder (

    input  logic       clk, //clock 
    input  logic       rst_n, //reset

    // When enc_start = 1, encoding begins.
    input  logic       enc_start,

    // Original 4-bit message that needs to be encoded.
    input  logic [3:0] data_in,

    // Final 7-bit systematic Cyclic Hamming codeword.
    // encoded_data[6:3] = original 4 data bits
    // encoded_data[2:0] = 3-bit remainder/parity bits
    output logic [6:0] encoded_data,

    // The FSM can use this signal to know that encoded_data is ready.
    output logic       enc_done
);


    
    // INTERNAL REGISTERS
  
    // Holds the value that will be divided by the generator polynomial.
    // For Cyclic Hamming (7,4): n = 7, k = 4, n-k = 3
    // Therefore, three zeros are appended to the original 4-bit data.
    logic [6:0] dividend;


    // Stores a copy of the original 4-bit message
    // The dividend will be shifted during polynomial division,
    // so we save the original data here before encoding begins.
    logic [3:0] data_reg;


    // Stores the current 3-bit remainder of the polynomial division.
    // It starts at 000 and changes once per clock cycle as each dividend bit is processed.
    logic [2:0] remainder;


    // Calculates what the remainder will become on the next clock.
    // remainder_next is combinational logic.
    // remainder is the current registered value.
    logic [2:0] remainder_next;


    // Counts how many of the 7 dividend bits have been processed.
    // A 3-bit counter because 3 bits can represent 0 through 7.
    logic [2:0] bit_count;


    // Internal status flag.
    // busy = 0: Encoder is idle and can accept a new enc_start.
    // busy = 1: Encoder is currently performing polynomial division.
    // This prevents a new enc_start from interrupting an encoding
    // operation that is already in progress.
    logic busy;

    // LFSR / POLYNOMIAL DIVISION LOGIC

    // Cyclic Hamming (7,4) generator polynomial:
    // g(x) = x^3 + x + 1
    // Binary representation:
    // x^3  x^2  x^1  x^0 => 1011 => g(x) = 1011
    // The remainder has only 3 bits because the degree of g(x) is 3.
    // During the LFSR division, the leading x^3 term is handled by
    // the shift operation. Therefore, the lower 3 generator bits,
    // 011, are used for the XOR feedback.
    always_comb begin

        // Shift the current 3-bit remainder one position to the left
        // and bring the next dividend bit into the rightmost position.
        // dividend[6] is always the next bit being processed because
        // the dividend register is shifted left after every clock.
        remainder_next = {
            remainder[1:0],
            dividend[6]
        };


        // Check the most significant bit of the old remainder.
        // If remainder[2] = 1, polynomial division requires an XOR
        // with the lower three bits of the generator polynomial.
        // Generator: 1011 -> Lower three bits: 011
        if (remainder[2])
            remainder_next = remainder_next ^ 3'b011;

    end



    // SEQUENTIAL ENCODER CONTROL

    // This section updates registers only on the rising edge of clk.
    // The basic sequence is:
    // 1. Wait for enc_start.
    // 2. Save the 4-bit input.
    // 3. Append three zeros to create the dividend.
    // 4. Process one dividend bit per clock.
    // 5. After all 7 bits are processed, save the final remainder.
    // 6. Combine original data + remainder.
    // 7. Set enc_done HIGH for one clock.
    always_ff @(posedge clk) begin

        // rst_n is active-low, reset the encoder.
        if (!rst_n) begin
    
            dividend     <= 7'b0000000;
            data_reg     <= 4'b0000;
            remainder    <= 3'b000;
            bit_count    <= 3'b000;
            encoded_data <= 7'b0000000;
            enc_done     <= 1'b0;
            busy         <= 1'b0;

        end


        else begin

            // Default enc_done Value
            enc_done <= 1'b0;

            // Start only when:
            // enc_start = 1  -> FSM requested encoding
            // busy = 0       -> encoder is currently idle

            if (enc_start && !busy) begin

                // Save the original 4-bit input.
                data_reg <= data_in;


                // Append three zeros to the 4-bit input.
                dividend <= {data_in, 3'b000};


                // Polynomial division always starts with a remainder of zero.
                remainder <= 3'b000;


                // No bits have been processed yet, so start the counter at zero.
                bit_count <= 3'd0;


                // Mark the encoder as active.
                // The following clock cycles will enter the busy section
                busy <= 1'b1;

            end



         
            // PERFORM POLYNOMIAL DIVISION
            
            // This section executes once per clock while busy = 1.
            // One dividend bit is processed during each clock cycle.
            else if (busy) begin

                // Store the newly calculated remainder.
                // remainder_next was calculated in always_comb.
                remainder <= remainder_next;


                // Shift the dividend left by one position.
                // The current dividend[6] was just processed.
                // Shifting moves the next bit into dividend[6].
                // A zero is inserted into the rightmost position.
                dividend <= {dividend[5:0], 1'b0};



                // Check whether all 7 bits have been processed
                // Bit_count begins at 0, when bit_count = 6, the current clock is processing the last of the seven dividend bits.
                if (bit_count == 3'd6) begin

                    // Create the final systematic Cyclic Hamming
                    // (7,4) codeword.
                    // Upper 4 bits:
                    //     original message stored in data_reg
                    // Lower 3 bits:
                    //     final polynomial division remainder
                    // We use remainder_next here instead of remainder because remainder_next contains the result of processing the final dividend bit during this clock cycle.
                    encoded_data <= {
                        data_reg,
                        remainder_next
                    };


                    // Tell the FSM that the encoded output is ready.
                    enc_done <= 1'b1;


                    // Encoding has finished, so return to the idle state.
                    // The encoder can now accept another enc_start.
                    busy <= 1'b0;

                end

                else begin

                    // Increase the bit counter so the next dividend bit can be processed on the next clock cycle.
                    bit_count <= bit_count + 1'b1;

                end
            end
        end
    end

endmodule