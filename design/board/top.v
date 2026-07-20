// top.v -- Basys3 top level: the same craps_core, two demo modes.
//
//   sw[0] = 0  STATS MODE: each press of BTNC plays a fresh batch of
//              exactly 10,000 games (in ~0.6 ms of real time) and shows
//              the WIN COUNT on the 7-seg. Expected value: ~4929 --
//              the win count per 10,000 IS the win rate x 10^4, so no
//              hardware divider is needed. The LFSRs keep their state
//              between presses, so every press is an independent
//              10,000-game sample: repeated presses scatter within the
//              predicted +/- 2 sigma (~ +/-100) band around 4929.
//
//   sw[0] = 1  PLAY MODE: each press of BTNC rolls once. The 7-seg
//              shows [die1][die2][sum tens][sum ones]; LEDs show the
//              game state, current point, and last win/lose.
//
//   BTNU = reset.
//
// LED map: led[0] come-out phase, led[1] point phase,
//          led[5:2] current point value (binary),
//          led[6] last game WON, led[7] last game LOST.

module top #(
    parameter        DB_BITS = 20,        // debounce ~10 ms at 100 MHz
    parameter [31:0] BATCH   = 32'd10000  // games per stats-mode press
)(
    input  wire       clk,      // 100 MHz board clock
    input  wire       btnC,     // action: run batch / roll once
    input  wire       btnU,     // reset
    input  wire [0:0] sw,       // sw[0]: 0 = stats, 1 = play
    output wire [7:0] led,
    output wire [6:0] seg,
    output wire       dp,
    output wire [3:0] an
);

    // ---- reset sync -------------------------------------------------
    reg [1:0] rst_sync;
    always @(posedge clk) rst_sync <= {rst_sync[0], btnU};
    wire rst = rst_sync[1];

    // ---- button -----------------------------------------------------
    wire press;
    debounce #(.BITS(DB_BITS)) db (
        .clk(clk), .rst(rst), .noisy(btnC), .press(press)
    );

    // ---- the machine (unchanged core) -------------------------------
    reg  enable;
    wire [31:0] wins, games, rolls, hw_wins, hw_bets;
    wire        roll_strobe, pl_state;
    wire [2:0]  face1, face2;
    wire [3:0]  point;

    craps_core core (
        .clk(clk), .rst(rst), .enable(enable),
        .wins(wins), .games(games), .rolls(rolls),
        .hw_wins(hw_wins), .hw_bets(hw_bets),
        .roll_strobe(roll_strobe),
        .face1(face1), .face2(face2),
        .pl_state(pl_state), .point(point)
    );

    wire [3:0] sum = {1'b0, face1} + {1'b0, face2};
    wire play_mode = sw[0];

    // ---- win/lose event detection (from counter changes) ------------
    reg [31:0] wins_q, games_q;
    always @(posedge clk) begin
        wins_q  <= wins;
        games_q <= games;
    end
    wire win_evt  = (wins  != wins_q);
    wire lose_evt = (games != games_q) & ~win_evt;

    // ---- controller -------------------------------------------------
    localparam S_IDLE  = 2'd0;
    localparam S_BATCH = 2'd1;
    localparam S_ROLL  = 2'd2;

    reg [1:0]  cstate;
    reg [31:0] wins_start, games_target;
    reg [13:0] batch_wins;              // stats-mode display value
    reg [2:0]  r_d1, r_d2;              // latched dice for play mode
    reg [3:0]  r_sum;
    reg        win_led, lose_led;

    wire [31:0] batch_diff = wins - wins_start;

    always @(posedge clk) begin
        if (rst) begin
            cstate       <= S_IDLE;
            enable       <= 1'b0;
            wins_start   <= 32'd0;
            games_target <= 32'd0;
            batch_wins   <= 14'd0;
            r_d1         <= 3'd0;
            r_d2         <= 3'd0;
            r_sum        <= 4'd0;
            win_led      <= 1'b0;
            lose_led     <= 1'b0;
        end else begin
            case (cstate)
                S_IDLE: begin
                    enable <= 1'b0;
                    if (press) begin
                        win_led  <= 1'b0;
                        lose_led <= 1'b0;
                        if (play_mode) begin
                            enable <= 1'b1;
                            cstate <= S_ROLL;
                        end else begin
                            wins_start   <= wins;
                            games_target <= games + BATCH;
                            enable       <= 1'b1;
                            cstate       <= S_BATCH;
                        end
                    end
                end

                S_BATCH: begin
                    // batch_wins is sampled the cycle games hits the
                    // target, so it reflects EXACTLY BATCH new games.
                    // (enable drops one cycle later; a stray extra roll
                    // may land in the cumulative counters -- harmless.)
                    if (games >= games_target) begin
                        enable     <= 1'b0;
                        batch_wins <= (batch_diff > 32'd9999)
                                      ? 14'd9999 : batch_diff[13:0];
                        cstate     <= S_IDLE;
                    end
                end

                S_ROLL: begin
                    if (roll_strobe) begin
                        r_d1   <= face1;   // latch: dice redraw after this
                        r_d2   <= face2;
                        r_sum  <= sum;
                        enable <= 1'b0;
                        cstate <= S_IDLE;
                    end
                end

                default: cstate <= S_IDLE;
            endcase

            // sticky result LEDs (cleared on next press)
            if (win_evt)  win_led  <= 1'b1;
            if (lose_evt) lose_led <= 1'b1;
        end
    end

    // ---- display ----------------------------------------------------
    wire [15:0] bcd_batch;
    bin2bcd b2b (.bin(batch_wins), .bcd(bcd_batch));

    wire [3:0] sum_tens = (r_sum >= 4'd10) ? 4'd1 : 4'd0;
    wire [3:0] sum_ones = (r_sum >= 4'd10) ? (r_sum - 4'd10) : r_sum;

    wire [15:0] digits = play_mode
        ? { 1'b0, r_d1, 1'b0, r_d2, sum_tens, sum_ones }  // d1 d2 sum
        : bcd_batch;                                       // ~"4929"

    sevenseg_display disp (
        .clk(clk), .rst(rst), .digits(digits),
        .seg(seg), .dp(dp), .an(an)
    );

    // ---- LEDs -------------------------------------------------------
    assign led[0]   = ~pl_state;   // come-out phase
    assign led[1]   =  pl_state;   // point phase
    assign led[5:2] =  point;      // current point value
    assign led[6]   =  win_led;
    assign led[7]   =  lose_led;

endmodule
