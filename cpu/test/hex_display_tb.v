`timescale 1ns/1ps
module hex_display_tb;

reg  [3:0] value;
wire [6:0] segments;

hex_display dut (.value(value), .segments(segments));

integer errors;

task chk;
    input [6:0] exp;
    input [3:0] val;
    begin
        value = val; #1;
        if (segments !== exp) begin
            $display("FAIL: hex %0h expected %07b got %07b", val, exp, segments);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0;

    // Active-low segment encoding {g,f,e,d,c,b,a}
    chk(7'b1000000, 4'h0);
    chk(7'b1111001, 4'h1);
    chk(7'b0100100, 4'h2);
    chk(7'b0110000, 4'h3);
    chk(7'b0011001, 4'h4);
    chk(7'b0010010, 4'h5);
    chk(7'b0000010, 4'h6);
    chk(7'b1111000, 4'h7);
    chk(7'b0000000, 4'h8);
    chk(7'b0010000, 4'h9);
    chk(7'b0001000, 4'ha);
    chk(7'b0000011, 4'hb);
    chk(7'b1000110, 4'hc);
    chk(7'b0100001, 4'hd);
    chk(7'b0000110, 4'he);
    chk(7'b0001110, 4'hf);

    if (errors==0) $display("PASS: hex_display");
    else           $display("FAIL: hex_display (%0d errors)", errors);
    $finish;
end
endmodule
