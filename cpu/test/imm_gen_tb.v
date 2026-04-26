`timescale 1ns/1ps
module imm_gen_tb;

reg  [31:0] instr;
wire [31:0] imm_out;

imm_gen dut (.instr(instr), .imm_out(imm_out));

integer errors;

task chk;
    input [31:0] exp;
    input [255:0] name;
    begin
        #1;
        if (imm_out !== exp) begin
            $display("FAIL: %s expected %0h got %0h", name, exp, imm_out);
            errors = errors + 1;
        end
    end
endtask

initial begin
    errors = 0;

    // I-type (opcode 0010011): addi x1, x0, 5  -> 00500093
    instr = 32'h00500093; chk(32'd5,          "I-type imm=5");

    // I-type negative: addi x1, x0, -1 -> FFF00093
    instr = 32'hFFF00093; chk(32'hFFFFFFFF,   "I-type imm=-1");

    // I-type imm=2047 (max positive 12-bit): 7FF00093
    instr = 32'h7FF00093; chk(32'd2047,       "I-type imm=2047");

    // I-type imm=-2048 (min 12-bit): 80000093
    instr = 32'h80000093; chk(32'hFFFFF800,   "I-type imm=-2048");

    // LOAD (opcode 0000011): lw x4, 4(x0) -> 00402203
    instr = 32'h00402203; chk(32'd4,          "LOAD imm=4");

    // JALR (opcode 1100111): jalr x0, 8(x0) -> 00800067
    instr = 32'h00800067; chk(32'd8,          "JALR imm=8");

    // S-type (opcode 0100011): sw x3, 4(x0) -> 00302223
    // imm=4: imm[11:5]=0000000 imm[4:0]=00100
    instr = 32'h00302223; chk(32'd4,          "S-type imm=4");

    // S-type negative: imm=-4 -> imm[11:5]=1111111 imm[4:0]=11100
    // sw x3, -4(x0): funct7=1111111, rs2=x3=00011, rs1=x0=00000, funct3=010, imm[4:0]=11100
    // = 1111111_00011_00000_010_11100_0100011 = 0xFE302E23
    instr = 32'hFE302E23; chk(32'hFFFFFFFC,   "S-type imm=-4");

    // B-type (opcode 1100011): beq x0, x0, 8 -> 00000463
    // imm=8: instr[31]=0 instr[30:25]=000000 instr[11:8]=0100 instr[7]=0
    instr = 32'h00000463; chk(32'd8,          "B-type imm=8");

    // B-type negative: beq x0, x0, -4
    // imm=-4=0xFFFFFFFC, imm[12]=1 imm[11]=1 imm[10:5]=111111 imm[4:1]=1110
    // instr[31]=1 instr[7]=imm[11]=1 instr[30:25]=111111 instr[11:8]=1110
    // = 1_111111_00000_00000_000_1110_1_1100011 = 0xFE000EE3
    instr = 32'hFE000EE3; chk(32'hFFFFFFFC,   "B-type imm=-4");

    // LUI (opcode 0110111): lui x1, 0xABCDE -> ABCDE0B7
    instr = 32'hABCDE0B7; chk(32'hABCDE000,   "LUI imm=ABCDE000");

    // AUIPC (opcode 0010111): auipc x1, 1 -> 00001097
    instr = 32'h00001097; chk(32'h00001000,   "AUIPC imm=0x1000");

    // JAL (opcode 1101111): jal x0, 4 -> 0040006F
    // imm=4: imm[20]=0 imm[19:12]=00000000 imm[11]=0 imm[10:1]=0000000010
    // instr[31]=0 instr[19:12]=00000000 instr[20]=0 instr[30:21]=0000000010
    instr = 32'h0040006F; chk(32'd4,          "JAL imm=4");

    // JAL negative: imm=-4
    // imm=-4=0xFFFFFFFC: imm[20]=1 imm[19:12]=11111111 imm[11]=1 imm[10:1]=1111111110
    // instr[31]=1 instr[30:21]=1111111110 instr[20]=1 instr[19:12]=11111111
    // = 1_1111111110_1_11111111_00000_1101111 = 0xFFDFF06F
    instr = 32'hFFDFF06F; chk(32'hFFFFFFFC,   "JAL imm=-4");

    if (errors == 0) $display("PASS: imm_gen");
    else             $display("FAIL: imm_gen (%0d errors)", errors);
    $finish;
end
endmodule
