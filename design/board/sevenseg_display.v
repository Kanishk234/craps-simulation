// sevenseg_display.v -- 4-digit multiplexed 7-seg driver (Basys3).
//
// The Basys3's four digits share one set of segment pins, so we light
// one digit at a time and cycle fast enough that eyes see all four.
// refresh[16:15] selects the digit: each digit is lit for 2^15 cycles
// (327 us), full refresh every 1.31 ms (~763 Hz) -- fast enough to be
// flicker-free, slow enough to avoid ghosting.
//
// Basys3 segments AND anodes are ACTIVE LOW.
// seg bit order here: seg[6:0] = {g, f, e, d, c, b, a}.

module sevenseg_display (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] digits,   // {digit3, digit2, digit1, digit0}, BCD
    output reg  [6:0]  seg,
    output wire        dp,
    output reg  [3:0]  an
);

    reg [16:0] refresh;
    always @(posedge clk) begin
        if (rst) refresh <= 17'd0;
        else     refresh <= refresh + 17'd1;
    end

    wire [1:0] sel = refresh[16:15];
    reg  [3:0] d;

    always @* begin
        case (sel)
            2'd0: begin an = 4'b1110; d = digits[3:0];   end
            2'd1: begin an = 4'b1101; d = digits[7:4];   end
            2'd2: begin an = 4'b1011; d = digits[11:8];  end
            2'd3: begin an = 4'b0111; d = digits[15:12]; end
        endcase
        case (d)                       //  gfedcba (0 = segment lit)
            4'd0:    seg = 7'b1000000;
            4'd1:    seg = 7'b1111001;
            4'd2:    seg = 7'b0100100;
            4'd3:    seg = 7'b0110000;
            4'd4:    seg = 7'b0011001;
            4'd5:    seg = 7'b0010010;
            4'd6:    seg = 7'b0000010;
            4'd7:    seg = 7'b1111000;
            4'd8:    seg = 7'b0000000;
            4'd9:    seg = 7'b0010000;
            default: seg = 7'b1111111;   // blank
        endcase
    end

    assign dp = 1'b1;   // decimal points off

endmodule
