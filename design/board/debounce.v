// debounce.v -- 2-FF synchronizer + counter debounce + rising-edge pulse.
//
// A mechanical button bounces for a few ms; without this, one press
// looks like dozens. The input must hold a new value for 2^BITS clock
// cycles (~10 ms at 100 MHz with BITS=20) before we believe it.
// 'press' pulses high for exactly one cycle per accepted press.
// BITS is a parameter so the board testbench can shrink it and
// simulate presses without waiting millions of cycles.

module debounce #(
    parameter BITS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire noisy,     // raw button pin
    output wire press      // one-cycle pulse on a clean rising edge
);

    // synchronize the async button into the clock domain
    reg [1:0] ff;
    always @(posedge clk) ff <= {ff[0], noisy};
    wire in = ff[1];

    reg              state;    // debounced level
    reg              state_q;  // previous debounced level
    reg [BITS-1:0]   cnt;

    always @(posedge clk) begin
        if (rst) begin
            state   <= 1'b0;
            state_q <= 1'b0;
            cnt     <= {BITS{1'b0}};
        end else begin
            state_q <= state;
            if (in == state) begin
                cnt <= {BITS{1'b0}};
            end else begin
                cnt <= cnt + 1'b1;
                if (&cnt) begin
                    state <= in;
                    cnt   <= {BITS{1'b0}};
                end
            end
        end
    end

    assign press = state & ~state_q;

endmodule
