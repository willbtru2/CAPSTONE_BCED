`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Capstone
// Engineer: Kendrick Chevez
//
// Create Date: 11/16/2026 11:05:35 PM
// Design Name: Finite State Machine Testbench for BCED
// Module Name: tb_bced_fsm
// Project Name: BCED
// Target Devices: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Tool Versions: 
// Description: This testbench is used to verify the state transitions of the
// BCED finite state machine. It simulates the input control signals and checks
// if the FSM moves to the correct states. The testbench also checks that the
// FSM returns to RD_SOURCE and IDLE when the corresponding signals are received.
//
// Dependencies: bced_fsm.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Behavioral simulation only. No synthesis required.
//
//////////////////////////////////////////////////////////////////////////////////

module tb_bced_fsm;

    //clock and reset
    logic clk = 0;  //tells the FSM when to update its state
    logic rst_n = 0;  //active-low reset, 0 means the FSM is being reset, 1 means the FSM can operate normally

    //FSM inputs
    logic [7:0] header = 0;  //8-bit header, tells the FSM whether a message starts or ends
    logic hdr_valid = 0;  //high when a valid header is received
    
    //status signals that tell the FSM when an operation is finished
    //in the actual BCED, different modules will generate them
    logic msg_buf_full = 0;  //source data has been sorted in the buffer, and indicates that the source data is ready to encode
    logic enc_done = 0;  //encoder finished encoding
    logic tx_snk_done = 0;  //encoded data was sent to the sink
    logic snk_buf_full = 0;  //corrupted data was received from the sink and is ready to decode
    logic dec_done = 0;  //decoder finished decoding
    logic tx_src_done = 0;  //decoded data was sent back to the source

    // FSM output
    wire [2:0] state_code;  //shows the current state using 3 bits

    //Enable signals
    wire rx_src_en;
    wire src_buf_write;
    wire rx_snk_en;
    wire snk_buf_wr; 

    //Pulse signals
    wire mode_reg_latch;
    wire enc_start;
    wire tx_snk_start;
    wire dec_start; 
    wire tx_src_start;

    //counts how many tests fail
    //this increases by one whenever the FSM enters an unexpected state
    integer failed_count = 0;  

    //connect the testbench signals to the FSM module
    //dut(design under test) is the FSM that we are testing
    bced_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .header(header),
        .hdr_valid(hdr_valid),
        .msg_buf_full(msg_buf_full),
        .enc_done(enc_done),
        .tx_snk_done(tx_snk_done),
        .snk_buf_full(snk_buf_full),
        .dec_done(dec_done),
        .tx_src_done(tx_src_done),
        .state_code(state_code),  //this is connected among the outputs because its just checking the states

        //Connected control outputs
        .rx_src_en(rx_src_en),
        .mode_reg_latch(mode_reg_latch),
        .src_buf_write(src_buf_write),
        .enc_start(enc_start),
        .tx_snk_start(tx_snk_start),
        .rx_snk_en(rx_snk_en),
        .snk_buf_wr(snk_buf_wr),
        .dec_start(dec_start),
        .tx_src_start(tx_src_start)
    );

    //clock generation
    //clock changes every 5 ns, giving a 10 ns period(100 MHz)
    always #5 clk = ~clk;

    //test sequence
    initial begin

        //before testing, we need to reset the FSM so it starts in IDLE, then we release the reset
        //and begin checking the state transtions 
        //wait for 2 falling clock edges before releasing reset
        repeat (2) @(negedge clk);
        rst_n = 1;  //release reset so the FSM can start

        //check if the FSM starts in IDLE (000) 
        @(posedge clk);
        #1;  //we use #1's in this program after the rising clock edge to give the simulator time to update the FSM state before checking the result
             //which is the current state_code to make sure the FSM moved to the correct state
        if (state_code !== 3'b000) begin
            $display("IDLE failed");
            failed_count++;
        end else begin
            $display("IDLE passed");
        end

        //for this test and the rest of the tests we change the inputs on the falling edge because the FSM checks the signals
        //on the rising edge. By changing them on the falling edge, they are already set before the next rising edge, and also
        //this avoids changing the signals at the exact same moment the FSM tries to read them
        //test 1: IDLE -> RD_SOURCE
        //send a start header so the FSM begins receiving source data
        @(negedge clk);
        //set the header to 08 in hexadecimal, which is 00001000 in binary
        //bit 7 is 0, meaning this is a start header
        header = 8'h09; //Binary: 0000_1001 (sync bits make it 8'h01)  
        hdr_valid = 1;  //header is valid

        @(posedge clk);
        #1;
        //RD_SOURCE has state code 001
        if (state_code !== 3'b001) begin
            $display("RD_SOURCE failed");
            failed_count++;
        end else begin
            $display("RD_SOURCE passed");
        end

        if (src_buf_write !== 1'b1) begin
            $display("Fail src_buf_write is 0, expected 1 in RD_SOURCE state");
            failed_count++;
        end else begin
            $display("src_buf_write asserted correctly");
        end

        //test 2: RD_SOURCE -> ENCODE_DATA
        //tell the FSM that the source buffer is full 
        @(negedge clk);
        hdr_valid = 0;  //header is no longer valid
        msg_buf_full = 1;  //source data is ready for encoding

        @(posedge clk);
        #1;
        //ENCODE_DATA has state code 010
        if (state_code !== 3'b010) begin
            $display("ENCODE_DATA failed");
            failed_count++;
        end else begin
            $display("ENCODE_DATA passed");
        end

        if (enc_start !== 1'b1)begin
            $display("enc_start did NOT pulse HIGH on entering ENCODE_DATA!");
            failed_count++;
        end else begin
            $display("Pass: enc_start pulsed HIGH on Cycle 1"); 
        end

        @(posedge clk);
        #1;
        if(enc_start != 1'b0)begin
            $display("Failed: enc_start is still High! Expected 0 on 2nd clock into encode data"); 
            failed_count++;
        end else begin 
            $display("Passed enc_start cleared to 0 on Cycle 2 (valid 1-cycle pulse)");
        end



        //test 3: ENCODE_DATA -> TX_SNK_ENCODED
        //tell the FSM that the encoder finished
        @(negedge clk);
        msg_buf_full = 0;  //clear the previous buffer signal
        enc_done = 1;  //encoding is complete

        @(posedge clk);
        #1;
        //TX_SNK_ENCODED has state code 011
        if (state_code !== 3'b011) begin
            $display("TX_SNK_ENCODED failed");
            failed_count++;
        end else begin
            $display("TX_SNK_ENCODED passed");
        end


        //test 4: TX_SNK_ENCODED -> RD_SNK_CORRUPT
        //tell the FSM that the encoded data was sent to the sink
        @(negedge clk);
        enc_done = 0;  //clear the encoder done signal
        tx_snk_done = 1;  //transmission to sink is complete

        @(posedge clk);
        #1;
        //RD_SNK_CORRUPT has state code 100
        if (state_code !== 3'b100) begin
            $display("RD_SNK_CORRUPT failed");
            failed_count++;
        end else begin
            $display("RD_SNK_CORRUPT passed");
        end


        //test 5: RD_SNK_CORRUPT -> DECODE_CORRUPT
        //tell the FSM that the corrupted block was received
        @(negedge clk);
        tx_snk_done = 0;  //clear the previous transmission signal
        snk_buf_full = 1;  //sink data is ready decoding

        @(posedge clk);
        #1;
        //DECODE_CORRUPT has state code 101
        if (state_code !== 3'b101 || dec_start !== 1'b1) begin
            $display("DECODE_CORRUPT failed");
            failed_count++;
        end else begin
            $display("DECODE_CORRUPT passed and dec_start pulsed high");
        end

        //Verify pulse cleared
        @(posedge clk); 
        #1; 
        if (dec_start !== 1'b0) begin 
            $display("Fail: dec_start stuck HIGH on Cycle 2!");
            failed_count++; 
        end else begin 
            $display("Passed: dec_start cleared on Cycle 2");
        end

        //test 6: DECODE_CORRUPT -> TX_SRC
        //tell the FSM that the decoder finished
        @(negedge clk);
        #1;
        snk_buf_full = 0;  //clear the sink buffer signal
        dec_done = 1;  //decoding is complete

        @(posedge clk);
        #1;
        //TX_SRC has state code 110
        if (state_code !== 3'b110) begin
            $display("TX_SRC failed");
            failed_count++;
        end else begin
            $display("TX_SRC passed");
        end


        //test 7: TX_SRC -> RD_SOURCE
        //tell the FSM that the decoded data was sent to the source
        //the FSM should return to RD_SOURCE to receive another block
        @(negedge clk);
        dec_done = 0;  //clear the decoder done signal
        tx_src_done = 1;  //transmission to source is complete

        @(posedge clk);
        #1;

        //Set header to 0xff (bit 7 = 1)
        header = 8'hFF;
        hdr_valid = 0; // No valid header  
        //RD_SOURCE has state code 001
        if (state_code !== 3'b001) begin
            $display("Return to RD_SOURCE failed");
            failed_count++;
        end else begin
            $display("Return to RD_SOURCE passed");
        end


        //test 8: RD_SOURCE -> IDLE
        //send an end header to tell the FSM that the message is finished
        @(negedge clk);
        tx_src_done = 0;  //clear the transmission done signal
        //set the header to 80 in hexadecimal, which is 10000000 in binary
        //bit 7 is 1, meaning this is an end header, which tells the FSM
        //that the message is finished and no more data needs to be received
        header = 8'h81; //Binary 1000_0001 (Bit 7 = 1 + Sync_signature bits = 2'b01)
        hdr_valid = 1;  //header is valid

        @(posedge clk);
        #1;
        //IDLE has state code 000
        if (state_code !== 3'b000) begin
            $display("Return to IDLE failed");
            failed_count++;
        end else begin
            $display("Return to IDLE passed");
        end


        //test results
        if (failed_count == 0) begin
            $display("All FSM test cases passed!");
        end else begin
            $display("%0d FSM test cases failed.", failed_count);
        end

        #20  //wait 20 ns so the final IDLE state is easier to see
        $finish;

    end

endmodule
