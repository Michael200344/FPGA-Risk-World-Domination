module text_mapper(
    input logic vga_clk,
	input logic [9:0] DrawX, DrawY,
	input logic blank, setup,
	input int troops_chars [0:19], player_input [0:30], // allows for 20 possible characters to be displayed
	input int p_name [0:7],
	input int victory_txt [0:7],
	input logic [1:0] p_color,
	input logic [70:0] territories [42],
	input logic vic_on,
	output logic [3:0] red, green, blue, red_t, green_t, blue_t,
	output logic txt_on, t_on
    );
    
    logic [7:0] row_data, row_data_t;
    logic [10:0] rom_address, rom_address_t;
    
    logic [3:0] p_red, p_green, p_blue;
    
    int start_address, start_address_t;
    int x_start_troops = 10, x_start_input = 240, x_pname = 566, x_territory;
    int y_start_troops = 10, y_start_input = 380, y_pname = 10, y_territory;
    int width = 8;
    int height = 16;
    int current_char, current_char_t;
    logic [1:0] color_idx = p_color;
    int number = 0;
    int numbers [1:0];
    int x_vic = 256, y_vic = 232;
    
always_comb begin
    
    ///// To avoid latches /////
    blue = 4'h0;
    red = 4'h0;
    green = 4'h0;
    rom_address_t = 0;
    rom_address = 0;
    red_t = 4'h0;
    green_t = 4'h0;
    blue_t = 4'h0;
    
    
    ///////////// Draw troops text in lines below /////////////
    t_on = 1'b0;
    if (vic_on) begin
        color_idx = p_color; // Winning players color
        if (DrawX >= x_vic && DrawX < (x_vic + (width * $size(victory_txt))) && 
        DrawY >= y_vic && DrawY < (y_vic + height)) begin
            current_char = victory_txt[(DrawX - x_vic) / 8];
            start_address = current_char * 16;
            rom_address = start_address + (DrawY - y_vic);
            if (row_data[7 - ((DrawX - x_vic) % 8)] == 1'b1 && current_char !=0) begin
                red = 16'h0000;
                green = 16'h0000;
                blue = 16'h0000;
            end else begin
                red = p_red;
                blue = p_blue;
                green = p_green;
            end
        end else if (DrawX >= x_vic && DrawX < (x_vic + (width * $size(p_name))) && 
        DrawY >= (y_vic + height) && DrawY < (y_vic + (2*height))) begin
            current_char = p_name[(DrawX - x_vic) / 8];
            start_address = current_char * 16;
            rom_address = start_address + (DrawY - (y_vic + 8));
            if (row_data[7 - ((DrawX - x_vic) % 8)] == 1'b1 && current_char !=0) begin
                red = 16'h0000;
                green = 16'h0000;
                blue = 16'h0000;
            end else begin
                red = p_red;
                blue = p_blue;
                green = p_green;
            end
        end else begin
            red = p_red;
            blue = p_blue;
            green = p_green;
        end
    
    
    end else if (DrawX >= x_start_troops && DrawX < (x_start_troops + (width * $size(troops_chars))) && 
    DrawY >= y_start_troops && DrawY < y_start_troops + height) begin
        current_char = troops_chars[(DrawX - x_start_troops) / 8];
        start_address = current_char * 16;
        rom_address = start_address + (DrawY - y_start_troops);
        if (row_data[7 - ((DrawX - x_start_troops) % 8)] == 1'b1 && current_char !=0) begin
                txt_on = 1'b1;
                red = 16'hFFFF;
                green = 16'hFFFF;
                blue = 16'hFFFF;
        end else begin
                txt_on = 1'b0;
        end

    ///////////// Draw Player Input in Lines Below /////////////
    
    end else if (DrawX >= x_start_input && DrawX < (x_start_input + (width * $size(player_input))) 
    && DrawY >= y_start_input && DrawY < y_start_input + height) begin
        current_char = player_input[(DrawX - x_start_input) / 8];
        start_address = current_char * 16;
        rom_address = start_address + (DrawY - y_start_input);
        if (row_data[7 - ((DrawX - x_start_input) % 8)] == 1'b1 && current_char !=0) begin
                txt_on = 1'b1;
                red = 16'h0000;
                green = 16'h0000;
                blue = 16'h0000;
        end else begin
                txt_on = 1'b0;
        end

   ///////////// Draw Player Name in Lines Below /////////////
   
   end else if (DrawX >= x_pname && DrawX < (x_pname + (width * $size(p_name))) 
    && DrawY >= y_pname && DrawY < y_pname + height) begin
        current_char = p_name[(DrawX - x_pname) / 8];
        start_address = current_char * 16;
        rom_address = start_address + (DrawY - y_pname);
        color_idx = p_color;
        if (row_data[7 - ((DrawX - x_pname) % 8)] == 1'b1 && current_char !=0) begin
                txt_on = 1'b1;
                red = p_red;
                green = p_green;
                blue = p_blue;
        end else begin
                txt_on = 1'b0;
        end
  
   end else begin
       txt_on = 1'b0;
   end // End of IF
   
   ///////////// Draw Territory Data in Lines Below /////////////
 if (setup == 1'b0 && txt_on == 1'b0 && !vic_on) begin
   for (int i = 0; i < 42; i++) begin // $size(territories)
           x_territory = territories[i][18:9];
           y_territory = territories[i][27:19];
           number = territories[i][34:28]; // How many troops on territory.
           if (DrawX >= x_territory && DrawX < (x_territory + width) 
           && DrawY >= y_territory && DrawY < y_territory + height) begin
               current_char_t = territories[i][6:0];
               start_address_t = current_char_t * 16;
               rom_address_t = start_address_t + (DrawY - y_territory);
               color_idx = territories[i][8:7];
               if (row_data_t[7 - ((DrawX - x_territory) % 8)] == 1'b1 && current_char_t !=0) begin
                    t_on = 1'b1;
                    red_t = p_red;
                    green_t = p_green;
                    blue_t = p_blue;
                    break;
               end else begin
                   t_on = 1'b0;
               end
           end else if (number <= 9 && DrawX >= (x_territory + width) && DrawX < (x_territory + (2 * width)) 
           && DrawY >= y_territory && DrawY < y_territory + height) begin // Checking if number is single digit
               current_char_t = number + 48; // Index for number in font_rom
               start_address_t = current_char_t * 16;
               rom_address_t = start_address_t + (DrawY - y_territory);
               color_idx = territories[i][8:7];
               if (row_data_t[7 - ((DrawX - x_territory) % 8)] == 1'b1 && current_char_t !=0) begin
                    t_on = 1'b1;
                    red_t = p_red;
                    green_t = p_green;
                    blue_t = p_blue;
                    break;
               end else begin
                   t_on = 1'b0;
               end
//           end else if (number <= 99 && number >= 10 && DrawX >= x_territory + width && DrawX < (x_territory + (3 * width)) // Not Working rn figure out why later!!!
//           && DrawY >= y_territory && DrawY < y_territory + height) begin // Checking if number is two digits
//               numbers[0] = (number / 10) + 48;
//               numbers[1] = (number % 10) + 48;
//               color_idx = territories[i][8:7];
//               if (DrawX < (x_territory + 2*width)) begin // Check which digit should be drawn currently
//                   start_address_t = numbers[0] * 16;
//               end else begin // Check which digit should be drawn currently
//                   start_address_t = numbers[1] * 16;
//               end
//               rom_address_t = start_address_t + (DrawY - y_territory);
//               if (row_data_t[7 - ((DrawX - x_territory) % 8)] == 1'b1 && current_char_t !=0) begin
//                    t_on = 1'b1;
//                    red_t = p_red;
//                    green_t = p_green;
//                    blue_t = p_blue;
//                    break;
//               end else begin
//                   color_idx = p_color;
//                   t_on = 1'b0;
//               end
               
           end else begin // Means number is 3 digits or invalid. Need to complete later
               t_on = 1'b0;
           end
           
  end // END of FOR for looping through territories
 end // END of IF for checking if in setup mode or not
end // of Always_comb
    
    font_rom font_inst (
    .addr(rom_address), // Rom address
    .data(row_data)     //returns the pixel data for the current row of a character
    );
    
    font_rom font_inst2 (
    .addr(rom_address_t), // Rom address
    .data(row_data_t)     //returns the pixel data for the current row of a character
    );
    
    player_colors_palette player_colors_palette (
	.index (color_idx),
	.red   (p_red),
	.green (p_green),
	.blue  (p_blue)
    );
    
endmodule
