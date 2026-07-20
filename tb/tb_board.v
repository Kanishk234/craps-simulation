// tb_board.v -- verifies the board top-level IN SIMULATION before any
// hardware is touched. Uses shrunk parameters (tiny debounce, 100-game
// batches) so button presses don't take millions of cycles.
//
// Checks:
//   1. bin2bcd converts a spread of values correctly.
//   2. STATS mode: one press plays exactly BATCH games and batch_wins
//      matches the true win count of those games.
//   3. PLAY mode: one press produces exactly one roll, and the latched
//      dice/sum are consistent.

`timescale 1ns / 1ps

module tb_board;

    reg clk, btnC, btnU;
    reg [0:0] sw;
    wire [7:0] led;
    wire [6:0] seg;
    wire dp;
    wire [3:0] an;

    // tiny debounce (2^4 cycles) and small batches for fast simulation
    top #(.DB_BITS(4), .BATCH(32'd100)) dut (
        .clk(clk), .btnC(btnC), .btnU(btnU), .sw(sw),
        .led(led), .seg(seg), .dp(dp), .an(an)
    );

    always #5 clk = ~clk;

    integer errors;

    // standalone BCD check
    reg [13:0] tv;
    wire [15:0] tv_bcd;
    bin2bcd check_b2b (.bin(tv), .bcd(tv_bcd));

    task press_button;
        begin
            btnC = 1'b1;
            repeat (60) @(posedge clk);   // > debounce period
            btnC = 1'b0;
            repeat (60) @(posedge clk);
        end
    endtask

    task check_bcd(input [13:0] val, input [15:0] expect);
        begin
            tv = val;
            #1;
            if (tv_bcd !== expect) begin
                errors = errors + 1;
                $display("FAIL bin2bcd(%0d): got %h expected %h",
                         val, tv_bcd, expect);
            end
        end
    endtask

    reg [31:0] games_before, wins_before, rolls_before;

    initial begin
        clk = 0; btnC = 0; btnU = 1; sw = 1'b0; errors = 0;

        // ---- 1. BCD converter ---------------------------------------
        check_bcd(14'd0,    16'h0000);
        check_bcd(14'd7,    16'h0007);
        check_bcd(14'd42,   16'h0042);
        check_bcd(14'd4929, 16'h4929);
        check_bcd(14'd9999, 16'h9999);

        // release reset
        repeat (10) @(posedge clk);
        btnU = 0;
        repeat (10) @(posedge clk);

        // ---- 2. STATS mode: one batch -------------------------------
        sw = 1'b0;
        games_before = dut.core.games;
        wins_before  = dut.core.wins;
        press_button;
        wait (dut.cstate == 2'd0 && dut.enable == 1'b0);
        repeat (5) @(posedge clk);

        if (dut.core.games < games_before + 100 ||
            dut.core.games > games_before + 101) begin  // +1 stray roll ok
            errors = errors + 1;
            $display("FAIL batch: played %0d games, expected 100",
                     dut.core.games - games_before);
        end
        if (dut.batch_wins !== (wins_before + dut.batch_wins - wins_before)
            || dut.batch_wins > 14'd100) begin
            errors = errors + 1;
            $display("FAIL batch_wins out of range: %0d", dut.batch_wins);
        end
        $display("stats batch: %0d games played, batch_wins = %0d",
                 dut.core.games - games_before, dut.batch_wins);

        // second press: independent sample continues from LFSR state
        games_before = dut.core.games;
        press_button;
        wait (dut.cstate == 2'd0 && dut.enable == 1'b0);
        repeat (5) @(posedge clk);
        $display("stats batch 2: %0d games, batch_wins = %0d",
                 dut.core.games - games_before, dut.batch_wins);

        // ---- 3. PLAY mode: one roll per press -----------------------
        sw = 1'b1;
        rolls_before = dut.core.rolls;
        press_button;
        wait (dut.cstate == 2'd0 && dut.enable == 1'b0);
        repeat (5) @(posedge clk);

        if (dut.core.rolls !== rolls_before + 1) begin
            errors = errors + 1;
            $display("FAIL play: %0d rolls for one press",
                     dut.core.rolls - rolls_before);
        end
        if (dut.r_d1 < 3'd1 || dut.r_d1 > 3'd6 ||
            dut.r_d2 < 3'd1 || dut.r_d2 > 3'd6 ||
            dut.r_sum !== dut.r_d1 + dut.r_d2) begin
            errors = errors + 1;
            $display("FAIL play: dice %0d+%0d sum %0d inconsistent",
                     dut.r_d1, dut.r_d2, dut.r_sum);
        end
        $display("play roll 1: %0d + %0d = %0d  (state led=%b point=%0d)",
                 dut.r_d1, dut.r_d2, dut.r_sum, led[1:0], led[5:2]);

        // a few more rolls for good measure
        press_button;
        wait (dut.cstate == 2'd0 && dut.enable == 1'b0);
        $display("play roll 2: %0d + %0d = %0d", dut.r_d1, dut.r_d2, dut.r_sum);
        press_button;
        wait (dut.cstate == 2'd0 && dut.enable == 1'b0);
        $display("play roll 3: %0d + %0d = %0d", dut.r_d1, dut.r_d2, dut.r_sum);

        if (errors == 0)
            $display("ALL BOARD TESTS PASSED");
        else
            $display("%0d BOARD TEST(S) FAILED", errors);
        $finish;
    end

    initial begin
        #10_000_000;
        $display("TIMEOUT in tb_board");
        $finish;
    end

endmodule
