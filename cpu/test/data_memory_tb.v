`timescale 1ns/1ps
module data_memory_tb;

reg        en;
reg        mem_write, mem_read;
reg [31:0] addr, write_data;
wire[31:0] read_data;

data_memory dut (
    .en(en), .mem_write(mem_write), .mem_read(mem_read),
    .addr(addr), .write_data(write_data), .read_data(read_data)
);

// en is the trigger clock (posedge = one write)
always #5 en = ~en;

task tick;
    begin @(posedge en); #1; end
endtask

integer errors;
initial begin
    errors = 0;
    en = 0; mem_write = 0; mem_read = 0;
    addr = 0; write_data = 0;

    // Write to word 0, read back
    addr = 32'd0; write_data = 32'hDEADBEEF; mem_write = 1; tick;
    mem_write = 0; mem_read = 1; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 read got %0h", read_data); errors = errors+1; end

    // Write to word 1 (byte addr 4), read back
    addr = 32'd4; write_data = 32'hCAFEBABE; mem_write = 1; tick;
    mem_write = 0; mem_read = 1; #1;
    if (read_data !== 32'hCAFEBABE) begin $display("FAIL: word1 read got %0h", read_data); errors = errors+1; end

    // Word 0 still intact
    addr = 32'd0; #1;
    if (read_data !== 32'hDEADBEEF) begin $display("FAIL: word0 still expected DEADBEEF got %0h", read_data); errors = errors+1; end

    // mem_read=0 returns 0
    mem_read = 0; addr = 32'd0; #1;
    if (read_data !== 32'd0) begin $display("FAIL: mem_read=0 expected 0 got %0h", read_data); errors = errors+1; end

    // No write without a tick: change write_data but don't tick
    addr = 32'd8; write_data = 32'hAAAAAAAA; mem_write = 1; tick;
    write_data = 32'hBBBBBBBB; mem_read = 1; #1;
    if (read_data !== 32'hAAAAAAAA)
        begin $display("FAIL: no tick should not change mem got %0h", read_data); errors = errors+1; end

    // mem_write=0 blocks write
    mem_write = 0; write_data = 32'h12345678; tick;
    if (read_data !== 32'hAAAAAAAA)
        begin $display("FAIL: mem_write=0 should block write got %0h", read_data); errors = errors+1; end

    // Write again with mem_write=1
    mem_write = 1; write_data = 32'hABCD1234; tick;
    mem_write = 0; mem_read = 1; #1;
    if (read_data !== 32'hABCD1234) begin $display("FAIL: rewrite got %0h", read_data); errors = errors+1; end

    if (errors == 0) $display("PASS: data_memory");
    else             $display("FAIL: data_memory (%0d errors)", errors);
    $finish;
end
endmodule
