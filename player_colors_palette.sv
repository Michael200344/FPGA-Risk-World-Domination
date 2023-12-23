module player_colors_palette (
	input logic [1:0] index,
	output logic [3:0] red, green, blue
);

localparam [0:3][11:0] palette = {
	{4'h9, 4'h2, 4'h1}, // Dark red 
	{4'h2, 4'hA, 4'h1}, // Green
	{4'hD, 4'h8, 4'h0}, // Orange
	{4'h0, 4'h0, 4'h0}  // Black
};

assign {red, green, blue} = palette[index];

endmodule
