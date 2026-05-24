module clock_div (
    input  clock50,
    input  reset,
    output clock25
);
    reg [1:0] state;
    always @(posedge clock50 or posedge reset)
        if (reset) state <= 2'b0;
        else       state <= state + 2'b1;

    assign clock25 = (state == 2'b00 || state == 2'b10) ? 1'b1 : 1'b0;
endmodule
