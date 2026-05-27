// =============================================================================
// button_pulse.v - Anti-rebote para un pulsador activo-bajo (KEY de la DE1-SoC).
// Sincroniza la entrada, espera DEBOUNCE_LIMIT ciclos estables y emite un pulso
// de 1 ciclo en cada PULSACION (flanco de bajada del valor ya estable).
// =============================================================================
module button_pulse #(
    parameter DEBOUNCE_LIMIT = 50000
) (
    input  clk,
    input  rst,
    input  btn,     // pulsador crudo, activo en bajo
    output pulse    // 1 ciclo por pulsacion
);

reg        sync0, sync1;
reg [15:0] count;
reg        stable;
reg        stable_prev;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sync0  <= 1'b1;
        sync1  <= 1'b1;
        count  <= 16'b0;
        stable <= 1'b1;
    end else begin
        sync0 <= btn;
        sync1 <= sync0;
        if (sync1 == stable) begin
            count <= 16'b0;
        end else if (count == DEBOUNCE_LIMIT - 1) begin
            stable <= sync1;
            count  <= 16'b0;
        end else begin
            count <= count + 1'b1;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) stable_prev <= 1'b1;
    else     stable_prev <= stable;
end

assign pulse = stable_prev & ~stable;  // flanco de bajada = pulsacion

endmodule
