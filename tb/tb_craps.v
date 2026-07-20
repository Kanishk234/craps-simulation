// tb_craps.v -- runs 2^20 (1,048,576) games and writes results.csv.
//
// TA feedback addressed here: we do NOT write a CSV line per roll
// (millions of file writes would make the simulation crawl). Instead
// we snapshot the running counters whenever the game count hits a
// power of two -- about 20 writes total -- which also gives points
// evenly spaced on the log axis for the log-log convergence plot.
// The power-of-two test: (games & (games-1)) == 0.
//
// Plain Verilog. In Vivado, set this as the simulation top and run
// with "run -all" (the default 1000 ns runtime is nowhere near enough).

`timescale 1ns / 1ps

module tb_craps;

    localparam [31:0] TARGET = 32'd1048576;   // 2^20 games

    reg  clk, rst;
    wire [31:0] wins, games, rolls, hw_wins, hw_bets;
    wire        roll_strobe, pl_state;
    wire [2:0]  face1, face2;

    craps_core dut (
        .clk         (clk),
        .rst         (rst),
        .enable      (1'b1),        // simulation: always rolling
        .wins        (wins),
        .games       (games),
        .rolls       (rolls),
        .hw_wins     (hw_wins),
        .hw_bets     (hw_bets),
        .roll_strobe (roll_strobe),
        .face1       (face1),
        .face2       (face2),
        .pl_state    (pl_state),
        .point       ()             // unused in simulation
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    integer fh;
    reg [31:0] prev_games;

    initial begin
        clk        = 1'b0;
        rst        = 1'b1;
        prev_games = 32'd0;

        fh = $fopen("results.csv", "w");
        $fdisplay(fh, "rolls,games,wins,hw_bets,hw_wins");

        #40 rst = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst && games != prev_games) begin
            prev_games <= games;

            // snapshot at powers of two: 1, 2, 4, ..., 2^20
            if ((games & (games - 32'd1)) == 32'd0)
                $fdisplay(fh, "%0d,%0d,%0d,%0d,%0d",
                          rolls, games, wins, hw_bets, hw_wins);

            if (games >= TARGET) begin
                $fclose(fh);
                $display("--------------------------------------------------");
                $display("games   = %0d", games);
                $display("rolls   = %0d   (rolls/game = %f, theory 3.376)",
                         rolls, rolls * 1.0 / games);
                $display("passline: wins = %0d  rate = %f  (theory 0.492929)",
                         wins, wins * 1.0 / games);
                $display("hard-8  : bets = %0d  wins = %0d  rate = %f  (theory 0.090909)",
                         hw_bets, hw_wins, hw_wins * 1.0 / hw_bets);
                $display("--------------------------------------------------");
                $display("Wrote results.csv -- now run: python3 plot_results.py");
                $finish;
            end
        end
    end

    // safety net: never hang forever if something is wired wrong
    initial begin
        #200_000_000;   // 200 ms of sim time, far more than needed
        $display("TIMEOUT: simulation did not reach %0d games", TARGET);
        $fclose(fh);
        $finish;
    end

endmodule
