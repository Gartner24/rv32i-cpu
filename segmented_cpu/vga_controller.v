// VGA timing generator for 800x600 @ 72 Hz (VESA), 50 MHz dot clock.
// The 50 MHz input IS the pixel clock (no PLL, no divider). VGA_CLK pin is
// driven directly from clk_50MHz. Character grid with the 8x16 font: 100x37.
module vga_controller (
    input         clk_50MHz,
    input         reset,
    output        video_on,
    output        hsync,
    output        vsync,
    output        clk,        // pixel clock out (= clk_50MHz, drives VGA_CLK pin)
    output [10:0] x,
    output [10:0] y
);
    // VESA 800x600 @ 72 Hz, dot clock 50.000 MHz
    parameter HD = 800;  // horizontal display
    parameter HF = 56;   // front porch
    parameter HR = 120;  // sync (retrace)
    parameter HB = 64;   // back porch
    parameter HMAX = HD + HF + HR + HB - 1; // 1039

    parameter VD = 600;
    parameter VF = 37;
    parameter VR = 6;
    parameter VB = 23;
    parameter VMAX = VD + VF + VR + VB - 1; // 665

    reg [10:0] h_count, v_count;
    reg        h_sync_reg, v_sync_reg;

    always @(posedge clk_50MHz or posedge reset) begin
        if (reset) begin
            h_count    <= 11'd0;
            v_count    <= 11'd0;
            h_sync_reg <= 1'b0;
            v_sync_reg <= 1'b0;
        end else begin
            if (h_count == HMAX) begin
                h_count <= 11'd0;
                v_count <= (v_count == VMAX) ? 11'd0 : v_count + 11'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end
            // 800x600@72 uses POSITIVE sync polarity (pulse = 1)
            h_sync_reg <= (h_count >= (HD + HF)) && (h_count < (HD + HF + HR));
            v_sync_reg <= (v_count >= (VD + VF)) && (v_count < (VD + VF + VR));
        end
    end

    assign hsync    = h_sync_reg;
    assign vsync    = v_sync_reg;
    assign x        = h_count;
    assign y        = v_count;
    assign video_on = (h_count < HD) && (v_count < VD);
    assign clk      = clk_50MHz;
endmodule
