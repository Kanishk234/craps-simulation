// bin2bcd.v -- combinational double-dabble: 14-bit binary -> 4 BCD digits.
//
// The classic shift-and-add-3 algorithm: shift the binary number in one
// bit at a time; before each shift, any BCD digit >= 5 gets +3 so the
// shift carries correctly into the next decimal digit. 14 bits covers
// 0..16383; the caller saturates at 9999 (4 digits) before this module.

module bin2bcd (
    input  wire [13:0] bin,
    output reg  [15:0] bcd    // {thousands, hundreds, tens, ones}
);

    integer i;

    always @* begin
        bcd = 16'd0;
        for (i = 13; i >= 0; i = i - 1) begin
            if (bcd[3:0]   >= 4'd5) bcd[3:0]   = bcd[3:0]   + 4'd3;
            if (bcd[7:4]   >= 4'd5) bcd[7:4]   = bcd[7:4]   + 4'd3;
            if (bcd[11:8]  >= 4'd5) bcd[11:8]  = bcd[11:8]  + 4'd3;
            if (bcd[15:12] >= 4'd5) bcd[15:12] = bcd[15:12] + 4'd3;
            bcd = {bcd[14:0], bin[i]};
        end
    end

endmodule
