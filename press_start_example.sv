module press_start_example (
	input logic vga_clk,
	input logic [9:0] DrawX, DrawY,
	input logic blank,
	output logic [3:0] red, green, blue,
	output logic on
);

logic [11:0] rom_address;
logic rom_q;

logic [3:0] palette_red, palette_green, palette_blue;

logic negedge_vga_clk;

// read from ROM on negedge, set pixel on posedge
assign negedge_vga_clk = ~vga_clk;

always_comb no_repeat: begin
    if ((DrawX >= 220) && 
    (DrawX <= 420) && 
    (DrawY >= 380) && 
    (DrawY <= 400)) begin
        on = 1'b1;
    end
    else begin
        on = 1'b0;
    end

end


assign rom_address = (DrawX % 220) + ((DrawY % 380) * 200);

always_ff @ (posedge vga_clk) begin
	red <= 4'h0;
	green <= 4'h0;
	blue <= 4'h0;

	if (blank) begin
		red <= palette_red;
		green <= palette_green;
		blue <= palette_blue;
	end
end

press_any_key press_start_rom (
	.clka   (negedge_vga_clk),
	.addra (rom_address),
	.douta       (rom_q)
);

press_start_palette press_start_palette (
	.index (rom_q),
	.red   (palette_red),
	.green (palette_green),
	.blue  (palette_blue)
);

endmodule
