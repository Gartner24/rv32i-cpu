`timescale 1ns/1ps
module data_memory_tb;

reg        clk, mem_read;
reg  [3:0] byte_we;
reg [31:0] addr, write_data;
wire[31:0] read_data;
reg  [4:0] debug_addr;
wire[31:0] debug_data;

data_memory dut (
    .clk(clk),
    .mem_read(mem_read), .byte_we(byte_we),
    .addr(addr), .write_data(write_data),
    .read_data(read_data),
    .debug_addr(debug_addr), .debug_data(debug_data)
);

always #5 clk = ~clk;

integer errors;

task wr;  // escribe una palabra completa (byte_we = 1111) en byte addr a
    input [31:0] a;
    input [31:0] d;
    begin
        @(negedge clk); byte_we = 4'b1111; addr = a; write_data = d;
        @(posedge clk); #1; byte_we = 4'b0;
    end
endtask

task wrbe;  // escribe con byte-enables especificos (para probar sb/sh)
    input [3:0]  be;
    input [31:0] a;
    input [31:0] d;
    begin
        @(negedge clk); byte_we = be; addr = a; write_data = d;
        @(posedge clk); #1; byte_we = 4'b0;
    end
endtask

initial begin
    errors = 0;
    clk = 0; byte_we = 4'b0; mem_read = 0; addr = 0; write_data = 0; debug_addr = 0;

    // Escribir palabra 0 (byte addr 0), leer
    wr(32'd0, 32'hDEADBEEF);
    mem_read = 1; addr = 32'd0; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 got %0h", read_data); errors = errors+1; end

    // Escribir palabra 1 (byte addr 4), leer
    wr(32'd4, 32'hCAFEBABE);
    addr = 32'd4; #1;
    if (read_data !== 32'hCAFEBABE) begin $display("FAIL: word1 got %0h", read_data); errors = errors+1; end

    // Palabra 0 sigue intacta
    addr = 32'd0; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 intact got %0h", read_data); errors = errors+1; end

    // mem_read=0 devuelve 0
    mem_read = 0; #1;
    if (read_data !== 32'd0) begin $display("FAIL: mem_read=0 got %0h", read_data); errors = errors+1; end

    // Sobrescribir palabra 1
    wr(32'd4, 32'hABCD1234);
    mem_read = 1; addr = 32'd4; #1;
    if (read_data !== 32'hABCD1234) begin $display("FAIL: rewrite got %0h", read_data); errors = errors+1; end

    // byte-enables: escribir solo el byte 1 de la palabra 2 (como un sb)
    wr(32'd8, 32'h00000000);
    wrbe(4'b0010, 32'd8, 32'h0000AA00);   // habilita solo el byte 1
    mem_read = 1; addr = 32'd8; #1;
    if (read_data !== 32'h0000AA00) begin $display("FAIL: byte_we got %0h", read_data); errors = errors+1; end

    // Puerto de depuracion (palabra 0)
    debug_addr = 5'd0; #1;
    if (debug_data !== 32'hDEADBEEF) begin $display("FAIL: debug word0 got %0h", debug_data); errors = errors+1; end

    if (errors == 0) $display("PASS: data_memory");
    else             $display("FAIL: data_memory (%0d errors)", errors);
    $finish;
end
endmodule
