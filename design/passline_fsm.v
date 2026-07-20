// passline_fsm.v -- plays the craps pass-line game forever.
//
// Two states + a 3-bit point register (instead of seven states) -- the
// classic encoding trade-off, worth one breath on the circuit slide.
// Wins/losses are counted directly on the state transition, so no roll
// can ever be missed while "resolving".
//
// TA feedback addressed here: counters are 32-bit. We count past 10^6
// games and ~3.4x that many rolls; a 16-bit counter would silently wrap
// at 65,536 and corrupt every rate with no error message.

module passline_fsm (
    input  wire        clk,
    input  wire        rst,
    input  wire        strobe,     // one fresh roll is on 'sum' this cycle
    input  wire [3:0]  sum,        // 2..12
    output reg  [31:0] wins,
    output reg  [31:0] games,
    output reg  [31:0] rolls,
    output reg         state,      // exposed for the board demo
    output reg  [3:0]  point       // exposed for the board demo LEDs
);

    localparam COME_OUT = 1'b0;
    localparam POINT_PH = 1'b1;

    wire natural   = (sum == 4'd7)  || (sum == 4'd11);
    wire craps_out = (sum == 4'd2)  || (sum == 4'd3) || (sum == 4'd12);
    wire seven     = (sum == 4'd7);

    always @(posedge clk) begin
        if (rst) begin
            state <= COME_OUT;
            point <= 4'd0;
            wins  <= 32'd0;
            games <= 32'd0;
            rolls <= 32'd0;
        end else if (strobe) begin
            rolls <= rolls + 32'd1;
            case (state)
                COME_OUT: begin
                    if (natural) begin
                        wins  <= wins  + 32'd1;
                        games <= games + 32'd1;   // stay in COME_OUT
                    end else if (craps_out) begin
                        games <= games + 32'd1;   // loss; stay in COME_OUT
                    end else begin
                        point <= sum;             // 4,5,6,8,9,10
                        state <= POINT_PH;
                    end
                end
                POINT_PH: begin
                    if (sum == point) begin
                        wins  <= wins  + 32'd1;
                        games <= games + 32'd1;
                        state <= COME_OUT;
                    end else if (seven) begin
                        games <= games + 32'd1;   // seven out
                        state <= COME_OUT;
                    end
                    // any other sum: nothing happens, keep rolling
                end
            endcase
        end
    end

endmodule
