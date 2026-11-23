
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Capstone
// Engineer: Kendrick Chevez
//
// Create Date: 11/19/2026 10:40:21 PM
// Design Name: UART Transmitter and Receiver Testbench
// Module Name: tb_uart_tx_rx
// Project Name: BCED
// Target Devices: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Tool Versions: Vivado 2024.1
// Description: This testbench checks if the UART transmitter sends data
// correctly and if the UART receiver receives the same data.
//
// Dependencies: uart_tx.sv, uart_rx.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Behavioral simulation only. No synthesis required.
//
//////////////////////////////////////////////////////////////////////////////////

module tb_uart_tx_rx;

    //clock and reset
    logic clk = 0;  //clock used by both UART modules
    logic rst_n = 0;  //active-low reset, 0 means both modules are being reset, 1 means they can operate normally

    //UART transmitter inputs
    logic tx_start = 0;  //tells the transmitter to start sending a byte
    logic [7:0] tx_data = 0;  //8-bit data that we want to transmit

    //UART transmitter outputs
    wire tx_pin;  //serial output that sends the data one bit at a time
    wire tx_busy;  //high while the transmitter is sending data
    wire tx_done;  //goes high for one cycle when transmission is finished

    //UART receiver inputs
    logic rx_en = 1;  //enables the receiver so it can receive data

    //UART receiver outputs
    wire [7:0] rx_data;  //8-bit data received from the transmitter
    wire rx_byte_valid;  //goes high for one cycle when a complete byte is received 
    wire rx_busy;  //high while the receiver is receiving data

    //counts how many tests fail
    //this increases by one whenever the received data does not match the expected data
    integer failed_count = 0;

    //connect the testbench signals to the UART transmitter module
    //u_tx is the transmitter that we are testing
    uart_tx u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_pin(tx_pin),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );

    //connect the testbench signals to the UART receiver module
    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_en(rx_en),
        .rx_pin(tx_pin),  //we connect tx_pin directly to rx_pin so the receiver gets the data sent by the transmitter
        .rx_data(rx_data),
        .rx_byte_valid(rx_byte_valid),
        .rx_busy(rx_busy)
    );

    //clock generation
    //clock changes every 5 ns, giving a 10 ns period (100 MHz)
    always #5 clk = ~clk;

    //test sequence
    initial begin

        //before testing, we need to reset both UART modules so they start in IDLE
        //wait for 2 falling clock edges before releasing reset
        repeat (2) @(negedge clk);
        rst_n = 1;  //release reset so both modules can start

        //for this tests and the rest of the tests, we change the inputs on the falling edge
        //because the UART modules check the signals on the rising edge
        //this makes sure the inputs are ready before the next rising edge
        
        //test 1: transmit and receive A5
        //send A5 through the transmitter and check if the receiver gets the same byte
        //I picked A5 because it has a mix of zeros and ones
        @(negedge clk);
        tx_data = 8'hA5;  //set the data to A5 in hexadecimal, which is 10100101 in binary
        tx_start = 1;  //tell the transmitter to start sending the byte

        @(negedge clk);
        tx_start = 0;  //clear the start signal after one cycle

        //wait until the receiver finishes receiving the byte
        wait(rx_byte_valid == 1);  //goes high when the received data is ready
        #1;  //gives the simulator time to update the received data before checking it

        //check if the received data matches the byte we transmitted
        if (rx_data !== 8'hA5) begin
            $display("Transmit and Receive A5 (mix of zeros and ones) failed");
            failed_count++;
        end else begin
            $display("Transmit and Receive A5 (mix of zeros and ones) passed");
        end

        //wait until the transmitter finishes before sending another byte
        wait(tx_done == 1);
        @(negedge clk);

        //test 2: transmit and receive 00
        //send 00 to check if the receiver correctly receives a byte with all zeros
        tx_data = 8'h00;  //set the data to 00 in hexadecimal, which is 00000000 in binary
        tx_start = 1;  //start transmitting the second byte

        @(negedge clk);
        tx_start = 0;  //clear the start signal after one clock cycle

        //wait until the receiver finishes receiving the second byte
        wait(rx_byte_valid == 1);
        #1;  //give the simulator time to update the received before checking it

        //check if the received data matches 00
        if (rx_data !== 8'h00) begin
            $display("Transmit and Receive 00 (all zeros) failed");
            failed_count++;
        end else begin
            $display("Transmit and Receive 00 (all zeros) passed");
        end

        //wait until transmission is finished before starting the next test
        wait(tx_done == 1);
        @(negedge clk);

        //test 3: transmit and receive FF
        //send FF to check if the receiver correctly receives a byte with all ones
        tx_data = 8'hFF;  //set the data to FF in hexadecimal, which is 11111111 in binary
        tx_start = 1;  //start transmitting the third byte

        @(negedge clk);
        tx_start = 0;  //clear the start signal after one clock cycle

        //wait until the receiver finishes receiving the third byte
        wait(rx_byte_valid == 1);
        #1;  //give the simulator time to update the received data before checking it

        //check if the received data matches FF
        if (rx_data !== 8'hFF) begin
            $display("Transmit and Receive FF (all ones) failed");
            failed_count++;
        end else begin
            $display("Transmit and Receive FF (all ones) passed");
        end

        //wait until the last transmission is finished
        wait(tx_done == 1);

        //test results
        if (failed_count == 0) begin
            $display("All UART Tx/Rx test cases passed!");
        end else begin
            $display("%0d UART test cases failed.", failed_count);
        end

        #20000;  //wait 20000 ns before ending the simulation to see FF being reconstructed clearly
        $finish;
  
    end

endmodule
