`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Hazael Magino
// 
// Create Date: 11/06/2026 11:10:19 AM
// Design Name: Finite State Machine for BCED
// Module Name: bced_fsm
// Project Name: BCED
// Target Devices: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Tool Versions: 
// Description: This project file houses the finite state machine for the BCED project. 
// The FSM is responsible for controlling the flow of data and operations based on the input header and other relevant control signals. 
// It transitions between different states to manage the encoding and decoding processes efficiently.
// Stream framing: start header (eos=0) -> blocks -> end header (eos=1) and the stream is finished.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bced_fsm(


    // Clock & active-low reset
    input logic clk,            //100 Mhz Clock
    input logic rst_n,         //Active-low reset

    // Header inptus
    input logic [7:0]  header,    //16 bit header that is valid when hdr_valid is high
    input logic         hdr_valid, //1 cycle pulse meaning start or end header was recieved
    
    // Status Flags
    input logic         msg_buf_full,    //High when the source block is buffered into msg_buffer
    input logic         enc_done,        //High when the encoding process is complete for the respective coding scheme
    input logic         tx_snk_done,    // High when UART TX#2 finished sending the encoded block to the sink
    input logic         snk_buf_full,   //High when the corrupted block from the sink is fully stored in snk_buffer
    input logic         dec_done,      //High when the decoder finished (syndrome + correction)
    input logic         tx_src_done,    //High when UART TX#1 finished the decoded block to the source

    //Fsm Control Enables &  debugging signals
    output logic        rx_src_en,     //Enable UART RX#1 to receive data from source software 
    output logic        mode_reg_latch, //Load enable for mod_reg coding scheme (1 cycle)
    output logic        src_buf_write,  //Enable to write the data payload into msg_buffer
    output logic        enc_start,     //Pulse to start the encoding process (1 cycle)
    output logic        tx_snk_start,   //Pulse to start sending the encoded data to sink software (1 cycle)
    output logic        rx_snk_en,     //Enable UART RX#2 to receive data from sink software
    output logic        snk_buf_wr,   //Enable byte write into snk_buffer
    output logic        dec_start,    //Pulse to start the decoding process (1 cycle)
    output logic        tx_src_start,    //Pulse to start sending the decoded data back to source software (1 cycle)

    // Debug 
    output logic [2:0]  state_code //3-bit binary code representing the current state of the FSM for debugging purposes & lEDs 
    );

    // Bit of header that signifies whether packet is a start or end header
    // 0 = start , 1 = end 
    localparam int EOS_BIT = 7;

    //State binary code definitions
    typedef enum logic [2:0] {
        IDLE = 3'b000, // Waiting for a start header
        RD_SOURCE = 3'b001, // Recieveing a message from the source PC
        ENCODE_DATA = 3'b010, //Encoder is running 
        TX_SNK_ENCODED = 3'b011, // Sending the encoded block to the sink pc
        RD_SNK_CORRUPT = 3'b100, // Recieving the corrupted block back from the sink pc
        DECODE_CORRUPT = 3'b101, // Decoder is detecting/correcting errors
        TX_SRC = 3'b110 //Sending the decoder block back to the source PC
    } state_t;

    state_t current_state, next_state, prev_state;

    //Entry logic:
    //'entered' is high for one clock after every state change. 
    // Mostly used to turn the start outputs as a clock-cycle pulse rather than staying high
    // Thus when encoding/decoding modules get a clean signle start command (more obvious in a waveform)

    logic entered;
    assign entered = (current_state != prev_state); // 1 cycle pulse when state changes


    // Header detection signals
    // start_hdr is high for 1 cycle when a start header is recieved in the current clock cycle
    // end_hdr is high for 1 cycle when an end header is recieved in the current clock cycle
    // useful wires for internal logic to detect the start and end of a stream
    logic start_hdr;
    logic end_hdr;
    assign start_hdr = hdr_valid & ~header[EOS_BIT]; // Bit 7 = 0
    assign end_hdr = hdr_valid & header[EOS_BIT]; // Bit 7 = 1




    //Sequential State Register
    // Updates on every rising edge of the clock or when the reset button is pressed (active low)
    always_ff @(posedge clk or negedge rst_n) begin //Active low; reset button holds 1 and when pressed drops to 0
        if (!rst_n) begin
            prev_state <= IDLE;
            current_state <= IDLE; 
        end else begin
            prev_state <= current_state;
            current_state <= next_state;
        end
    end

    //Combinational Next State Logic:
    // Default is stay in current state amd only leave that state when the flags are asserted
    // The design of flag methods, each state serves as a wait state for the next state to be triggered by the next 
    // respective flag.
    always_comb begin

        next_state = current_state; //Default hold current state

        case (current_state)
            //Wait for start header
            IDLE: begin
                if (start_hdr)
                    next_state = RD_SOURCE;
            end

            //Recieve a block. An end header means that the stream is finished 
            //cand should be checked before moving to encoding. 
            RD_SOURCE: begin
                if (end_hdr)
                    next_state = IDLE;
                else if (msg_buf_full)
                    next_state = ENCODE_DATA;
            end

            //Wait for the encoder to finish then send result to sink software
            ENCODE_DATA: begin  
                if (enc_done)
                    next_state = TX_SNK_ENCODED;
            end

            //wait until the whole corrupted block is recieved from the sink software before decoding
            TX_SNK_ENCODED: begin
                if(tx_snk_done)
                    next_state = RD_SNK_CORRUPT;
            end

            //Wait until the whole corrupted block has been recieved. 
            RD_SNK_CORRUPT: begin
                if(snk_buf_full)
                    next_state = DECODE_CORRUPT;
            end

            //Wait for the deocder, then return the result to the source software.
            DECODE_CORRUPT: begin
                if(dec_done)
                    next_state = TX_SRC;
            end

            // After sending back, go get the next block for reading (or the end header if the stream is finished)
            TX_SRC: begin
                if(tx_src_done) begin
                    if (header[EOS_BIT]) // Last block was sent, so go back to idle and wait for the next stream
                        next_state = IDLE;
                    else // Otherwise go back to reading the next block from the source software
                        next_state = RD_SOURCE;
                end else begin
                    next_state = TX_SRC; //Hold until the TX is done
                end
            end 

            //Safety Net
            default: 
                next_state = IDLE; //Should never be reached, but if it does, go to error state (helpful for debugging)
        endcase
    end

    // Output Combination logic
    // Enables signals (rx_src_en, src_buf_write): High the whole time while in the state
    // Start signals (enc_start, tx_snk_start, dec_start, tx_src_start, syndr_calc_en): High for 1 clock cycle when entering the state
    always_comb begin
        // initialize to 0 
        rx_src_en = 1'b0;
        mode_reg_latch = 1'b0;
        src_buf_write = 1'b0;
        enc_start = 1'b0;
        tx_snk_start = 1'b0;
        rx_snk_en = 1'b0; 
        snk_buf_wr = 1'b0; 
        dec_start = 1'b0;
        tx_src_start = 1'b0;

        case (current_state)

            IDLE: begin
                rx_src_en = 1'b1; // Myst be high to recieve the start header
                mode_reg_latch = start_hdr; // Pulse high when start header arrives such that coding scheme is stored. 
            end

            RD_SOURCE: begin
                rx_src_en = 1'b1;   // Keep receiving from the source PC 
                src_buf_write = 1'b1; //write only when the UART is valid
            end 

            ENCODE_DATA: begin
                enc_start = entered; // one-cycle pulse to start the encoding process
            end


            TX_SNK_ENCODED: begin
                tx_snk_start = entered; //one-cycle pulse to UART TX#2 to start sending the encoded block to the sink software 
            end 

            RD_SNK_CORRUPT: begin
                rx_snk_en = 1'b1; //listen to sink software to recieve the corrupted block
                snk_buf_wr = 1'b1; //write the corrupted block into the snk_buffer when the UART byte is valid
            end

            DECODE_CORRUPT: begin 
                dec_start = entered; //one-cycle pulse to start the decoding process 
            end

            TX_SRC: begin
                tx_src_start = entered; //one-cycle pulse to UART TX#1 to start sending the decoded block back to the source software
            end

            default: //outputs stay 0
            begin    
            end 
        endcase
    end
    //Current state code output for debugging purposes on the LEDs.
    assign state_code = current_state; //For debugging purposes, output the current state code to the LEDs
endmodule   
