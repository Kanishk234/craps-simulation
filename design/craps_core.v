// craps_core.v -- wires everything together.
//
//   lfsr+die_gen x2  -->  sum/pair decode  -->  passline_fsm
//        (handshake)                       -->  hardways_fsm
//
// TA feedback addressed here:
//  * The two dice use different feedback polynomials AND different
//    widths: die 1 is a 24-bit LFSR (taps 24,23,22,17), die 2 is a
//    23-bit LFSR (taps 23,18). Both are maximal-length. Different
//    seeds alone would NOT make them independent.
//  * roll_strobe = valid1 & valid2: the game only advances when both
//    dice hold fresh faces (the ready/valid handshake). Consuming a
//    roll immediately starts both dice drawing again.

module craps_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,       // board demo: gates rolling on/off
    output wire [31:0] wins,
    output wire [31:0] games,
    output wire [31:0] rolls,
    output wire [31:0] hw_wins,
    output wire [31:0] hw_bets,
    output wire        roll_strobe,  // exposed for testbench / board demo
    output wire [2:0]  face1,
    output wire [2:0]  face2,
    output wire        pl_state,     // COME_OUT / POINT, for board LEDs
    output wire [3:0]  point         // current point value, for board LEDs
);

    wire v1, v2;
    // the game only advances when both dice hold fresh faces AND the
    // controller allows it (enable=1 always in the simulation testbench;
    // pulsed/held by the board top-level for batch and play modes)
    assign roll_strobe = v1 & v2 & enable;

    // Die 1: 24-bit LFSR, polynomial x^24+x^23+x^22+x^17+1
    // tap mask: bits 23,22,21,16 -> 0xE10000
    die_gen #(
        .WIDTH (24),
        .TAPS  (32'h00E10000),
        .SEED  (32'h005A5A5A)
    ) die1 (
        .clk     (clk),
        .rst     (rst),
        .consume (roll_strobe),
        .face    (face1),
        .valid   (v1)
    );

    // Die 2: 23-bit LFSR, polynomial x^23+x^18+1
    // tap mask: bits 22,17 -> 0x420000
    die_gen #(
        .WIDTH (23),
        .TAPS  (32'h00420000),
        .SEED  (32'h001ACE55)
    ) die2 (
        .clk     (clk),
        .rst     (rst),
        .consume (roll_strobe),
        .face    (face2),
        .valid   (v2)
    );

    // roll decode
    wire [3:0] sum  = {1'b0, face1} + {1'b0, face2};   // 2..12
    wire       pair = (face1 == face2);

    passline_fsm pl (
        .clk    (clk),
        .rst    (rst),
        .strobe (roll_strobe),
        .sum    (sum),
        .wins   (wins),
        .games  (games),
        .rolls  (rolls),
        .state  (pl_state),
        .point  (point)
    );

    hardways_fsm hw (
        .clk     (clk),
        .rst     (rst),
        .strobe  (roll_strobe),
        .sum     (sum),
        .pair    (pair),
        .hw_wins (hw_wins),
        .hw_bets (hw_bets)
    );

endmodule
