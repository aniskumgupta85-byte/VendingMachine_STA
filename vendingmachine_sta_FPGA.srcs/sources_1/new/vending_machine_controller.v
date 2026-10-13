`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.10.2026 00:51:38
// Design Name: 
// Module Name: vending_machine_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module vending_machine_controller #(
    parameter PRICE_A = 8'd10, // Item 0
    parameter PRICE_B = 8'd15, // Item 1
    parameter PRICE_C = 8'd20  // Item 2
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] coin_in,     // 2'b01 = 5 units, 2'b10 = 10 units
    input  wire       coin_valid,  // Clean 1-cycle strobe
    input  wire [1:0] item_sel,    // 00: A, 01: B, 10: C
    input  wire       sel_valid,   // Clean 1-cycle strobe
    input  wire       cancel_btn,  // Clean 1-cycle strobe
    output reg  [2:0] dispense,    // One-hot dispense actuators
    output reg  [7:0] change_out,  // Calculated refund/change
    output reg  [7:0] balance      // Live balance for display
);

    // One-Hot State Encoding
    localparam [4:0] S_IDLE        = 5'b00001,
                     S_ACCUMULATE  = 5'b00010,
                     S_CHECK_FUNDS = 5'b00100,
                     S_DISPENSE    = 5'b01000,
                     S_RETURN      = 5'b10000;

    reg [4:0] current_state, next_state;

    // Registers to store the selection so releasing the button doesn't corrupt logic
    reg [1:0] latched_item;
    reg [7:0] latched_price;

    // Convert raw coin input to numerical credit
    wire [7:0] coin_value = (coin_in == 2'b01) ? 8'd5  :
                            (coin_in == 2'b10) ? 8'd10 : 8'd0;

    // Decode price combinationally for latching
    reg [7:0] decoded_price;
    always @(*) begin
        case (item_sel)
            2'b00:   decoded_price = PRICE_A;
            2'b01:   decoded_price = PRICE_B;
            2'b10:   decoded_price = PRICE_C;
            default: decoded_price = 8'd255;
        endcase
    end

    // BLOCK 1: Sequential State & Latch Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            latched_item  <= 2'b00;
            latched_price <= 8'd0;
        end else begin
            current_state <= next_state;
            
            // Latch item and price safely when the selection button is pressed
            if ((current_state == S_ACCUMULATE || current_state == S_IDLE) && sel_valid) begin
                latched_item  <= item_sel;
                latched_price <= decoded_price;
            end
        end
    end

    // BLOCK 2: Next-State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (coin_valid)
                    next_state = S_ACCUMULATE;
                else if (sel_valid)
                    next_state = S_CHECK_FUNDS; // In case user selects first with 0 balance
            end

            S_ACCUMULATE: begin
                if (cancel_btn)
                    next_state = S_RETURN;
                else if (sel_valid)
                    next_state = S_CHECK_FUNDS;
            end

            S_CHECK_FUNDS: begin
                // Compare accumulated credit with the latched price
                if (balance >= latched_price)
                    next_state = S_DISPENSE;
                else
                    next_state = S_ACCUMULATE; // Not enough coins: keep waiting
            end

            S_DISPENSE: begin
                next_state = S_RETURN;
            end

            S_RETURN: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // BLOCK 3: Datapath & Glitch-Free Registered Outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            balance    <= 8'd0;
            change_out <= 8'd0;
            dispense   <= 3'b000;
        end else begin
            case (current_state)
                S_IDLE: begin
                    dispense   <= 3'b000;
                    change_out <= 8'd0;
                    if (coin_valid)
                        balance <= coin_value;
                    else
                        balance <= 8'd0;
                end

                S_ACCUMULATE: begin
                    dispense   <= 3'b000;
                    change_out <= 8'd0;
                    if (coin_valid)
                        balance <= balance + coin_value;
                end

                S_CHECK_FUNDS: begin
                    dispense <= 3'b000;
                    // Balance holds stable while checking
                end

                S_DISPENSE: begin
                    // Trigger actuator using the latched selection
                    dispense[latched_item] <= 1'b1;
                    // Deduct exact price from accumulated credit
                    balance                <= balance - latched_price;
                end

                S_RETURN: begin
                    dispense   <= 3'b000;
                    change_out <= balance; // Any remaining amount is returned as change
                    balance    <= 8'd0;
                end

                default: begin
                    dispense   <= 3'b000;
                    change_out <= 8'd0;
                    balance    <= 8'd0;
                end
            endcase
        end
    end

endmodule