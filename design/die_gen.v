// die_gen.v -- one die: LFSR draw + rejection sampling + valid handshake.
//
// Rejection sampling: take 3 raw bits (values 0-7). Values 0-5 map to
// faces 1-6; values 6-7 are REJECTED and we draw again next cycle.
// This makes every face exactly 1/6 -- a mod-6 mapping would bias
// faces 1-2 to 2/8 each. Each attempt succeeds with prob 6/8, so the
// number of attempts per face is geometric with mean 8/6 (a measurable
// mini-result).
//
// TA feedback addressed here: because rejection takes a VARIABLE number
// of cycles, the die exposes a ready/valid handshake. 'valid' rises
// when a fresh face is held; the game consumes it by pulsing 'consume',
// which immediately starts the next draw. The game logic only advances
// when BOTH dice are valid.

module die_gen #(
    parameter          WIDTH = 24,
    parameter [31:0]   TAPS  = 32'h00E10000,
    parameter [31:0]   SEED  = 32'h005A5A5A
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       consume,   // this face was used; draw a new one
    output reg  [2:0] face,      // 1..6, meaningful only while valid=1
    output reg        valid
);

    wire [2:0] r3;

    // draw a new attempt whenever we don't hold a valid face,
    // or the held face is being consumed right now
    wire trying = ~valid | consume;

    lfsr #(.WIDTH(WIDTH), .TAPS(TAPS), .SEED(SEED)) rng (
        .clk   (clk),
        .rst   (rst),
        .step  (trying),
        .rand3 (r3)
    );

    always @(posedge clk) begin
        if (rst) begin
            valid <= 1'b0;
            face  <= 3'd1;
        end else if (trying) begin
            if (r3 < 3'd6) begin
                face  <= r3 + 3'd1;   // 0..5 -> 1..6
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;        // rejected: retry next cycle
            end
        end
    end

endmodule
