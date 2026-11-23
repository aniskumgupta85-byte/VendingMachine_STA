`timescale 1ns / 1ps

module vending_machine_controller #(
    parameter PRICE_A    = 8'd10, // Item 0
    parameter PRICE_B    = 8'd15, // Item 1
    parameter PRICE_C    = 8'd20, // Item 2
    parameter INIT_STOCK = 4'd5   // Initial stock per item
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] coin_in,      // 2'b01 = 5 units, 2'b10 = 10 units
    input  wire       coin_valid,   // Clean 1-cycle strobe
    input  wire [1:0] item_sel,     // 00: A, 01: B, 10: C
    input  wire       sel_valid,    // Clean 1-cycle strobe
    input  wire       cancel_btn,   // Clean 1-cycle strobe
    output reg  [2:0] dispense,     // One-hot dispense actuators
    output reg  [7:0] change_out,   // Calculated refund/change
    output reg  [7:0] balance,      // Live balance for display
    output reg        out_of_stock  // High if selected item is empty
);

    // One-Hot State Encoding
    localparam [4:0] S_IDLE        = 5'b00001,
                     S_ACCUMULATE  = 5'b00010,
                     S_CHECK_FUNDS = 5'b00100,
                     S_DISPENSE    = 5'b01000,
                     S_RETURN      = 5'b10000;

    reg [4:0] current_state, next_state;

    // Latched selection and inventory registers
    reg [1:0] latched_item;
    reg [7:0] latched_price;
    reg [3:0] stock [0:2];

    // Convert raw coin input to numerical credit (with overflow protection)
    wire [7:0] coin_value = (coin_in == 2'b01) ? 8'd5  :
                            (coin_in == 2'b10) ? 8'd10 : 8'd0;

    wire [7:0] next_balance = (coin_valid && (balance <= 8'd245)) ? 
                              (balance + coin_value) : balance;

    // Decode price combinationally
    reg [7:0] decoded_price;
    always @(*) begin
        case (item_sel)
            2'b00:   decoded_price = PRICE_A;
            2'b01:   decoded_price = PRICE_B;
            2'b10:   decoded_price = PRICE_C;
            default: decoded_price = 8'd255;
        endcase
    end

    // Helper signal for stock availability of latched item
    wire item_in_stock = (latched_item < 2'd3) && (stock[latched_item] > 4'd0);

    // BLOCK 1: Sequential State & Latch Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            latched_item  <= 2'b00;
            latched_price <= 8'd0;
        end else begin
            current_state <= next_state;

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
                if (sel_valid)
                    next_state = S_CHECK_FUNDS; // Handles both sel_valid alone and sel_valid + coin_valid
                else if (coin_valid)
                    next_state = S_ACCUMULATE;
            end

            S_ACCUMULATE: begin
                if (cancel_btn)
                    next_state = S_RETURN;
                else if (sel_valid)
                    next_state = S_CHECK_FUNDS;
            end

            S_CHECK_FUNDS: begin
                if (!item_in_stock)
                    next_state = (next_balance > 8'd0) ? S_ACCUMULATE : S_IDLE;
                else if (next_balance >= latched_price)
                    next_state = S_DISPENSE;
                else
                    next_state = (next_balance > 8'd0) ? S_ACCUMULATE : S_IDLE;
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

    // BLOCK 3: Datapath, Inventory & Glitch-Free Registered Outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            balance      <= 8'd0;
            change_out   <= 8'd0;
            dispense     <= 3'b000;
            out_of_stock <= 1'b0;
            stock[0]     <= INIT_STOCK;
            stock[1]     <= INIT_STOCK;
            stock[2]     <= INIT_STOCK;
        end else begin
            case (current_state)
                S_IDLE: begin
                    dispense <= 3'b000;
                    if (coin_valid || sel_valid) begin
                        balance      <= next_balance;
                        change_out   <= 8'd0;
                        out_of_stock <= 1'b0;
                    end
                end

                S_ACCUMULATE: begin
                    dispense <= 3'b000;
                    balance  <= next_balance;
                    // Clear out_of_stock only when user tries a new selection or inserts coins
                    if (sel_valid || coin_valid)
                        out_of_stock <= 1'b0;
                end

                S_CHECK_FUNDS: begin
                    dispense     <= 3'b000;
                    balance      <= next_balance;
                    out_of_stock <= !item_in_stock;
                end

                S_DISPENSE: begin
                    dispense[latched_item] <= 1'b1;
                    balance                <= balance - latched_price;
                    stock[latched_item]    <= stock[latched_item] - 4'd1;
                    out_of_stock           <= 1'b0;
                end

                S_RETURN: begin
                    dispense     <= 3'b000;
                    change_out   <= balance;
                    balance      <= 8'd0;
                    out_of_stock <= 1'b0;
                end

                default: begin
                    dispense     <= 3'b000;
                    change_out   <= 8'd0;
                    balance      <= 8'd0;
                    out_of_stock <= 1'b0;
                end
            endcase
        end
    end

endmodule