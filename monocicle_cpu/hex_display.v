// =============================================================================
// hex_display.v - 4-bit to 7-segment decoder
// Active-low output for DE1-SoC HEX displays (0 = segment ON).
// Segment order: segments[6:0] = {g, f, e, d, c, b, a}
// =============================================================================
module hex_display (
    input  [3:0] value,
    output reg [6:0] segments
);

always @(*) begin
    case (value)
        4'h0: segments = 7'b1000000;
        4'h1: segments = 7'b1111001;
        4'h2: segments = 7'b0100100;
        4'h3: segments = 7'b0110000;
        4'h4: segments = 7'b0011001;
        4'h5: segments = 7'b0010010;
        4'h6: segments = 7'b0000010;
        4'h7: segments = 7'b1111000;
        4'h8: segments = 7'b0000000;
        4'h9: segments = 7'b0010000;
        4'ha: segments = 7'b0001000;
        4'hb: segments = 7'b0000011;
        4'hc: segments = 7'b1000110;
        4'hd: segments = 7'b0100001;
        4'he: segments = 7'b0000110;
        4'hf: segments = 7'b0001110;
        default: segments = 7'b1111111; // all off
    endcase
end

endmodule
