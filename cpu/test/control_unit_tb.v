`timescale 1ns/1ps
module control_unit_tb;

reg  [6:0] opcode;
wire       reg_write, alu_src, alu_a_src;
wire       mem_write, mem_read, mem_to_reg;
wire       branch, jal, jalr;
wire [1:0] alu_op;

control_unit dut (
    .opcode(opcode),
    .reg_write(reg_write), .alu_src(alu_src), .alu_a_src(alu_a_src),
    .mem_write(mem_write), .mem_read(mem_read), .mem_to_reg(mem_to_reg),
    .branch(branch), .jal(jal), .jalr(jalr), .alu_op(alu_op)
);

integer errors;

// rw as aa mw mr m2r br jl jr op
task chk;
    input erw, eas, eaa, emw, emr, em2r, ebr, ejal, ejalr;
    input [1:0] eop;
    input [255:0] name;
    begin
        #1;
        if (reg_write!==erw || alu_src!==eas || alu_a_src!==eaa ||
            mem_write!==emw || mem_read!==emr || mem_to_reg!==em2r ||
            branch!==ebr   || jal!==ejal     || jalr!==ejalr       ||
            alu_op!==eop) begin
            $display("FAIL: %s", name);
            $display("  got  rw=%b as=%b aa=%b mw=%b mr=%b m2r=%b br=%b jal=%b jalr=%b op=%b",
                     reg_write,alu_src,alu_a_src,mem_write,mem_read,mem_to_reg,branch,jal,jalr,alu_op);
            $display("  want rw=%b as=%b aa=%b mw=%b mr=%b m2r=%b br=%b jal=%b jalr=%b op=%b",
                     erw,eas,eaa,emw,emr,em2r,ebr,ejal,ejalr,eop);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0;

    //                    rw as aa mw mr m2r br jl jr  op
    opcode=7'b0110011; chk(1, 0, 0, 0, 0, 0, 0, 0, 0, 2'b10, "R-TYPE");
    opcode=7'b0010011; chk(1, 1, 0, 0, 0, 0, 0, 0, 0, 2'b10, "I-TYPE");
    opcode=7'b0000011; chk(1, 1, 0, 0, 1, 1, 0, 0, 0, 2'b00, "LOAD");
    opcode=7'b0100011; chk(0, 1, 0, 1, 0, 0, 0, 0, 0, 2'b00, "S-TYPE");
    opcode=7'b1100011; chk(0, 0, 0, 0, 0, 0, 1, 0, 0, 2'b01, "B-TYPE");
    opcode=7'b0110111; chk(1, 1, 0, 0, 0, 0, 0, 0, 0, 2'b00, "LUI");
    opcode=7'b0010111; chk(1, 1, 1, 0, 0, 0, 0, 0, 0, 2'b00, "AUIPC");
    opcode=7'b1101111; chk(1, 1, 0, 0, 0, 0, 0, 1, 0, 2'b00, "JAL");
    opcode=7'b1100111; chk(1, 1, 0, 0, 0, 0, 0, 0, 1, 2'b00, "JALR");

    // Regression: jalr must be 0 for all non-JALR opcodes (latch bug fix)
    opcode=7'b0110011; #1; if (jalr!==0) begin $display("FAIL: R-type jalr should be 0"); errors=errors+1; end
    opcode=7'b1100011; #1; if (jalr!==0) begin $display("FAIL: B-type jalr should be 0"); errors=errors+1; end
    opcode=7'b0000011; #1; if (jalr!==0) begin $display("FAIL: LOAD jalr should be 0");  errors=errors+1; end
    opcode=7'b1101111; #1; if (jalr!==0) begin $display("FAIL: JAL jalr should be 0");   errors=errors+1; end

    if (errors == 0) $display("PASS: control_unit");
    else             $display("FAIL: control_unit (%0d errors)", errors);
    $finish;
end
endmodule
