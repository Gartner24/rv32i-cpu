// =============================================================================
// vga_debug.v - Muestra el estado completo de la CPU por pantalla (640x480).
// Dibuja una grilla de 80x30 caracteres (fuente 8x16, font128.hex).
// Completamente combinacional: dada la posicion del pixel (x,y) y las senales
// de la CPU, produce directamente el color RGB sin estado interno.
//
// Distribucion de filas en pantalla:
//   Fila 0  (amarillo): PC / INSTR / ALU / ZERO / HALT / MEM
//   Fila 1  (blanco):   OPC / F3 / F7 / RD / RS1 / RS2 / IMM
//   Fila 2  (cyan):     senales de control (RW, MR, MW, M2R, AS, BR, JL, JR, PCS)
//   Fila 4  (verde):    encabezado REGISTERS
//   Filas 5-20 (blanco): x00..x15 (panel izquierdo) y x16..x31 (panel derecho)
// =============================================================================

module vga_debug (
    input         video_on,
    input  [9:0]  x, y,

    input  [31:0] pc_out,
    input  [31:0] instr,
    input  [31:0] alu_result,
    input  [31:0] imm_ext,
    input  [31:0] mem_data_out,
    input         alu_zero,
    input         halted,
    input         reg_write,
    input         mem_read,
    input         mem_write,
    input         mem_to_reg,
    input         alu_src,
    input         branch,
    input         jal,
    input         jalr,
    input         pc_src,

    output [4:0]  reg_debug_addr,
    input  [31:0] reg_debug_data,

    output reg [7:0] vga_r,
    output reg [7:0] vga_g,
    output reg [7:0] vga_b
);

    // ---------------------------------------------------------------
    // Font ROM: 128 glyphs x 16 rows = 2048 bytes
    // ---------------------------------------------------------------
    reg [7:0] font_rom [0:2047];
    initial $readmemh("font128.hex", font_rom);

    // ---------------------------------------------------------------
    // Cell coordinates
    // ---------------------------------------------------------------
    wire [6:0] col       = x[9:3];   // 0..79
    wire [2:0] glyph_col = x[2:0];   // 0..7
    wire [4:0] row       = y[8:4];   // 0..29
    wire [3:0] glyph_row = y[3:0];   // 0..15

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------
    // Convierte un nibble (0-15) a su caracter ASCII hexadecimal ('0'..'9', 'A'..'F').
    function [6:0] hn;
        input [3:0] n;
        begin
            if (n < 4'd10) hn = 7'h30 + {3'b0, n};
            else           hn = 7'h37 + {3'b0, n}; // 'A'=0x41; 0x41-10=0x37
        end
    endfunction

    // Convierte un bit a su caracter ASCII: 0 -> '0', 1 -> '1'.
    function [6:0] bit_ch;
        input b;
        bit_ch = b ? 7'h31 : 7'h30;
    endfunction

    // Devuelve el digito de las decenas en ASCII para un numero 0..31.
    function [6:0] dec_tens;
        input [4:0] n;
        begin
            if      (n >= 30) dec_tens = 7'h33;
            else if (n >= 20) dec_tens = 7'h32;
            else if (n >= 10) dec_tens = 7'h31;
            else              dec_tens = 7'h30;
        end
    endfunction

    // Devuelve el digito de las unidades en ASCII para un numero 0..31.
    function [6:0] dec_ones;
        input [4:0] n;
        reg [4:0] v;
        begin
            if      (n >= 30) v = n - 5'd30;
            else if (n >= 20) v = n - 5'd20;
            else if (n >= 10) v = n - 5'd10;
            else              v = n;
            dec_ones = 7'h30 + {2'b0, v};
        end
    endfunction

    // ---------------------------------------------------------------
    // Register file address: combinational from (col, row)
    // ---------------------------------------------------------------
    wire        in_reg_rows  = (row >= 5'd5) && (row <= 5'd20);
    wire [4:0]  reg_idx_l    = row - 5'd5;        // 0..15
    wire [4:0]  reg_idx_r    = row - 5'd5 + 5'd16; // 16..31

    assign reg_debug_addr = in_reg_rows
                          ? (col >= 7'd40 ? reg_idx_r : reg_idx_l)
                          : 5'd0;

    // ---------------------------------------------------------------
    // ASCII character for current cell
    // ---------------------------------------------------------------
    reg [6:0] ascii;

    always @(*) begin
        ascii = 7'h20; // default: space

        case (row)

        // ---- Row 0: PC / INSTR / ALU / Z / HALT / MEM ----
        5'd0: begin
            if      (col == 7'd0)  ascii = "P";
            else if (col == 7'd1)  ascii = "C";
            else if (col == 7'd2)  ascii = ":";
            else if (col == 7'd3)  ascii = hn(pc_out[31:28]);
            else if (col == 7'd4)  ascii = hn(pc_out[27:24]);
            else if (col == 7'd5)  ascii = hn(pc_out[23:20]);
            else if (col == 7'd6)  ascii = hn(pc_out[19:16]);
            else if (col == 7'd7)  ascii = hn(pc_out[15:12]);
            else if (col == 7'd8)  ascii = hn(pc_out[11:8]);
            else if (col == 7'd9)  ascii = hn(pc_out[7:4]);
            else if (col == 7'd10) ascii = hn(pc_out[3:0]);
            else if (col == 7'd13) ascii = "I";
            else if (col == 7'd14) ascii = "N";
            else if (col == 7'd15) ascii = "S";
            else if (col == 7'd16) ascii = "T";
            else if (col == 7'd17) ascii = "R";
            else if (col == 7'd18) ascii = ":";
            else if (col == 7'd19) ascii = hn(instr[31:28]);
            else if (col == 7'd20) ascii = hn(instr[27:24]);
            else if (col == 7'd21) ascii = hn(instr[23:20]);
            else if (col == 7'd22) ascii = hn(instr[19:16]);
            else if (col == 7'd23) ascii = hn(instr[15:12]);
            else if (col == 7'd24) ascii = hn(instr[11:8]);
            else if (col == 7'd25) ascii = hn(instr[7:4]);
            else if (col == 7'd26) ascii = hn(instr[3:0]);
            else if (col == 7'd29) ascii = "A";
            else if (col == 7'd30) ascii = "L";
            else if (col == 7'd31) ascii = "U";
            else if (col == 7'd32) ascii = ":";
            else if (col == 7'd33) ascii = hn(alu_result[31:28]);
            else if (col == 7'd34) ascii = hn(alu_result[27:24]);
            else if (col == 7'd35) ascii = hn(alu_result[23:20]);
            else if (col == 7'd36) ascii = hn(alu_result[19:16]);
            else if (col == 7'd37) ascii = hn(alu_result[15:12]);
            else if (col == 7'd38) ascii = hn(alu_result[11:8]);
            else if (col == 7'd39) ascii = hn(alu_result[7:4]);
            else if (col == 7'd40) ascii = hn(alu_result[3:0]);
            else if (col == 7'd43) ascii = "Z";
            else if (col == 7'd44) ascii = ":";
            else if (col == 7'd45) ascii = bit_ch(alu_zero);
            else if (col == 7'd48) ascii = "H";
            else if (col == 7'd49) ascii = "A";
            else if (col == 7'd50) ascii = "L";
            else if (col == 7'd51) ascii = "T";
            else if (col == 7'd52) ascii = ":";
            else if (col == 7'd53) ascii = bit_ch(halted);
            else if (col == 7'd56) ascii = "M";
            else if (col == 7'd57) ascii = "E";
            else if (col == 7'd58) ascii = "M";
            else if (col == 7'd59) ascii = ":";
            else if (col == 7'd60) ascii = hn(mem_data_out[31:28]);
            else if (col == 7'd61) ascii = hn(mem_data_out[27:24]);
            else if (col == 7'd62) ascii = hn(mem_data_out[23:20]);
            else if (col == 7'd63) ascii = hn(mem_data_out[19:16]);
            else if (col == 7'd64) ascii = hn(mem_data_out[15:12]);
            else if (col == 7'd65) ascii = hn(mem_data_out[11:8]);
            else if (col == 7'd66) ascii = hn(mem_data_out[7:4]);
            else if (col == 7'd67) ascii = hn(mem_data_out[3:0]);
        end

        // ---- Row 1: OPC / F3 / F7 / RD / RS1 / RS2 / IMM ----
        5'd1: begin
            if      (col == 7'd0)  ascii = "O";
            else if (col == 7'd1)  ascii = "P";
            else if (col == 7'd2)  ascii = "C";
            else if (col == 7'd3)  ascii = ":";
            else if (col == 7'd4)  ascii = hn({1'b0, instr[6:4]});
            else if (col == 7'd5)  ascii = hn(instr[3:0]);
            else if (col == 7'd8)  ascii = "F";
            else if (col == 7'd9)  ascii = "3";
            else if (col == 7'd10) ascii = ":";
            else if (col == 7'd11) ascii = hn({1'b0, instr[14:12]});
            else if (col == 7'd14) ascii = "F";
            else if (col == 7'd15) ascii = "7";
            else if (col == 7'd16) ascii = ":";
            else if (col == 7'd17) ascii = hn({1'b0, instr[31:29]});
            else if (col == 7'd18) ascii = hn(instr[28:25]);
            else if (col == 7'd21) ascii = "R";
            else if (col == 7'd22) ascii = "D";
            else if (col == 7'd23) ascii = ":";
            else if (col == 7'd24) ascii = dec_tens(instr[11:7]);
            else if (col == 7'd25) ascii = dec_ones(instr[11:7]);
            else if (col == 7'd28) ascii = "R";
            else if (col == 7'd29) ascii = "S";
            else if (col == 7'd30) ascii = "1";
            else if (col == 7'd31) ascii = ":";
            else if (col == 7'd32) ascii = dec_tens(instr[19:15]);
            else if (col == 7'd33) ascii = dec_ones(instr[19:15]);
            else if (col == 7'd36) ascii = "R";
            else if (col == 7'd37) ascii = "S";
            else if (col == 7'd38) ascii = "2";
            else if (col == 7'd39) ascii = ":";
            else if (col == 7'd40) ascii = dec_tens(instr[24:20]);
            else if (col == 7'd41) ascii = dec_ones(instr[24:20]);
            else if (col == 7'd44) ascii = "I";
            else if (col == 7'd45) ascii = "M";
            else if (col == 7'd46) ascii = "M";
            else if (col == 7'd47) ascii = ":";
            else if (col == 7'd48) ascii = hn(imm_ext[31:28]);
            else if (col == 7'd49) ascii = hn(imm_ext[27:24]);
            else if (col == 7'd50) ascii = hn(imm_ext[23:20]);
            else if (col == 7'd51) ascii = hn(imm_ext[19:16]);
            else if (col == 7'd52) ascii = hn(imm_ext[15:12]);
            else if (col == 7'd53) ascii = hn(imm_ext[11:8]);
            else if (col == 7'd54) ascii = hn(imm_ext[7:4]);
            else if (col == 7'd55) ascii = hn(imm_ext[3:0]);
        end

        // ---- Row 2: CTL: RW=X MR=X MW=X M2R=X AS=X BR=X JL=X JR=X PS=X ----
        5'd2: begin
            if      (col == 7'd0)  ascii = "C";
            else if (col == 7'd1)  ascii = "T";
            else if (col == 7'd2)  ascii = "L";
            else if (col == 7'd3)  ascii = ":";
            else if (col == 7'd5)  ascii = "R";
            else if (col == 7'd6)  ascii = "W";
            else if (col == 7'd7)  ascii = "=";
            else if (col == 7'd8)  ascii = bit_ch(reg_write);
            else if (col == 7'd10) ascii = "M";
            else if (col == 7'd11) ascii = "R";
            else if (col == 7'd12) ascii = "=";
            else if (col == 7'd13) ascii = bit_ch(mem_read);
            else if (col == 7'd15) ascii = "M";
            else if (col == 7'd16) ascii = "W";
            else if (col == 7'd17) ascii = "=";
            else if (col == 7'd18) ascii = bit_ch(mem_write);
            else if (col == 7'd20) ascii = "M";
            else if (col == 7'd21) ascii = "2";
            else if (col == 7'd22) ascii = "R";
            else if (col == 7'd23) ascii = "=";
            else if (col == 7'd24) ascii = bit_ch(mem_to_reg);
            else if (col == 7'd26) ascii = "A";
            else if (col == 7'd27) ascii = "S";
            else if (col == 7'd28) ascii = "=";
            else if (col == 7'd29) ascii = bit_ch(alu_src);
            else if (col == 7'd31) ascii = "B";
            else if (col == 7'd32) ascii = "R";
            else if (col == 7'd33) ascii = "=";
            else if (col == 7'd34) ascii = bit_ch(branch);
            else if (col == 7'd36) ascii = "J";
            else if (col == 7'd37) ascii = "L";
            else if (col == 7'd38) ascii = "=";
            else if (col == 7'd39) ascii = bit_ch(jal);
            else if (col == 7'd41) ascii = "J";
            else if (col == 7'd42) ascii = "R";
            else if (col == 7'd43) ascii = "=";
            else if (col == 7'd44) ascii = bit_ch(jalr);
            else if (col == 7'd46) ascii = "P";
            else if (col == 7'd47) ascii = "C";
            else if (col == 7'd48) ascii = "S";
            else if (col == 7'd49) ascii = "=";
            else if (col == 7'd50) ascii = bit_ch(pc_src);
        end

        // ---- Row 4: --- REGISTERS --- ----
        5'd4: begin
            if      (col == 7'd0)  ascii = "-";
            else if (col == 7'd1)  ascii = "-";
            else if (col == 7'd2)  ascii = "-";
            else if (col == 7'd4)  ascii = "R";
            else if (col == 7'd5)  ascii = "E";
            else if (col == 7'd6)  ascii = "G";
            else if (col == 7'd7)  ascii = "I";
            else if (col == 7'd8)  ascii = "S";
            else if (col == 7'd9)  ascii = "T";
            else if (col == 7'd10) ascii = "E";
            else if (col == 7'd11) ascii = "R";
            else if (col == 7'd12) ascii = "S";
            else if (col == 7'd14) ascii = "-";
            else if (col == 7'd15) ascii = "-";
            else if (col == 7'd16) ascii = "-";
        end

        // ---- Rows 5-20: xNN=XXXXXXXX pairs ----
        default: begin
            if (in_reg_rows) begin
                // Left panel: x00..x15
                if      (col == 7'd0)  ascii = "x";
                else if (col == 7'd1)  ascii = dec_tens(reg_idx_l);
                else if (col == 7'd2)  ascii = dec_ones(reg_idx_l);
                else if (col == 7'd3)  ascii = "=";
                else if (col == 7'd4)  ascii = hn(reg_debug_data[31:28]);
                else if (col == 7'd5)  ascii = hn(reg_debug_data[27:24]);
                else if (col == 7'd6)  ascii = hn(reg_debug_data[23:20]);
                else if (col == 7'd7)  ascii = hn(reg_debug_data[19:16]);
                else if (col == 7'd8)  ascii = hn(reg_debug_data[15:12]);
                else if (col == 7'd9)  ascii = hn(reg_debug_data[11:8]);
                else if (col == 7'd10) ascii = hn(reg_debug_data[7:4]);
                else if (col == 7'd11) ascii = hn(reg_debug_data[3:0]);
                // Right panel: x16..x31
                else if (col == 7'd40) ascii = "x";
                else if (col == 7'd41) ascii = dec_tens(reg_idx_r);
                else if (col == 7'd42) ascii = dec_ones(reg_idx_r);
                else if (col == 7'd43) ascii = "=";
                else if (col == 7'd44) ascii = hn(reg_debug_data[31:28]);
                else if (col == 7'd45) ascii = hn(reg_debug_data[27:24]);
                else if (col == 7'd46) ascii = hn(reg_debug_data[23:20]);
                else if (col == 7'd47) ascii = hn(reg_debug_data[19:16]);
                else if (col == 7'd48) ascii = hn(reg_debug_data[15:12]);
                else if (col == 7'd49) ascii = hn(reg_debug_data[11:8]);
                else if (col == 7'd50) ascii = hn(reg_debug_data[7:4]);
                else if (col == 7'd51) ascii = hn(reg_debug_data[3:0]);
            end
        end

        endcase
    end

    // ---------------------------------------------------------------
    // Pixel: font ROM lookup
    // ---------------------------------------------------------------
    wire [7:0] font_byte = font_rom[{ascii[6:0], glyph_row}];
    wire       pixel     = font_byte[7 - glyph_col]; // MSB = leftmost pixel

    // ---------------------------------------------------------------
    // Color: per-row foreground, black background
    // ---------------------------------------------------------------
    reg [7:0] fr, fg, fb;
    always @(*) begin
        if      (row == 5'd0) {fr, fg, fb} = {8'hFF, 8'hFF, 8'h00}; // yellow
        else if (row == 5'd2) {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF}; // cyan
        else if (row == 5'd4) {fr, fg, fb} = {8'h00, 8'hFF, 8'h00}; // green
        else                  {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF}; // white
    end

    // HALT character turns red when halted
    wire halt_cell = (row == 5'd0) && (col == 7'd53);
    wire [7:0] pr  = (halt_cell && halted) ? 8'hFF : fr;
    wire [7:0] pg  = (halt_cell && halted) ? 8'h00 : fg;
    wire [7:0] pb  = (halt_cell && halted) ? 8'h00 : fb;

    always @(*) begin
        if (~video_on)
            {vga_r, vga_g, vga_b} = 24'h0;
        else if (pixel)
            {vga_r, vga_g, vga_b} = {pr, pg, pb};
        else
            {vga_r, vga_g, vga_b} = 24'h0; // black background
    end

endmodule
