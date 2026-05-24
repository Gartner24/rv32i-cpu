// =============================================================================
// vga_debug.v - Vista de depuracion del pipeline de 5 etapas (640x480).
// Grilla de 80x30 caracteres (fuente 8x16, font128.hex). Completamente
// combinacional: dada la posicion del pixel (x,y) y el estado de cada etapa,
// produce el color RGB sin estado interno.
//
// Distribucion de filas:
//   0      (amarillo): titulo
//   1-5    (blanco):   una fila por etapa IF/ID/EX/MEM/WB (PC, instruccion, ...)
//   6      (cyan):     riesgos: STALL / FLUSH / forwarding A,B / HALT
//   8      (verde):    encabezado REGISTERS
//   9-16   (blanco):   32 registros en 4 columnas (x0..x31)
//   18     (verde):    encabezado DATA MEMORY
//   19-26  (blanco):   32 palabras de memoria en 4 columnas (m0..m31)
// =============================================================================
module vga_debug (
    input         video_on,
    input  [9:0]  x, y,

    // etapas del pipeline
    input  [31:0] if_pc,   if_instr,
    input  [31:0] id_pc,   id_instr,
    input  [31:0] ex_pc,   ex_instr, ex_alu,
    input  [31:0] mem_instr, mem_alu,
    input  [31:0] wb_instr, wb_data,
    input  [4:0]  wb_rd,
    input         wb_we,

    // riesgos / forwarding / halt
    input         stall,
    input         flush,
    input  [1:0]  forward_a,
    input  [1:0]  forward_b,
    input         halted,

    // banco de registros (lectura combinacional por direccion)
    output [4:0]  reg_debug_addr,
    input  [31:0] reg_debug_data,
    // memoria de datos
    output [4:0]  mem_debug_addr,
    input  [31:0] mem_debug_data,

    output reg [7:0] vga_r,
    output reg [7:0] vga_g,
    output reg [7:0] vga_b
);

    localparam [6:0] SP = 7'h20;

    reg [7:0] font_rom [0:2047];
    initial $readmemh("font128.hex", font_rom);

    wire [6:0] col       = x[9:3];
    wire [2:0] glyph_col = x[2:0];
    wire [4:0] row       = y[8:4];
    wire [3:0] glyph_row = y[3:0];

    // ---------------- funciones auxiliares ----------------
    function [6:0] hn;
        input [3:0] n;
        begin
            if (n < 4'd10) hn = 7'h30 + {3'b0, n};
            else           hn = 7'h37 + {3'b0, n};
        end
    endfunction

    function [6:0] bit_ch;
        input b;
        bit_ch = b ? 7'h31 : 7'h30;
    endfunction

    function [6:0] dec_tens;
        input [4:0] n;
        begin
            if      (n >= 30) dec_tens = 7'h33;
            else if (n >= 20) dec_tens = 7'h32;
            else if (n >= 10) dec_tens = 7'h31;
            else              dec_tens = 7'h30;
        end
    endfunction

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

    // digito hex de un valor de 32 bits (8 digitos a partir de la columna base)
    function [6:0] hx;
        input [31:0] val;
        input [6:0]  base;
        input [6:0]  c;
        reg   [2:0]  k;
        begin
            hx = SP;
            if (c >= base && c <= base + 7'd7) begin
                k  = c - base;
                hx = hn(val[(7 - k) * 4 +: 4]);
            end
        end
    endfunction

    // caracter de una etiqueta de texto colocada en la columna base
    function [6:0] lbl;
        input [6:0]   c;
        input [6:0]   base;
        input [255:0] text;
        input [5:0]   len;
        reg   [5:0]   i;
        begin
            lbl = SP;
            if (c >= base && c < base + len) begin
                i   = c - base;
                lbl = text[(len - 1 - i) * 8 +: 8];
            end
        end
    endfunction

    // ---------------- paneles de registros / memoria (4 columnas) ----------
    wire        in_reg_rows = (row >= 5'd9)  && (row <= 5'd16);
    wire        in_mem_rows = (row >= 5'd19) && (row <= 5'd26);
    wire [4:0]  ridx        = row - 5'd9;
    wire [4:0]  midx        = row - 5'd19;
    wire [1:0]  gcol        = (col < 7'd20) ? 2'd0 :
                              (col < 7'd40) ? 2'd1 :
                              (col < 7'd60) ? 2'd2 : 2'd3;
    wire [6:0]  gbase       = gcol * 7'd20;

    assign reg_debug_addr = {gcol, 3'b0} + ridx;
    assign mem_debug_addr = {gcol, 3'b0} + midx;

    // campos decodificados de la instruccion en ID
    wire [4:0] id_rs1 = id_instr[19:15];
    wire [4:0] id_rs2 = id_instr[24:20];
    wire [4:0] id_rd  = id_instr[11:7];

    // ---------------- caracter de la celda actual ----------
    reg [6:0] ascii;
    reg [6:0] t;

    always @(*) begin
        ascii = SP;
        t     = SP;

        case (row)

        // ---- titulo ----
        5'd0: begin
            t = lbl(col, 7'd0, "===== PIPELINE 5 ETAPAS =====", 6'd29);
            if (t != SP) ascii = t;
        end

        // ---- IF ----
        5'd1: begin
            t = lbl(col, 7'd0,  "IF", 6'd2);    if (t != SP) ascii = t;
            t = lbl(col, 7'd4,  "PC:", 6'd3);   if (t != SP) ascii = t;
            t = hx(if_pc, 7'd7, col);           if (t != SP) ascii = t;
            t = lbl(col, 7'd17, "IR:", 6'd3);   if (t != SP) ascii = t;
            t = hx(if_instr, 7'd20, col);       if (t != SP) ascii = t;
        end

        // ---- ID ----
        5'd2: begin
            t = lbl(col, 7'd0,  "ID", 6'd2);    if (t != SP) ascii = t;
            t = lbl(col, 7'd4,  "PC:", 6'd3);   if (t != SP) ascii = t;
            t = hx(id_pc, 7'd7, col);           if (t != SP) ascii = t;
            t = lbl(col, 7'd17, "IR:", 6'd3);   if (t != SP) ascii = t;
            t = hx(id_instr, 7'd20, col);       if (t != SP) ascii = t;
            t = lbl(col, 7'd30, "RS1:", 6'd4);  if (t != SP) ascii = t;
            if      (col == 7'd34) ascii = dec_tens(id_rs1);
            else if (col == 7'd35) ascii = dec_ones(id_rs1);
            t = lbl(col, 7'd38, "RS2:", 6'd4);  if (t != SP) ascii = t;
            if      (col == 7'd42) ascii = dec_tens(id_rs2);
            else if (col == 7'd43) ascii = dec_ones(id_rs2);
            t = lbl(col, 7'd46, "RD:", 6'd3);   if (t != SP) ascii = t;
            if      (col == 7'd49) ascii = dec_tens(id_rd);
            else if (col == 7'd50) ascii = dec_ones(id_rd);
        end

        // ---- EX ----
        5'd3: begin
            t = lbl(col, 7'd0,  "EX", 6'd2);    if (t != SP) ascii = t;
            t = lbl(col, 7'd4,  "PC:", 6'd3);   if (t != SP) ascii = t;
            t = hx(ex_pc, 7'd7, col);           if (t != SP) ascii = t;
            t = lbl(col, 7'd17, "IR:", 6'd3);   if (t != SP) ascii = t;
            t = hx(ex_instr, 7'd20, col);       if (t != SP) ascii = t;
            t = lbl(col, 7'd30, "ALU:", 6'd4);  if (t != SP) ascii = t;
            t = hx(ex_alu, 7'd34, col);         if (t != SP) ascii = t;
            t = lbl(col, 7'd44, "RD:", 6'd3);   if (t != SP) ascii = t;
            if      (col == 7'd47) ascii = dec_tens(ex_instr[11:7]);
            else if (col == 7'd48) ascii = dec_ones(ex_instr[11:7]);
        end

        // ---- MEM ----
        5'd4: begin
            t = lbl(col, 7'd0,  "MEM", 6'd3);   if (t != SP) ascii = t;
            t = lbl(col, 7'd4,  "IR:", 6'd3);   if (t != SP) ascii = t;
            t = hx(mem_instr, 7'd7, col);       if (t != SP) ascii = t;
            t = lbl(col, 7'd17, "ALU:", 6'd4);  if (t != SP) ascii = t;
            t = hx(mem_alu, 7'd21, col);        if (t != SP) ascii = t;
            t = lbl(col, 7'd31, "RD:", 6'd3);   if (t != SP) ascii = t;
            if      (col == 7'd34) ascii = dec_tens(mem_instr[11:7]);
            else if (col == 7'd35) ascii = dec_ones(mem_instr[11:7]);
        end

        // ---- WB ----
        5'd5: begin
            t = lbl(col, 7'd0,  "WB", 6'd2);    if (t != SP) ascii = t;
            t = lbl(col, 7'd4,  "IR:", 6'd3);   if (t != SP) ascii = t;
            t = hx(wb_instr, 7'd7, col);        if (t != SP) ascii = t;
            t = lbl(col, 7'd17, "WB:", 6'd3);   if (t != SP) ascii = t;
            t = hx(wb_data, 7'd20, col);        if (t != SP) ascii = t;
            t = lbl(col, 7'd30, "RD:", 6'd3);   if (t != SP) ascii = t;
            if      (col == 7'd33) ascii = dec_tens(wb_rd);
            else if (col == 7'd34) ascii = dec_ones(wb_rd);
            t = lbl(col, 7'd37, "WE:", 6'd3);   if (t != SP) ascii = t;
            if      (col == 7'd40) ascii = bit_ch(wb_we);
        end

        // ---- riesgos / forwarding / halt ----
        5'd6: begin
            t = lbl(col, 7'd0,  "STALL:", 6'd6);  if (t != SP) ascii = t;
            if (col == 7'd6)  ascii = bit_ch(stall);
            t = lbl(col, 7'd9,  "FLUSH:", 6'd6);  if (t != SP) ascii = t;
            if (col == 7'd15) ascii = bit_ch(flush);
            t = lbl(col, 7'd18, "FWDA:", 6'd5);   if (t != SP) ascii = t;
            if (col == 7'd23) ascii = hn({2'b0, forward_a});
            t = lbl(col, 7'd26, "FWDB:", 6'd5);   if (t != SP) ascii = t;
            if (col == 7'd31) ascii = hn({2'b0, forward_b});
            t = lbl(col, 7'd34, "HALT:", 6'd5);   if (t != SP) ascii = t;
            if (col == 7'd39) ascii = bit_ch(halted);
        end

        // ---- encabezado registros ----
        5'd8: begin
            t = lbl(col, 7'd0, "===== REGISTERS =====", 6'd21);
            if (t != SP) ascii = t;
        end

        // ---- encabezado memoria ----
        5'd18: begin
            t = lbl(col, 7'd0, "===== DATA MEMORY =====", 6'd23);
            if (t != SP) ascii = t;
        end

        // ---- filas de registros (9-16) y memoria (19-26), 4 columnas ----
        default: begin
            if (in_reg_rows) begin
                if      (col == gbase)        ascii = "x";
                else if (col == gbase + 7'd1) ascii = dec_tens(reg_debug_addr);
                else if (col == gbase + 7'd2) ascii = dec_ones(reg_debug_addr);
                else if (col == gbase + 7'd3) ascii = "=";
                else begin
                    t = hx(reg_debug_data, gbase + 7'd4, col);
                    if (t != SP) ascii = t;
                end
            end else if (in_mem_rows) begin
                if      (col == gbase)        ascii = "m";
                else if (col == gbase + 7'd1) ascii = dec_tens(mem_debug_addr);
                else if (col == gbase + 7'd2) ascii = dec_ones(mem_debug_addr);
                else if (col == gbase + 7'd3) ascii = "=";
                else begin
                    t = hx(mem_debug_data, gbase + 7'd4, col);
                    if (t != SP) ascii = t;
                end
            end
        end

        endcase
    end

    // ---------------- pixel y color ----------------
    wire [7:0] font_byte = font_rom[{ascii[6:0], glyph_row}];
    wire       pixel     = font_byte[7 - glyph_col];

    reg [7:0] fr, fg, fb;
    always @(*) begin
        if      (row == 5'd0)                  {fr, fg, fb} = {8'hFF, 8'hFF, 8'h00}; // amarillo
        else if (row >= 5'd1 && row <= 5'd5)   {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF}; // blanco
        else if (row == 5'd6)                  {fr, fg, fb} = {8'h00, 8'hFF, 8'hFF}; // cyan
        else if (row == 5'd8 || row == 5'd18)  {fr, fg, fb} = {8'h00, 8'hFF, 8'h00}; // verde
        else                                   {fr, fg, fb} = {8'hFF, 8'hFF, 8'hFF}; // blanco
    end

    // HALT en rojo cuando esta detenido (fila 6, col 39)
    wire halt_cell = (row == 5'd6) && (col == 7'd39);
    wire [7:0] pr  = (halt_cell && halted) ? 8'hFF : fr;
    wire [7:0] pg  = (halt_cell && halted) ? 8'h00 : fg;
    wire [7:0] pb  = (halt_cell && halted) ? 8'h00 : fb;

    always @(*) begin
        if (~video_on)
            {vga_r, vga_g, vga_b} = 24'h0;
        else if (pixel)
            {vga_r, vga_g, vga_b} = {pr, pg, pb};
        else
            {vga_r, vga_g, vga_b} = 24'h0;
    end

endmodule
