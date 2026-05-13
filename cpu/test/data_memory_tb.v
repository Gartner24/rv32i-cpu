`timescale 1ns/1ps
module data_memory_tb;

reg [31:0] mem_tb [0:255];
wire [256*32-1:0] mem_flat;

genvar gi;
generate
    for (gi = 0; gi < 256; gi = gi + 1) begin : pack
        assign mem_flat[32*gi +: 32] = mem_tb[gi];
    end
endgenerate

reg        mem_read;
reg [31:0] addr;
wire[31:0] read_data;

data_memory dut (
    .mem_flat(mem_flat),
    .mem_read(mem_read),
    .addr(addr),
    .read_data(read_data)
);

integer i, errors;
initial begin
    errors = 0;
    for (i = 0; i < 256; i = i + 1) mem_tb[i] = 32'b0;
    mem_read = 0; addr = 0;
    #1;

    // Write word 0, read back
    mem_tb[0] = 32'hDEADBEEF;
    addr = 32'd0; mem_read = 1; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 read got %0h", read_data); errors = errors+1; end

    // Write word 1 (byte addr 4), read back
    mem_tb[1] = 32'hCAFEBABE;
    addr = 32'd4; #1;
    if (read_data !== 32'hCAFEBABE) begin $display("FAIL: word1 read got %0h", read_data); errors = errors+1; end

    // Word 0 still intact
    addr = 32'd0; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 still expected DEADBEEF got %0h", read_data); errors = errors+1; end

    // mem_read=0 returns 0
    mem_read = 0; #1;
    if (read_data !== 32'd0) begin $display("FAIL: mem_read=0 expected 0 got %0h", read_data); errors = errors+1; end

    // Write word 2 (byte addr 8), read back
    mem_tb[2] = 32'hAAAAAAAA;
    addr = 32'd8; mem_read = 1; #1;
    if (read_data !== 32'hAAAAAAAA) begin $display("FAIL: word2 read got %0h", read_data); errors = errors+1; end

    // Overwrite word 2, read back
    mem_tb[2] = 32'hABCD1234; #1;
    if (read_data !== 32'hABCD1234) begin $display("FAIL: rewrite got %0h", read_data); errors = errors+1; end

    if (errors == 0) $display("PASS: data_memory");
    else             $display("FAIL: data_memory (%0d errors)", errors);
    $finish;
end
endmodule
