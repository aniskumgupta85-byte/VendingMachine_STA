`timescale 1ns / 1ps

module tb_vending_machine;

    // Parameters matching DUT (INIT_STOCK set to 2 for fast depletion testing)
    localparam PRICE_A    = 8'd10;
    localparam PRICE_B    = 8'd15;
    localparam PRICE_C    = 8'd20;
    localparam INIT_STOCK = 4'd2;

    // DUT Inputs
    reg        clk;
    reg        rst_n;
    reg  [1:0] coin_in;
    reg        coin_valid;
    reg  [1:0] item_sel;
    reg        sel_valid;
    reg        cancel_btn;

    // DUT Outputs
    wire [2:0] dispense;
    wire [7:0] change_out;
    wire [7:0] balance;
    wire       out_of_stock;

    // Test Tracking Counters
    integer pass_count = 0;
    integer fail_count = 0;

    // Instantiate Device Under Test (DUT)
    vending_machine_controller #(
        .PRICE_A(PRICE_A),
        .PRICE_B(PRICE_B),
        .PRICE_C(PRICE_C),
        .INIT_STOCK(INIT_STOCK)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .coin_in(coin_in),
        .coin_valid(coin_valid),
        .item_sel(item_sel),
        .sel_valid(sel_valid),
        .cancel_btn(cancel_btn),
        .dispense(dispense),
        .change_out(change_out),
        .balance(balance),
        .out_of_stock(out_of_stock)
    );

    // 100 MHz Clock Generation (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // Helper Tasks for Clean Stimulus & Self-Checking Assertions
    // =========================================================================

    task reset_dut;
        begin
            rst_n      = 0;
            coin_in    = 2'b00;
            coin_valid = 0;
            item_sel   = 2'b00;
            sel_valid  = 0;
            cancel_btn = 0;
            repeat (3) @(posedge clk);
            #1 rst_n = 1;
            @(posedge clk);
        end
    endtask

    // Insert a single coin (2'b01 = 5, 2'b10 = 10) for 1 clock cycle
    task insert_coin(input [1:0] c_type);
        begin
            @(negedge clk);
            coin_in    = c_type;
            coin_valid = 1'b1;
            @(negedge clk);
            coin_in    = 2'b00;
            coin_valid = 1'b0;
        end
    endtask

    // Press item selection button for 1 clock cycle
    task select_item(input [1:0] item);
        begin
            @(negedge clk);
            item_sel  = item;
            sel_valid = 1'b1;
            @(negedge clk);
            item_sel  = 2'b00;
            sel_valid = 1'b0;
        end
    endtask

    // Press cancel button for 1 clock cycle
    task press_cancel;
        begin
            @(negedge clk);
            cancel_btn = 1'b1;
            @(negedge clk);
            cancel_btn = 1'b0;
        end
    endtask

    // Self-checking verification task
    task check_state(
        input [255:0] test_name,
        input [2:0]   exp_dispense,
        input [7:0]   exp_change,
        input [7:0]   exp_balance,
        input         exp_oos
    );
        begin
            #1; // Sample just after clock edge
            if (dispense     === exp_dispense &&
                change_out   === exp_change   &&
                balance      === exp_balance  &&
                out_of_stock === exp_oos) begin
                $display("[PASS] %0s | disp=%b change=%0d bal=%0d oos=%b",
                         test_name, dispense, change_out, balance, out_of_stock);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s", test_name);
                $display("       Expected: disp=%b change=%0d bal=%0d oos=%b",
                         exp_dispense, exp_change, exp_balance, exp_oos);
                $display("       Actual  : disp=%b change=%0d bal=%0d oos=%b",
                         dispense, change_out, balance, out_of_stock);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("=== Starting Vending Machine Self-Checking Testbench ===");
        reset_dut();

        // ---------------------------------------------------------------------
        // TEST 1: Exact Payment (Item B = 15 -> Insert 10 + 5)
        // ---------------------------------------------------------------------
        insert_coin(2'b10); // +10
        insert_coin(2'b01); // +5 (Total = 15)
        select_item(2'b01); // Select Item B (Price = 15)
        @(posedge clk);     // Enter S_CHECK_FUNDS -> S_DISPENSE on next edge
        @(posedge clk);     // Now in S_DISPENSE
        check_state("Test 1a: Exact Payment Dispense (Item B)", 3'b010, 8'd0, 8'd0, 1'b0);
        @(posedge clk);     // Now in S_RETURN
        check_state("Test 1b: Exact Payment Change Return",     3'b000, 8'd0, 8'd0, 1'b0);

        // ---------------------------------------------------------------------
        // TEST 2: Overpayment & Exact Change Return (Item A = 10 -> Insert 10 + 10)
        // ---------------------------------------------------------------------
        insert_coin(2'b10); // +10
        insert_coin(2'b10); // +10 (Total = 20)
        select_item(2'b00); // Select Item A (Price = 10)
        @(posedge clk);     // S_CHECK_FUNDS
        @(posedge clk);     // S_DISPENSE
        check_state("Test 2a: Overpayment Dispense (Item A)",   3'b001, 8'd0,  8'd10, 1'b0);
        @(posedge clk);     // S_RETURN
        check_state("Test 2b: Overpayment Exact Change (10)",   3'b000, 8'd10, 8'd0,  1'b0);

        // ---------------------------------------------------------------------
        // TEST 3: Insufficient Funds & Top-Up (Item C = 20 -> Insert 10 -> Fail -> Insert 10 -> Pass)
        // ---------------------------------------------------------------------
        insert_coin(2'b10); // +10
        select_item(2'b10); // Select Item C (Price = 20) -> Insufficient!
        @(posedge clk);     // S_CHECK_FUNDS
        @(posedge clk);     // Returns to S_ACCUMULATE
        check_state("Test 3a: Insufficient Funds Holds Balance", 3'b000, 8'd0, 8'd10, 1'b0);

        insert_coin(2'b10); // +10 (Total = 20)
        select_item(2'b10); // Select Item C again
        @(posedge clk);     // S_CHECK_FUNDS
        @(posedge clk);     // S_DISPENSE
        check_state("Test 3b: Top-Up Dispense (Item C)",        3'b100, 8'd0, 8'd0,  1'b0);
        @(posedge clk);     // S_RETURN

        // ---------------------------------------------------------------------
        // TEST 4: Mid-Transaction Cancellation (Insert 10 + 5 -> Cancel)
        // ---------------------------------------------------------------------
        insert_coin(2'b10); // +10
        insert_coin(2'b01); // +5 (Total = 15)
        press_cancel();     // Abort transaction
        @(posedge clk);     // Enter S_RETURN
        check_state("Test 4: Cancel Full Refund (15)",          3'b000, 8'd15, 8'd0, 1'b0);

        // ---------------------------------------------------------------------
        // TEST 5: Simultaneous Coin + Selection on Same Clock Cycle
        // ---------------------------------------------------------------------
        @(negedge clk);
        coin_in    = 2'b10; // +10
        coin_valid = 1'b1;
        item_sel   = 2'b00; // Item A (Price = 10)
        sel_valid  = 1'b1;
        @(negedge clk);
        coin_in    = 2'b00;
        coin_valid = 1'b0;
        sel_valid  = 1'b0;
        @(posedge clk);     // S_CHECK_FUNDS
        @(posedge clk);     // S_DISPENSE (Note: Item A stock now hits 0 since INIT_STOCK=2)
        check_state("Test 5: Simultaneous Coin + Select",       3'b001, 8'd0, 8'd0, 1'b0);
        @(posedge clk);     // S_RETURN

        // ---------------------------------------------------------------------
        // TEST 6: Out-of-Stock Detection (Item A stock is now 0)
        // ---------------------------------------------------------------------
        insert_coin(2'b10); // +10
        select_item(2'b00); // Try buying Item A again (Stock = 0!)
        @(posedge clk);     // S_CHECK_FUNDS
        @(posedge clk);     // Transitions to S_ACCUMULATE with out_of_stock = 1
        check_state("Test 6a: Out-of-Stock Flag Asserted",      3'b000, 8'd0, 8'd10, 1'b1);

        // Cancel to recover the 10 units
        press_cancel();
        @(posedge clk);     // S_RETURN
        check_state("Test 6b: Refund After Out-of-Stock",       3'b000, 8'd10, 8'd0, 1'b0);

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        #20;
        $display("========================================================");
        $display("Verification Complete: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================================");
        if (fail_count == 0)
            $display("ALL TESTS PASSED SUCCESSFULLY!");
        else
            $display("SOME TESTS FAILED - INSPECT LOGS ABOVE.");
        $finish;
    end

endmodule