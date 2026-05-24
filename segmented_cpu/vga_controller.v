// VGA timing generator for 640x480 @ 60 Hz (25 MHz pixel clock).
// Internally divides the 50 MHz input clock using clock_div.
module vga_controller (
    input        clk_50MHz,
    input        reset,
    output       video_on,
    output       hsync,
    output       vsync,
    output       clk,       // 25 MHz pixel clock (also drives VGA_CLK pin)
    output [9:0] x,
    output [9:0] y
);
    // VESA 640x480 @ 60 Hz parameters
    parameter HD   = 640; // horizontal display
    parameter HF   = 48;  // front porch
    parameter HB   = 16;  // back porch
    parameter HR   = 96;  // retrace
    parameter HMAX = HD + HF + HB + HR - 1; // 799

    parameter VD   = 480;
    parameter VF   = 10;
    parameter VB   = 33;
    parameter VR   = 2;
    parameter VMAX = VD + VF + VB + VR - 1; // 524

    wire w_25MHz;
    clock_div u_clkdiv (.clock50(clk_50MHz), .reset(reset), .clock25(w_25MHz));

    reg [9:0] h_count_reg, h_count_next;
    reg [9:0] v_count_reg, v_count_next;
    reg       v_sync_reg,  h_sync_reg;
    wire      v_sync_next, h_sync_next;

    always @(posedge clk_50MHz or posedge reset) begin
        if (reset) begin
            v_count_reg <= 10'd0;
            h_count_reg <= 10'd0;
            v_sync_reg  <= 1'b0;
            h_sync_reg  <= 1'b0;
        end else begin
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg  <= v_sync_next;
            h_sync_reg  <= h_sync_next;
        end
    end

    always @(posedge w_25MHz or posedge reset)
        if (reset)
            h_count_next = 10'd0;
        else if (h_count_reg == HMAX)
            h_count_next = 10'd0;
        else
            h_count_next = h_count_reg + 10'd1;

    always @(posedge w_25MHz or posedge reset)
        if (reset)
            v_count_next = 10'd0;
        else if (h_count_reg == HMAX)
            v_count_next = (v_count_reg == VMAX) ? 10'd0 : v_count_reg + 10'd1;

    assign h_sync_next = (h_count_reg >= (HD + HB)) && (h_count_reg <= (HD + HB + HR - 1));
    assign v_sync_next = (v_count_reg >= (VD + VB)) && (v_count_reg <= (VD + VB + VR - 1));
    assign video_on    = (h_count_reg < HD) && (v_count_reg < VD);

    assign hsync = h_sync_reg;
    assign vsync = v_sync_reg;
    assign x     = h_count_reg;
    assign y     = v_count_reg;
    assign clk   = w_25MHz;
endmodule
