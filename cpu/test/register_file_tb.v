`timescale 1ns/1ps
module register_file_tb;

reg        en, rst;
reg        reg_write;
reg  [4:0] rs1, rs2, rd, debug_addr;
reg [31:0] write_data;
wire[31:0] read_data1, read_data2, debug_data, exit_code;

register_file dut (
    .reg_write(reg_write), .en(en), .rst(rst),
    .rs1(rs1), .rs2(rs2), .rd(rd), .write_data(write_data),
    .read_data1(read_data1), .read_data2(read_data2),
    .debug_addr(debug_addr), .debug_data(debug_data),
    .exit_code(exit_code)
);

// en is the trigger clock (posedge = one write)
always #5 en = ~en;

task tick;
    begin @(posedge en); #1; end
endtask

integer errors;
initial begin
    errors = 0;
    en = 0; rst = 1; reg_write = 0;
    rs1 = 0; rs2 = 0; rd = 0; write_data = 0; debug_addr = 0;

    // Reset clears all registers
    tick; tick;
    rst = 0; #1;

    // Write x1=42, read back via rs1
    rd = 5'd1; write_data = 32'd42; reg_write = 1; tick;
    reg_write = 0; rs1 = 5'd1; #1;
    if (read_data1 !== 32'd42) begin $display("FAIL: x1 write/read1 got %0d", read_data1); errors = errors+1; end

    // Write x2=100, read back via rs2
    rd = 5'd2; write_data = 32'd100; reg_write = 1; tick;
    reg_write = 0; rs2 = 5'd2; #1;
    if (read_data2 !== 32'd100) begin $display("FAIL: x2 write/read2 got %0d", read_data2); errors = errors+1; end

    // x0 always reads 0, write attempt has no effect
    rd = 5'd0; write_data = 32'hDEADBEEF; reg_write = 1; tick;
    reg_write = 0; rs1 = 5'd0; rs2 = 5'd0; #1;
    if (read_data1 !== 32'd0) begin $display("FAIL: x0 rs1 should be 0 got %0h", read_data1); errors = errors+1; end
    if (read_data2 !== 32'd0) begin $display("FAIL: x0 rs2 should be 0 got %0h", read_data2); errors = errors+1; end

    // debug port reads correct register
    debug_addr = 5'd1; #1;
    if (debug_data !== 32'd42)  begin $display("FAIL: debug x1 expected 42 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd2; #1;
    if (debug_data !== 32'd100) begin $display("FAIL: debug x2 expected 100 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd0; #1;
    if (debug_data !== 32'd0)   begin $display("FAIL: debug x0 should be 0 got %0h", debug_data); errors = errors+1; end

    // No write without a tick: change write_data but don't tick, rs1 stays old
    rd = 5'd3; write_data = 32'hCAFEBABE; reg_write = 1;
    rs1 = 5'd3; #1;
    if (read_data1 === 32'hCAFEBABE)
        begin $display("FAIL: write before tick should not propagate"); errors = errors+1; end
    tick; reg_write = 0; #1;
    if (read_data1 !== 32'hCAFEBABE) begin $display("FAIL: x3 after tick got %0h", read_data1); errors = errors+1; end

    // reg_write=0 blocks write
    rd = 5'd4; write_data = 32'hAAAAAAAA; reg_write = 1; tick;
    write_data = 32'hBBBBBBBB; reg_write = 0; tick;
    rs1 = 5'd4; #1;
    if (read_data1 !== 32'hAAAAAAAA)
        begin $display("FAIL: reg_write=0 should block write got %0h", read_data1); errors = errors+1; end

    // Two-port simultaneous read
    rs1 = 5'd1; rs2 = 5'd2; #1;
    if (read_data1 !== 32'd42 || read_data2 !== 32'd100)
        begin $display("FAIL: dual read got %0d %0d", read_data1, read_data2); errors = errors+1; end

    // exit_code always reflects x10
    rd = 5'd10; write_data = 32'd7; reg_write = 1; tick;
    reg_write = 0; #1;
    if (exit_code !== 32'd7) begin $display("FAIL: exit_code expected 7 got %0d", exit_code); errors = errors+1; end

    if (errors == 0) $display("PASS: register_file");
    else             $display("FAIL: register_file (%0d errors)", errors);
    $finish;
end
endmodule
