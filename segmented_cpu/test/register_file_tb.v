`timescale 1ns/1ps
module register_file_tb;

reg        clk, rst, we;
reg  [4:0] wa, rs1, rs2, debug_addr;
reg  [31:0] wd;
wire [31:0] read_data1, read_data2, debug_data;

register_file dut (
    .clk(clk), .rst(rst),
    .we(we), .wa(wa), .wd(wd),
    .rs1(rs1), .rs2(rs2),
    .debug_addr(debug_addr),
    .read_data1(read_data1), .read_data2(read_data2),
    .debug_data(debug_data)
);

always #5 clk = ~clk;

integer errors;

task wr;  // escribe wd en wa en un flanco de reloj
    input [4:0] a;
    input [31:0] d;
    begin
        @(negedge clk); we = 1; wa = a; wd = d;
        @(posedge clk); #1; we = 0;
    end
endtask

initial begin
    errors = 0;
    clk = 0; rst = 1; we = 0; wa = 0; wd = 0; rs1 = 0; rs2 = 0; debug_addr = 0;
    @(posedge clk); #1; rst = 0;

    // Escribir x1=42, leer por rs1
    wr(5'd1, 32'd42);
    rs1 = 5'd1; #1;
    if (read_data1 !== 32'd42) begin $display("FAIL: x1 read1 got %0d", read_data1); errors = errors+1; end

    // Escribir x2=100, leer por rs2
    wr(5'd2, 32'd100);
    rs2 = 5'd2; #1;
    if (read_data2 !== 32'd100) begin $display("FAIL: x2 read2 got %0d", read_data2); errors = errors+1; end

    // x0 siempre lee 0, incluso si se intenta escribir
    wr(5'd0, 32'hDEADBEEF);
    rs1 = 5'd0; rs2 = 5'd0; #1;
    if (read_data1 !== 32'd0) begin $display("FAIL: x0 rs1 should be 0 got %0h", read_data1); errors = errors+1; end
    if (read_data2 !== 32'd0) begin $display("FAIL: x0 rs2 should be 0 got %0h", read_data2); errors = errors+1; end

    // Puerto de depuracion
    debug_addr = 5'd1; #1;
    if (debug_data !== 32'd42)  begin $display("FAIL: debug x1 expected 42 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd2; #1;
    if (debug_data !== 32'd100) begin $display("FAIL: debug x2 expected 100 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd0; #1;
    if (debug_data !== 32'd0)   begin $display("FAIL: debug x0 should be 0 got %0h", debug_data); errors = errors+1; end

    // Lectura simultanea de dos puertos
    rs1 = 5'd1; rs2 = 5'd2; #1;
    if (read_data1 !== 32'd42 || read_data2 !== 32'd100)
        begin $display("FAIL: dual read got %0d %0d", read_data1, read_data2); errors = errors+1; end

    // Bypass write-first: leer el mismo registro que se escribe este ciclo
    @(negedge clk); we = 1; wa = 5'd5; wd = 32'd123; rs1 = 5'd5;
    #1;
    if (read_data1 !== 32'd123) begin $display("FAIL: write-first bypass got %0d", read_data1); errors = errors+1; end
    @(posedge clk); #1; we = 0;

    if (errors == 0) $display("PASS: register_file");
    else             $display("FAIL: register_file (%0d errors)", errors);
    $finish;
end
endmodule
