`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/18/2026 10:39:57 AM
// Design Name: 
// Module Name: led_driver
// Project Name: BCED  
// Target Devices: Digilent Nexys A7-100T (xc7a100tcsg324-1)
// Tool Versions: 
// Description: Display 8-bit diagnostic value as to hex digits on the 7 segment display
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Display Sections for each scheme
// - AN1 (Left Digit, data_in[7:4])
// 0: IDLE
// 1: RD_SOURCE
// 2: ENCODE_DATA
// 3: TX_SNK_ENCODED
// 4: RD_SNK_CORRUPT 
// 5: DECODE_CORRUPT
// 6: TX_SRC
// - AN0 (Right Digit, data_in[3:0])
// 0 - Simple parity
// 1 - 4 Non-Cyclic Hamming (7,4), (15,11), (31,26), (63,57)
// 5 - 8 Cyclic Hamming (7,4), (15,11), (31,26), (63,57)
// 9 Binary Golay
//////////////////////////////////////////////////////////////////////////////////


module led_driver(
    input clk, // 100 MHz clock 
    input wire rst_n, //Active Low -asynch 
    input [7:0] data_in, // 8 bit data [7:4] = Left anode (digit) [3:0] = Right anode (right)
    output reg [7:0] an, //Enable lines for anodes function on active low architecture (0 = ON)
    output reg [6:0] seg //Cathode segment (active-low)
    );

    //Refresh Counter:
    // Need a switching rate for anodes to display correctly. 
    // Currently with a 100Mhz clock we can get 762.9 Hz

    reg [16:0] refresh_counter;
    wire digital_sel;
    reg [3:0] digital_value;
    reg [7:0] data_latched;


    assign digital_sel = refresh_counter[16]; //MSB will switch between left and right digit (AN0 and AN1)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_latched <= 8'h00;
        else begin
            data_latched <= data_in;
        end
    end

    //Refresh counter 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            refresh_counter <= 17'd0;
        else begin
            refresh_counter <= refresh_counter + 1'b1;
        end
    end

    // Digit active-low anode selection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digital_value <= 4'h0;
            an <= 8'b11111111; //All display 1 during an active reset
        end else begin
            if(digital_sel == 1'b0) begin
                digital_value <= data_latched[3:0]; //Right Digit Scheme ID
                an <= 8'b11111110; //AN0 is enabled/high only
            end else begin
                digital_value <= data_latched[7:4]; //Left Digit: FSM State ID
                an <= 8'b11111101; //AN1 is enabled/high 
            end
        end
    end

    //Hexadecimal to 7 segment decoder (Active low: 0 = lit, 1 = dark)
    // Mapping: seg = {CA, CB, CC, CD, CE, CF, CG}
    always @(*) begin //Run whenever there is changes given from input
        if(!rst_n) begin
        seg <= 8'b11111111; //all segments are off
        end else begin
            case (digital_value)
                4'h0: seg <= 8'b0000001; //0
                4'h1: seg <= 8'b1001111; //1
                4'h2: seg <= 8'b0010010; //2
                4'h3: seg <= 8'b0000110; //3
                4'h4: seg <= 8'b1001100; //4
                4'h5: seg <= 8'b0100100; //5
                4'h6: seg <= 8'b0100000; //6
                4'h7: seg <= 8'b0001111; //7
                4'h8: seg <= 8'b0000000; //8
                4'h9: seg <= 8'b0000100; //9
                4'hA: seg <= 8'b0001000; //A
                4'hB: seg <= 8'b1100000; //B
                4'hC: seg <= 8'b0110001; //C
                4'hD: seg <= 8'b1000010; //D
                4'hE: seg <= 8'b0110000; //E
                4'hF: seg <= 8'b0111000; //F
                default: seg <= 8'b11111111; 
            endcase
        end
    end
endmodule
