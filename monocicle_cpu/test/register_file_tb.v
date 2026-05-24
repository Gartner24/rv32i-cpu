`timescale 1ns/1ps
module register_file_tb;

reg [31:0] regs_tb [0:31];
wire [32*32-1:0] regs_flat;

genvar gi;
generate
    for (gi = 0; gi < 32; gi = gi + 1) begin : pack
        assign regs_flat[32*gi +: 32] = regs_tb[gi];
    end
endgenerate

reg  [4:0] rs1, rs2, debug_addr;
wire [31:0] read_data1, read_data2, debug_data, exit_code;

register_file dut (
    .regs_flat(regs_flat),
    .rs1(rs1), .rs2(rs2),
    .debug_addr(debug_addr),
    .read_data1(read_data1), .read_data2(read_data2),
    .debug_data(debug_data),
    .exit_code(exit_code)
);

integer i, errors;
initial begin
    errors = 0;
    for (i = 0; i < 32; i = i + 1) regs_tb[i] = 32'b0;
    rs1 = 0; rs2 = 0; debug_addr = 0;
    #1;

    // Write x1=42, read back via rs1
    regs_tb[1] = 32'd42;
    rs1 = 5'd1; #1;
    if (read_data1 !== 32'd42) begin $display("FAIL: x1 read1 got %0d", read_data1); errors = errors+1; end

    // Write x2=100, read back via rs2
    regs_tb[2] = 32'd100;
    rs2 = 5'd2; #1;
    if (read_data2 !== 32'd100) begin $display("FAIL: x2 read2 got %0d", read_data2); errors = errors+1; end

    // x0 always reads 0 (combinational guard, regardless of regs_tb[0])
    regs_tb[0] = 32'hDEADBEEF;
    rs1 = 5'd0; rs2 = 5'd0; #1;
    if (read_data1 !== 32'd0) begin $display("FAIL: x0 rs1 should be 0 got %0h", read_data1); errors = errors+1; end
    if (read_data2 !== 32'd0) begin $display("FAIL: x0 rs2 should be 0 got %0h", read_data2); errors = errors+1; end
    regs_tb[0] = 32'b0;

    // debug port reads correct register
    debug_addr = 5'd1; #1;
    if (debug_data !== 32'd42)  begin $display("FAIL: debug x1 expected 42 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd2; #1;
    if (debug_data !== 32'd100) begin $display("FAIL: debug x2 expected 100 got %0d", debug_data); errors = errors+1; end
    debug_addr = 5'd0; #1;
    if (debug_data !== 32'd0)   begin $display("FAIL: debug x0 should be 0 got %0h", debug_data); errors = errors+1; end

    // Two-port simultaneous read
    rs1 = 5'd1; rs2 = 5'd2; #1;
    if (read_data1 !== 32'd42 || read_data2 !== 32'd100)
        begin $display("FAIL: dual read got %0d %0d", read_data1, read_data2); errors = errors+1; end

    // exit_code always reflects x10
    regs_tb[10] = 32'd7; #1;
    if (exit_code !== 32'd7) begin $display("FAIL: exit_code expected 7 got %0d", exit_code); errors = errors+1; end

    if (errors == 0) $display("PASS: register_file");
    else             $display("FAIL: register_file (%0d errors)", errors);
    $finish;
end
endmodule
