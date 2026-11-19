`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Hazael Magino
// 
// Create Date: 11/18/2026 10:49:20 PM
// Design Name: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Module Name: bced_top
// Project Name: BCED
// Target Devices: 
// Tool Versions: 
// Description: Top level structural integration for BCED FPGA
// Combines:
// - Uart transcievers and recievers (Source PC & Sink PC at 115200 baud rate )
// - Central 7-State FSM
// - Parity Coding scheme
// - 7 segment for led_driver error 
// - Error indicator LED
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bced_top#(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE = 115_200,
    parameter int DATA_WIDTH = 64
)(
    //100 Mhz clock and cpu reset
    input logic clk, //Pin E3
    input logic rst_n, //Pin C12 (active low rst)

    //Source PC interface 
    input logic uart_txd_in, //Pin C4 (Data from source PC to FPGA Rx)
    input logic uart_rxd_out, //Pin D4 (Data from FPGA Tx#1 to source PC)

    //Sink PC Interface 
    //output logic jb_tx, //Pins D14 (JB[7]: Encoded data to sink PC) - to be implemented in spring
    //output logic jb_rx, //Pins E16 (JB[8]: Courrupted data fro Sink PC)

    //Seven segment LEDs (AN1 = State, AN0 = Scheme ID)
    output logic [7:0] an, //Pins j17, j18, t9, j14, p14, t14, k2, U13
    output logic [6:0] seg, // Pins t10, r10, k16, k13, p15, t11, L18

    output logic [2:0] led_state, //Pins h17, k15, j13 (LED[2:0 = State Code])
    output logic  led_error //Pin N14 (LED[9] = Sticky Channel Error Flag)
);

    //Signals & internal connections
    logic [7:0] header_in;
    logic hdr_valid;
    logic msg_buf_full;
    logic enc_done;
    logic tx_snk_done;
    logic snk_buf_full;
    logic dec_done; 
    logic tx_src_done;
    logic [2:0] state_code;

    logic rx_src_en;
    logic mode_reg_latch; 
    logic src_buf_write;
    logic enc_start;
    logic tx_snk_start;
    logic rx_snk_en;
    logic snk_buf_wr;
    logic dec_start; 
    logic tx_src_start;

    //Latched Registers
    logic [7:0] header_reg; //Holds [EOS, SCHEME[6:3], DEBUG, Sync[1:0]]

    //Buffers for data payload and code words
    logic [63:0] msg_buffer; //Buffer 8 bytes from Source PC
    logic [2:0] src_byte_cnt;
    logic [64:0] encoded_codeword; //Parity encoder [64:1] Data, parity bit
    logic [63:0] decoded_payload; //From parity decoder
    logic [63:0] recovered_buffer; //Latched decoded data from TX#1
    logic parity_error_raw; //1 cycle error flag from parity decoder

    //Shared UART Signals for transmitting to signle source
    //Uart RX #1 
    logic [7:0] rx_data_shared;
    logic rx_valid_shared;
    logic rx_busy_shared;

    //UART Tx #1 (Source PC) signals
    logic [7:0] tx_data_src;
    logic tx_start_src;
    logic [7:0] tx_data_snk;
    logic tx_start_snk;
    
    logic [7:0] tx_data_mux;
    logic tx_start_mux;
    logic tx_busy_shared;
    logic tx_done_shared; 

    //Assign led state
    assign led_state = state_code;
    
    
    //Chose with Tx to stream based on the transmission state
    always_comb begin
        if (state_code == 3'b011) begin // Tx_snk encoded: sending code to sink pc
            tx_data_mux = tx_data_snk;
            tx_start_mux = tx_start_snk;
        end else begin
            tx_data_mux = tx_data_src; // Tx_src: Returning recovered payload to source PC
            tx_start_mux = tx_start_src; 
        end
    end


    // //Sink PC signals with pmod
    // //UART Rx #2 

    // logic [7:0] rx_data_snk; 
    // logic rx_valid_snk;
    // logic rx_busy_snk;

    // //UART Tx #2
    // logic [7:0] tx_data_snk;
    // logic tx_start_snk;
    // logic tx_busy_snk;
    // logic tx_done_snk;

    //Shared port for right now until spring
    //UART Rx #1: Take data from Source PC (Pin C4)
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE (BAUD_RATE))
    u_rx(
    .clk (clk),
    .rst_n (rst_n),
    .rx_en (rx_src_en || rx_snk_en),
    .rx_pin (uart_txd_in),
    .rx_data (rx_data_shared),
    .rx_byte_valid (rx_valid_shared),
    .rx_busy (rx_busy_shared)
    );

    //UART Tx #1: Send recovered data back to source PC (Pin D4)
    uart_tx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE (BAUD_RATE))
    u_tx(
        .clk(clk),
        .rst_n (rst_n),
        .tx_start(tx_start_mux),
        .tx_data(tx_data_mux),
        .tx_pin(uart_rxd_out),
        .tx_busy(tx_busy_shared),
        .tx_done(tx_done_shared)
    );

    //Only using FPGA headers since we are using source and sink on the same computer

    // //Uart Rx #2: Recieving Courrupted codeword from Sink PC (Pin E16)
    // uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE (BAUD_RATE))
    // u_tx_snk(
    // .clk (clk),
    // .rst_n (rst_n),
    // .rx_en (rx_snk_en),
    // .rx_pin (jb_rx),
    // .rx_data (rx_data_snc),
    // .rx_byte_valid (rx_valid_snk),
    // .rx_busy (rx_busy_snc)
    // );

    //Uart Tx #2: Sending encoded codeword to Sink PC (Pin D14)
    // uart_tx #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.BAUD_RATE (BAUD_RATE))
    // u_tx_snk(
    //     .clk(clk),
    //     .rst_n (rst_n),
    //     .tx_start(tx_start_snk),
    //     .tx_data(tx_data_snk),
    //     .tx_pin(jb_tx),
    //     .tx_busy(tx_busy_snc),
    //     .tx_done(tx_done_snk)
    // );


    // Finite State Machine

    bced_fsm u_fsm(
        .clk(clk),
        .rst_n(rst_n),
        .hdr_valid(hdr_valid),
        .header(header_in),
        .msg_buf_full(msg_buf_full),
        .enc_done(enc_done),
        .snk_buf_full(snk_buf_full),
        .dec_done(dec_done),
        .tx_snk_done(tx_src_done),
        .tx_src_done(tx_src_done),

        .rx_src_en(rx_src_en),
        .mode_reg_latch(mode_reg_latch),
        .src_buf_write(src_buf_write),
        .enc_start(enc_start),
        .tx_snk_start(tx_snk_start),
        .rx_snk_en(rx_snk_en),
        .snk_buf_wr(snk_buf_wr),
        .dec_start(dec_start),
        .tx_src_start(tx_src_start),
        .state_code(state_code)  
    );

    //Parity Encoder & Decoder Module
    parity_codec #(
        .DATA_WIDTH(64)
    )u_parity_codec(
        .clk(clk),
        .rst_n(rst_n),
        .enc_start(enc_start),
        .dec_start(dec_start),
        .data_in(msg_buffer),
        .received_data(snk_buffer[71:7]), //Top 65 bits contains the data + parity is the remaining 7
        .encoded_data(encoded_codeword),
        .enc_done(enc_done),
        .decoded_data(decoded_payload),
        .parity_error(parity_error_raw),
        .dec_done(dec_done)
    );

    led_driver u_led_driver(
        .clk(clk),
        .rst_n(rst_n),
        .data_in({1'b0, state_code, header_reg[6:3]}), //Data to be displayed
        .an(an),
        .seg(seg)
    );

    //Source Ingest Data and latch data
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            header_reg <= 8'h0; 
            header_in <= 8'h0;
            hdr_valid <= 1'b0;
            msg_buffer <= 64'd0;
            src_byte_cnt <= 3'd0;
            msg_buf_full <= 1'b0;
        end else begin
            //1 cycle default pulse
            hdr_valid <= 1'b0;
            msg_buf_full <= 1'b0;

            //In Idle: Wait for Start Header Byte 0
            if (state_code == 3'b000) begin
                src_byte_cnt <= 3'd0;
                if (rx_valid_shared) begin
                    header_in <= rx_data_shared;
                    hdr_valid <= 1'b1;
                    if (rx_data_shared[1:0] == 2'b01) begin
                        header_reg <= rx_data_shared; //Latch active recieving scheme from header --- THIS WILL ALWAYS LOOP FAIL IF SOURCE STREAM DOES NOT HAVE THIS SIGNATURE 2'b01 ----
                    end
                end
            end

            //In RD_SOURCE: Differentiate End Header vs 8-byte Data stream
            else if (state_code == 3'b001) begin
                if (rx_valid_shared) begin
                    //If buffer is empty and incoming byte has EOS high with sync bits 2'b01
                    if ((src_byte_cnt == 3'd0) && (rx_data_shared[7] == 1'b1) && (rx_data_shared[1:0] == 2'b01)) begin
                        header_in <= rx_data_shared;
                        hdr_valid <= 1'b1; // Trigger FSM to return tp IDLE
                    end else begin
                        //Shift in payload bytes (MSB first)
                        msg_buffer <= {msg_buffer[55:0], rx_data_shared};
                        if (src_byte_cnt == 3'd7) begin
                            src_byte_cnt <= 3'd0;
                            msg_buf_full <= 1'b1;   //All 8 bytes have been recieved
                        end else begin
                            src_byte_cnt <= src_byte_cnt + 1'b1; 
                        end
                    end
                end
            end
        end
    end
    // Serialize data to Sink PC (Tx#2 - 9 bytes)
    // 65 bite parity codeword needs 9 bytes (65 data bytes + 7 zer0 pads)
    logic [71:0] tx_snk_shift_reg;
    logic [3:0] tx_snk_bytes_left;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_snk_shift_reg <= 72'd0;
            tx_snk_bytes_left <= 4'd0;
            tx_start_snk <= 1'b0;
            tx_data_snk <= 8'd0;
            tx_snk_done <= 1'b0;
        end else begin
            tx_start_snk <= 1'b0;
            tx_snk_done <= 1'b0;

            //Trigger on entry to Tx_Snk_encoded
            if (tx_snk_start) begin
                //65 bit codeword goes into 72 bits: top 65 bits are codeword
                tx_snk_shift_reg <= {encoded_codeword, 7'b0000000};
                tx_data_snk <= encoded_codeword[64:57]; //Send Byte 0 
                tx_start_snk <= 1'b1;
                tx_snk_bytes_left <= 4'd8; //There are 8 bytes remaining
            end else if (tx_snk_bytes_left > 0) begin
                if (tx_done_shared) begin
                    tx_data_snk <= tx_snk_shift_reg[63:56];
                    tx_snk_shift_reg <= {tx_snk_shift_reg[63:0], 8'h00};
                    tx_start_snk <= 1'b1;
                    tx_snk_bytes_left <= tx_snk_bytes_left - 1'b1; 
                    if (tx_snk_bytes_left == 4'd1) begin
                        tx_snk_done <= 1'b1; //All 9 bytes have been serialized
                    end
                end
            end
        end
    end

    // Sink Return Buffer (Rx#2 - 9 bytes)

    logic [71:0] snk_buffer;
    logic [3:0] snk_byte_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snk_buffer <= 72'd0;
            snk_byte_cnt <= 4'd0;
            snk_buf_full <= 1'b0;
        end else begin
            snk_buf_full <= 1'b0;
            if (state_code == 3'b100) begin //RD_SNK_Corrupt
                if (rx_valid_shared) begin
                    snk_buffer <= {snk_buffer[63:0], rx_data_shared};
                    if(snk_byte_cnt == 4'd8) begin //9th Byte recieved
                        snk_byte_cnt <= 4'd0;
                        snk_buf_full <= 1'b1;
                    end else begin
                        snk_byte_cnt <= snk_byte_cnt + 1'b1;
                    end
                end
            end else begin
                snk_byte_cnt <= 4'd0;
            end
        end
    end

    //Recovered Data Serialized to be sent to Source PC (Tx#1) - 8 bytes with LED feedback

    logic [63:0] tx_src_shift_reg;
    logic [3:0] tx_src_bytes_left; 

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            recovered_buffer <= 64'd0;
            tx_src_shift_reg <= 64'd0;
            tx_src_bytes_left <= 4'd0;
            tx_start_src <= 1'b0;
            tx_data_src <= 8'b0;
            tx_src_done <= 1'b0;
            led_error <= 1'b0;
        end else begin
            tx_start_src <= 1'b0;
            tx_src_done <= 1'b0;

            // Latch decoded data and detect any error 
            if (state_code == 3'b101) begin //Decode Corrupt
                if (dec_done) begin
                    recovered_buffer <= decoded_payload;
                    if (parity_error_raw) begin
                        led_error <= 1'b1; // LED indicator to latch
                    end
                end
            end
            //Error to be cleared when returning to IDLE state for new data stream
            if (state_code == 3'b000) begin
                led_error <= 1'b0;
            end

            if (tx_src_start) begin
                tx_src_shift_reg <= recovered_buffer;
                tx_data_src <= recovered_buffer[63:56]; //Send byte 0
                tx_start_src <= 1'b1;
                tx_src_bytes_left <= 4'd7; //7 bytes are remaining
            end else if (tx_src_bytes_left > 0) begin
                if (tx_done_shared) begin
                    tx_data_src <= tx_src_shift_reg[55:48];
                    tx_src_shift_reg <= {tx_src_shift_reg[55:0], 8'h00};
                    tx_start_src <= 1'b1;
                    tx_src_bytes_left <= tx_src_bytes_left - 1'b1;
                    if (tx_src_bytes_left == 4'd1) begin
                        tx_src_done <= 1'b1; //All data (8 bytes) returned to Source PC
                    end
                end
            end
        end
    end
endmodule
