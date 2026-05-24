// =============================================================================
// vga_debug.v - Muestra el estado completo de la CPU por pantalla (640x480).
// Dibuja una grilla de 80x30 caracteres (fuente 8x16, font128.hex).
// Completamente combinacional: dada la posicion del pixel (x,y) y las senales
// de la CPU, produce directamente el color RGB sin estado interno.
//
// Distribucion de filas en pantalla (80 columnas x 30 filas):
//   Fila 0-4 (amarillo): valores de 32 bits del datapath
//   Fila 5  (blanco):   campos decodificados (OPCODE/FUNCT3/FUNCT7/RD/RS1/RS2)
//   Fila 6-8 (cyan):    estado y senales de control (nombres completos)
//   Fila 10 (verde):    encabezado REGISTERS
//   Fila 11-18 (blanco): 32 registros en 4 columnas (x0..x31)
//   Fila 20 (verde):    encabezado DATA MEMORY
//   Fila 21-28 (blanco): 32 palabras de memoria en 4 columnas (m0..m31)
// =============================================================================

module vga_debug (
    input         video_on,
    input  [9:0]  x, y,

    // valores de 32 bits del datapath
    input  [31:0] pc_out,
    input  [31:0] instr,
    input  [31:0] imm_ext,
    input  [31:0] alu_result,
    input  [31:0] alu_operand_a,
    input  [31:0] alu_operand_b,
    input  [31:0] reg_data1,
    input  [31:0] reg_data2,
    input  [31:0] wb_data,
    input  [31:0] mem_data_out,

    // estado y control
    input         alu_zero,
    input         halted,
    input         branch_taken,
    input  [1:0]  alu_op,
    input  [3:0]  alu_ctrl,
    input         reg_write,
    input         mem_read,
    input         mem_write,
    input         mem_to_reg,
    input         alu_src,
    input         alu_a_src,
    input         branch,
    input         jal,
    input         jalr,
    input         pc_src,

    // banco de registros (lectura combinacional por direccion)
    output [4:0]  reg_debug_addr,
    input  [31:0] reg_debug_data,

    // memoria de datos (lectura combinacional por direccion)
    output [4:0]  mem_debug_addr,
    input  [31:0] mem_debug_data,

    output reg [7:0] vga_r,
    output reg [7:0] vga_g,
    output reg [7:0] vga_b
);

    localparam [6:0] SP = 7'h20; // caracter espacio

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
    // Nibble (0-15) a ASCII hexadecimal ('0'..'9', 'A'..'F').
    function [6:0] hn;
        input [3:0] n;
        begin
            if (n < 4'd10) hn = 7'h30 + {3'b0, n};
            else           hn = 7'h37 + {3'b0, n}; // 'A'=0x41; 0x41-10=0x37
        end
    endfunction

    // Bit a ASCII: 0 -> '0', 1 -> '1'.
    function [6:0] bit_ch;
        input b;
        bit_ch = b ? 7'h31 : 7'h30;
    endfunction

    // Digito de las decenas en ASCII para un numero 0..31.
    function [6:0] dec_tens;
        input [4:0] n;
        begin
            if      (n >= 30) dec_tens = 7'h33;
            else if (n >= 20) dec_tens = 7'h32;
            else if (n >= 10) dec_tens = 7'h31;
            else              dec_tens = 7'h30;
        end
    endfunction

    // Digito de las unidades en ASCII para un numero 0..31.
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

    // Caracter de uno de los 8 digitos hex de un valor de 32 bits.
    // Devuelve el digito en la columna actual `c` si cae en [base, base+7],
    // o espacio en caso contrario. El digito 0 (base) es el mas significativo.
    function [6:0] hx;
        input [31:0] val;
        input [6:0]  base;
        input [6:0]  c;
        reg   [2:0]  k;
        begin
            hx = SP;
            if (c >= base && c <= base + 7'd7) begin
                k  = c - base;                  // 0..7, 0 = MSB
                hx = hn(val[(7 - k) * 4 +: 4]);
            end
        end
    endfunction

    // Caracter de una etiqueta de texto colocada en la columna `base`.
    // `text` lleva la cadena justificada a la derecha (estilo Verilog).
    // Devuelve el caracter i-esimo (0 = izquierda) si la columna cae dentro,
    // o espacio en caso contrario.
    function [6:0] lbl;
        input [6:0]   c;
        input [6:0]   base;
        input [255:0] text;
        input [5:0]   len;
        reg   [5:0]   i;
        begin
            lbl = SP;
            if (c >= base && c < base + len) begin
                i   = c - base;                 // 0 = primer caracter
                lbl = text[(len - 1 - i) * 8 +: 8];
            end
        end
    endfunction

    // ---------------------------------------------------------------
    // Paneles de registros y memoria: 4 columnas de 8 filas.
    // La direccion a leer depende de la columna del pixel (grupo) y la fila.
    // ---------------------------------------------------------------
    wire        in_reg_rows = (row >= 5'd11) && (row <= 5'd18);
    wire        in_mem_rows = (row >= 5'd21) && (row <= 5'd28);
    wire [4:0]  ridx        = row - 5'd11;       // 0..7
    wire [4:0]  midx        = row - 5'd21;       // 0..7
    wire [1:0]  gcol        = (col < 7'd20) ? 2'd0 :
                              (col < 7'd40) ? 2'd1 :
                              (col < 7'd60) ? 2'd2 : 2'd3;
    wire [6:0]  gbase       = gcol * 7'd20;      // 0, 20, 40, 60

    assign reg_debug_addr = {gcol, 3'b0} + ridx; // gcol*8 + ridx
    assign mem_debug_addr = {gcol, 3'b0} + midx;

    // ---------------------------------------------------------------
    // ASCII character for current cell
    // ---------------------------------------------------------------
    reg [6:0] ascii;
    reg [6:0] t;

    always @(*) begin
        ascii = SP;
        t     = SP;

        case (row)

        // ---- Row 0: PC / INSTRUCTION ----
        5'd0: begin
            t = lbl(col, 7'd0,  "PC:", 6'd3);          if (t != SP) ascii = t;
            t = hx(pc_out, 7'd3, col);                 if (t != SP) ascii = t;
            t = lbl(col, 7'd40, "INSTRUCTION:", 6'd12);if (t != SP) ascii = t;
            t = hx(instr, 7'd52, col);                 if (t != SP) ascii = t;
        end

        // ---- Row 1: IMMEDIATE / ALU_RESULT ----
        5'd1: begin
            t = lbl(col, 7'd0,  "IMMEDIATE:", 6'd10);  if (t != SP) ascii = t;
            t = hx(imm_ext, 7'd10, col);               if (t != SP) ascii = t;
            t = lbl(col, 7'd40, "ALU_RESULT:", 6'd11); if (t != SP) ascii = t;
            t = hx(alu_result, 7'd51, col);            if (t != SP) ascii = t;
        end

        // ---- Row 2: ALU_OPERAND_A / ALU_OPERAND_B ----
        5'd2: begin
            t = lbl(col, 7'd0,  "ALU_OPERAND_A:", 6'd14); if (t != SP) ascii = t;
            t = hx(alu_operand_a, 7'd14, col);            if (t != SP) ascii = t;
            t = lbl(col, 7'd40, "ALU_OPERAND_B:", 6'd14); if (t != SP) ascii = t;
            t = hx(alu_operand_b, 7'd54, col);            if (t != SP) ascii = t;
        end

        // ---- Row 3: RS1_VALUE / RS2_VALUE ----
        5'd3: begin
            t = lbl(col, 7'd0,  "RS1_VALUE:", 6'd10);  if (t != SP) ascii = t;
            t = hx(reg_data1, 7'd10, col);             if (t != SP) ascii = t;
            t = lbl(col, 7'd40, "RS2_VALUE:", 6'd10);  if (t != SP) ascii = t;
            t = hx(reg_data2, 7'd50, col);             if (t != SP) ascii = t;
        end

        // ---- Row 4: WRITE_BACK / MEM_DATA ----
        5'd4: begin
            t = lbl(col, 7'd0,  "WRITE_BACK:", 6'd11); if (t != SP) ascii = t;
            t = hx(wb_data, 7'd11, col);               if (t != SP) ascii = t;
            t = lbl(col, 7'd40, "MEM_DATA:", 6'd9);    if (t != SP) ascii = t;
            t = hx(mem_data_out, 7'd49, col);          if (t != SP) ascii = t;
        end

        // ---- Row 5: OPCODE / FUNCT3 / FUNCT7 / RD / RS1 / RS2 ----
        5'd5: begin
            t = lbl(col, 7'd0,  "OPCODE:", 6'd7);      if (t != SP) ascii = t;
            if      (col == 7'd7)  ascii = hn({1'b0, instr[6:4]});
            else if (col == 7'd8)  ascii = hn(instr[3:0]);
            t = lbl(col, 7'd12, "FUNCT3:", 6'd7);      if (t != SP) ascii = t;
            if      (col == 7'd19) ascii = hn({1'b0, instr[14:12]});
            t = lbl(col, 7'd24, "FUNCT7:", 6'd7);      if (t != SP) ascii = t;
            if      (col == 7'd31) ascii = hn({1'b0, instr[31:29]});
            else if (col == 7'd32) ascii = hn(instr[28:25]);
            t = lbl(col, 7'd40, "RD:", 6'd3);          if (t != SP) ascii = t;
            if      (col == 7'd43) ascii = dec_tens(instr[11:7]);
            else if (col == 7'd44) ascii = dec_ones(instr[11:7]);
            t = lbl(col, 7'd48, "RS1:", 6'd4);         if (t != SP) ascii = t;
            if      (col == 7'd52) ascii = dec_tens(instr[19:15]);
            else if (col == 7'd53) ascii = dec_ones(instr[19:15]);
            t = lbl(col, 7'd58, "RS2:", 6'd4);         if (t != SP) ascii = t;
            if      (col == 7'd62) ascii = dec_tens(instr[24:20]);
            else if (col == 7'd63) ascii = dec_ones(instr[24:20]);
        end

        // ---- Row 6: ZERO / HALT / BRANCH_TAKEN / ALU_OP / ALU_CTRL ----
        5'd6: begin
            t = lbl(col, 7'd0,  "ZERO:", 6'd5);            if (t != SP) ascii = t;
            if (col == 7'd5)  ascii = bit_ch(alu_zero);
            t = lbl(col, 7'd10, "HALT:", 6'd5);            if (t != SP) ascii = t;
            if (col == 7'd15) ascii = bit_ch(halted);
            t = lbl(col, 7'd20, "BRANCH_TAKEN:", 6'd13);   if (t != SP) ascii = t;
            if (col == 7'd33) ascii = bit_ch(branch_taken);
            t = lbl(col, 7'd40, "ALU_OP:", 6'd7);          if (t != SP) ascii = t;
            if (col == 7'd47) ascii = hn({2'b0, alu_op});
            t = lbl(col, 7'd52, "ALU_CTRL:", 6'd9);        if (t != SP) ascii = t;
            if (col == 7'd61) ascii = hn(alu_ctrl);
        end

        // ---- Row 7: REG_WRITE / MEM_READ / MEM_WRITE / MEM_TO_REG / ALU_SRC ----
        5'd7: begin
            t = lbl(col, 7'd0,  "REG_WRITE:", 6'd10);  if (t != SP) ascii = t;
            if (col == 7'd10) ascii = bit_ch(reg_write);
            t = lbl(col, 7'd13, "MEM_READ:", 6'd9);    if (t != SP) ascii = t;
            if (col == 7'd22) ascii = bit_ch(mem_read);
            t = lbl(col, 7'd26, "MEM_WRITE:", 6'd10);  if (t != SP) ascii = t;
            if (col == 7'd36) ascii = bit_ch(mem_write);
            t = lbl(col, 7'd40, "MEM_TO_REG:", 6'd11); if (t != SP) ascii = t;
            if (col == 7'd51) ascii = bit_ch(mem_to_reg);
            t = lbl(col, 7'd55, "ALU_SRC:", 6'd8);     if (t != SP) ascii = t;
            if (col == 7'd63) ascii = bit_ch(alu_src);
        end

        // ---- Row 8: ALU_A_SRC / BRANCH / JAL / JALR / PC_SRC ----
        5'd8: begin
            t = lbl(col, 7'd0,  "ALU_A_SRC:", 6'd10);  if (t != SP) ascii = t;
            if (col == 7'd10) ascii = bit_ch(alu_a_src);
            t = lbl(col, 7'd13, "BRANCH:", 6'd7);      if (t != SP) ascii = t;
            if (col == 7'd20) ascii = bit_ch(branch);
            t = lbl(col, 7'd23, "JAL:", 6'd4);         if (t != SP) ascii = t;
            if (col == 7'd27) ascii = bit_ch(jal);
            t = lbl(col, 7'd30, "JALR:", 6'd5);        if (t != SP) ascii = t;
            if (col == 7'd35) ascii = bit_ch(jalr);
            t = lbl(col, 7'd40, "PC_SRC:", 6'd7);      if (t != SP) ascii = t;
            if (col == 7'd47) ascii = bit_ch(pc_src);
        end

        // ---- Row 10: ===== REGISTERS ===== ----
        5'd10: begin
            t = lbl(col, 7'd0, "===== REGISTERS =====", 6'd21); if (t != SP) ascii = t;
        end

        // ---- Row 20: ===== DATA MEMORY ===== ----
        5'd20: begin
            t = lbl(col, 7'd0, "===== DATA MEMORY =====", 6'd23); if (t != SP) ascii = t;
        end

        // ---- Rows 11-18 (registros) y 21-28 (memoria), 4 columnas ----
        default: begin
            if (in_reg_rows) begin
                if      (col == gbase)         ascii = "x";
                else if (col == gbase + 7'd1)  ascii = dec_tens(reg_debug_addr);
                else if (col == gbase + 7'd2)  ascii = dec_ones(reg_debug_addr);
                else if (col == gbase + 7'd3)  ascii = "=";
                else begin
                    t = hx(reg_debug_data, gbase + 7'd4, col);
                    if (t != SP) ascii = t;
                end
            end else if (in_mem_rows) begin
                if      (col == gbase)         ascii = "m";
                else if (col == gbase + 7'd1)  ascii = dec_tens(mem_debug_addr);
                else if (col == gbase + 7'd2)  ascii = dec_ones(mem_debug_addr);
                else if (col == gbase + 7'd3)  ascii = "=";
                else begin
                    t = hx(mem_debug_data, gbase + 7'd4, col);
                    if (t != SP) ascii = t;
                end
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
        if      (row <= 5'd4)                      {fr, fg, fb} = {8'hFF, 8'hFF, 8'h00}; // yellow
        else if (row == 5'd5)                      {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF}; // white
        else if (row >= 5'd6 && row <= 5'd8)       {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF}; // cyan
        else if (row == 5'd10 || row == 5'd20)     {fr, fg, fb} = {8'h00, 8'hFF, 8'h00}; // green
        else                                       {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF}; // white
    end

    // HALT character turns red when halted (row 6, col 15)
    wire halt_cell = (row == 5'd6) && (col == 7'd15);
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
