// hardways_fsm.v -- the hard-8 side bet, permanently armed.
//
// The bet is a race: hard 8 (4+4) wins, easy 8 or any 7 loses,
// everything else is ignored and the bet stays live.
//
// TA feedback addressed here: "decide exactly when the bet re-arms."
// Answer: it re-arms INSTANTLY, by construction. ARMED is the only
// persistent state -- win/lose are counted combinationally on the same
// strobe that resolves them, and the next strobe is evaluated exactly
// the same way. It is structurally impossible for this watcher to miss
// a roll the pass-line FSM saw, so the two games can never fall out of
// sync on which dice they witnessed.
//
// Simplification (state on a slide): the bet also runs during come-out
// rolls, where real tables usually pause it. The bet's probability is
// unaffected -- its race doesn't care what the pass-line game is doing.

module hardways_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire        strobe,
    input  wire [3:0]  sum,
    input  wire        pair,       // die1 == die2
    output reg  [31:0] hw_wins,
    output reg  [31:0] hw_bets     // decisive resolutions (wins + losses)
);

    wire hard8 = (sum == 4'd8) &&  pair;
    wire easy8 = (sum == 4'd8) && ~pair;
    wire seven = (sum == 4'd7);

    always @(posedge clk) begin
        if (rst) begin
            hw_wins <= 32'd0;
            hw_bets <= 32'd0;
        end else if (strobe) begin
            if (hard8) begin
                hw_wins <= hw_wins + 32'd1;
                hw_bets <= hw_bets + 32'd1;
            end else if (easy8 | seven) begin
                hw_bets <= hw_bets + 32'd1;
            end
            // all other sums: bet stays live, nothing counted
        end
    end

endmodule
