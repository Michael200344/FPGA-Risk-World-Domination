module mb_usb_hdmi_top(
    input logic Clk,
    input logic reset_rtl_0,
    
    //USB signals
    input logic [0:0] gpio_usb_int_tri_i,
    output logic gpio_usb_rst_tri_o,
    input logic usb_spi_miso,
    output logic usb_spi_mosi,
    output logic usb_spi_sclk,
    output logic usb_spi_ss,
    
    //UART
    input logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,
    
    //HDMI
    output logic hdmi_tmds_clk_n,
    output logic hdmi_tmds_clk_p,
    output logic [2:0]hdmi_tmds_data_n,
    output logic [2:0]hdmi_tmds_data_p,
        
    //HEX displays
    output logic [7:0] hex_segA,
    output logic [3:0] hex_gridA,
    output logic [7:0] hex_segB,
    output logic [3:0] hex_gridB
    );
    
    logic [31:0] keycode0_gpio, keycode1_gpio;
    logic clk_25MHz, clk_125MHz, clk, clk_100MHz;
    logic locked;
    logic [9:0] drawX, drawY;

    logic hsync, vsync, vde;
    logic [3:0] red, green, blue, r_menu, g_menu, b_menu, r_map, g_map, b_map, r_any, g_any, b_any;
    logic [3:0] r_txt, g_txt, b_txt, red_t, green_t, blue_t;
    logic reset_ah;
    logic menu, setup;
    logic press_any_on, txt_on, t_on;
    int troops_chars [0:19], player_input [0:30];
    int p_name [0:7];
    logic [1:0] p_color;
    logic [70:0] territories [42];
    int t_selected, t_attack, t_defend;
    logic battle_calc_flag;
    int done_flag = 0;
    int rand_idx;
    int hardcoded_colors [41:0] = {1, 2, 0, 1, 2, 0, 0, 1, 2, 1, 1, 0, 2, 2, 2, 1, 0, 2, 0, 1, 0, 1, 2, 0, 1, 2, 0, 0, 1, 2, 1, 1, 0, 2, 2, 2, 1, 0, 2, 0, 1, 0};
    
    int p1_territory_cnt, p2_territory_cnt, p3_territory_cnt;
    logic p1_color, p2_color, p3_color;
    int p_lost_idx = 4;
    int p_won_idx = 4;
    logic victory_flag = 0;
    int victory_txt [0:7];
    logic vic = 1'b0;
    logic demo;
    
    assign reset_ah = reset_rtl_0;
    
    always_ff @ (posedge clk_125MHz) begin
        if (reset_ah)
            done_flag <= 0;
        if (done_flag == 0) begin // Setup of territories
        //////// Sets the unique characters for all 42 territories ////////
            for (int i = 0; i < 42; i++) begin // Loop through all territories $size(territories)
                if (i < 29) // 26 letters + 3 more characters after in ROM
                    territories[i][6:0] <= 65 + i;
                else if (i < 33)
                    territories[i][6:0] <= i - 5; // Arrow keys
                else if (i == 33)
                    territories[i][6:0] <= i + 1; // "
                else if (i == 34)
                    territories[i][6:0] <= i - 2; // Spacebar
                else if (i < 39)
                    territories[i][6:0] <= i + 9; // , - . /
                else if (i == 39)
                    territories[i][6:0] <= i + 20; // ;
                else if (i == 40)
                    territories[i][6:0] <= i + 21; // =
                else
                    territories[i][6:0] <= i + 85; // ~
                    
                //////// Sets troop count of all territories to be 1 initially ////////
                
                territories[i][34:28] <= 1;
                 
                //////// Sets the starting colors for all territories ////////
                
                //rand_idx = lfsr % 2; // Would have used to generate random color index but wasn't working
                rand_idx = hardcoded_colors[i];
                if (rand_idx == 0) begin
                    territories[i][8:7] <= 0; // red
                end else if (rand_idx == 1) begin
                    territories[i][8:7] <= 1; // green
                end else if (rand_idx == 2) begin
                    territories[i][8:7] <= 2; // orange    
                end else
                    territories[i][8:7] <= 3; // If something goes wrong color will turn black
                  
            end // For loop
            done_flag <= 1;
         end else if (done_flag == 1) begin
            // Below I assign the drawX and drawY coordinates for each territory
            // Where x and y are the starting position of the characters on it.
            // characters include # of troops and unique character
            // DrawY is measured/.625 * 400
            // DrawX is measured/.625
            
//          A 31,3,1
//          Draw X and Y coordinates first, then adjacent territories
            territories[0][18:9] <= 43;
            territories[0][27:19] <= 64;
            
            territories[0][40:35] <= 31; // right arrow
            territories[0][46:41] <= 3; // D
            territories[0][52:47] <= 1; // B
            territories[0][70:53] <= 42; // No more adjacent territories
            
            
            // B
            territories[1][18:9] <= 96;
            territories[1][27:19] <= 58;
            
            territories[1][40:35] <= 0; // A
            territories[1][46:41] <= 3; // D
            territories[1][52:47] <= 4; // E
            territories[1][58:53] <= 2; // C
            territories[1][70:59] <= 42; // No more adjacent territories
            
            // C
            territories[2][18:9] <= 215;
            territories[2][27:19] <= 38;
            
            territories[2][40:35] <= 13; // N
            territories[2][46:41] <= 1; // B
            territories[2][52:47] <= 5; // F
            territories[2][70:53] <= 42; // No more adjacent territories
            
            // D
            territories[3][18:9] <= 86;
            territories[3][27:19] <= 95;
            
            territories[3][40:35] <= 0; // A
            territories[3][46:41] <= 1; // B
            territories[3][52:47] <= 4; // E
            territories[3][58:53] <= 6; // G
            territories[3][70:59] <= 42; // No more adjacent territories
            
            // E
            territories[4][18:9] = 125;
            territories[4][27:19] = 105;
            
            territories[4][40:35] <= 1; // B
            territories[4][46:41] <= 3; // D
            territories[4][52:47] <= 5; // F
            territories[4][58:53] <= 6; // G
            territories[4][64:59] <= 7; // H
            territories[4][70:65] <= 42; // No more adjacent territories
            
            // F
            territories[5][18:9] <= 170;
            territories[5][27:19] <= 105;
            
            territories[5][40:35] <= 2; // C
            territories[5][46:41] <= 7; // H
            territories[5][52:47] <= 4; // E
            territories[5][70:53] <= 42; // No more adjacent territories
            
            // G
            territories[6][18:9] <= 80;
            territories[6][27:19] <= 145;
            
            territories[6][40:35] <= 3; // D
            territories[6][46:41] <= 8; // I
            territories[6][52:47] <= 4; // E
            territories[6][58:53] <= 7; // H
            territories[6][70:59] <= 42; // No more adjacent territories
            
            // H
            territories[7][18:9] <= 135;
            territories[7][27:19] <= 155;
            
            territories[7][40:35] <= 5; // F
            territories[7][46:41] <= 8; // I
            territories[7][52:47] <= 4; // E
            territories[7][58:53] <= 6; // G
            territories[7][70:59] <= 42; // No more adjacent territories
            
            // I
            territories[8][18:9] <= 90;
            territories[8][27:19] <= 205;
            
            territories[8][40:35] <= 9; // J
            territories[8][46:41] <= 7; // H
            territories[8][52:47] <= 6; // G
            territories[8][70:53] <= 42; // No more adjacent territories
            
            // J
            territories[9][18:9] <= 120;
            territories[9][27:19] <= 245;
            
            territories[9][40:35] <= 11; // L
            territories[9][46:41] <= 10; // K
            territories[9][52:47] <= 8; // I
            territories[9][70:53] <= 42; // No more adjacent territories

            // K
            territories[10][18:9] <= 140;
            territories[10][27:19] <= 315;
            
            territories[10][40:35] <= 9; // J
            territories[10][46:41] <= 11; // L
            territories[10][52:47] <= 12; // M
            territories[10][70:53] <= 42; // No more adjacent territories

            // L
            territories[11][18:9] <= 168;
            territories[11][27:19] <= 295;
            
            territories[11][40:35] <= 10; // K
            territories[11][46:41] <= 12; // M
            territories[11][52:47] <= 9; // J
            territories[11][58:53] <= 20; // U
            territories[11][70:59] <= 42; // No more adjacent territories

            // M
            territories[12][18:9] <= 128;
            territories[12][27:19] <= 360;
            
            territories[12][40:35] <= 10; // K
            territories[12][46:41] <= 11; // L
            territories[12][70:47] <= 42; // No more adjacent territories

            // N
            territories[13][18:9] <= 270;
            territories[13][27:19] <= 72;
            
            territories[13][40:35] <= 2; // C
            territories[13][46:41] <= 15; // P
            territories[13][52:47] <= 14; // O
            territories[13][70:53] <= 42; // No more adjacent territories

            // O
            territories[14][18:9] <= 250;
            territories[14][27:19] <= 130;
            
            territories[14][40:35] <= 13; // N
            territories[14][46:41] <= 15; // P
            territories[14][52:47] <= 16; // Q
            territories[14][58:53] <= 17; // R
            territories[14][70:59] <= 42; // No more adjacent territories

            // P
            territories[15][18:9] <= 310;
            territories[15][27:19] <= 90;
            
            territories[15][40:35] <= 13; // N
            territories[15][46:41] <= 14; // O
            territories[15][52:47] <= 16; // Q
            territories[15][58:53] <= 19; // T
            territories[15][70:59] <= 42; // No more adjacent territories
    
            // Q
            territories[16][18:9] <= 305;
            territories[16][27:19] <= 135;
            
            territories[16][40:35] <= 14; // O
            territories[16][46:41] <= 15; // P
            territories[16][52:47] <= 19; // T
            territories[16][58:53] <= 18; // S
            territories[16][64:59] <= 17; // R
            territories[16][70:65] <= 42; // No more adjacent territories

            // R
            territories[17][18:9] <= 260;
            territories[17][27:19] <= 195;
            
            territories[17][40:35] <= 14; // O
            territories[17][46:41] <= 16; // Q
            territories[17][52:47] <= 18; // S
            territories[17][58:53] <= 20; // U
            territories[17][70:59] <= 42; // No more adjacent territories
            
            done_flag <= 2;
            
        end else if (done_flag == 2) begin
            // S
            territories[18][18:9] <= 320;
            territories[18][27:19] <= 190;
            
            territories[18][40:35] <= 21; // V
            territories[18][46:41] <= 16; // Q
            territories[18][52:47] <= 17; // R
            territories[18][58:53] <= 19; // T
            territories[18][64:59] <= 26; // [
            territories[18][70:65] <= 42; // No more adjacent territories

            // T
            territories[19][18:9] <= 360;
            territories[19][27:19] <= 110;
            
            territories[19][40:35] <= 15; // P
            territories[19][46:41] <= 16; // Q
            territories[19][52:47] <= 18; // S
            territories[19][58:53] <= 28; // ]
            territories[19][64:59] <= 26; // [
            territories[19][70:65] <= 27; // \

            // U
            territories[20][18:9] <= 280;
            territories[20][27:19] <= 270;
            
            territories[20][40:35] <= 21; // V
            territories[20][46:41] <= 11; // L
            territories[20][52:47] <= 17; // R
            territories[20][58:53] <= 22; // W
            territories[20][64:59] <= 23; // X
            territories[20][70:65] <= 42; // No more adjacent territories

            // V
            territories[21][18:9] <= 335;
            territories[21][27:19] <= 250;
            
            territories[21][40:35] <= 18; // S
            territories[21][46:41] <= 20; // U
            territories[21][52:47] <= 22; // W
            territories[21][58:53] <= 26; // [
            territories[21][70:59] <= 42; // No more adjacent territories

            // W
            territories[22][18:9] <= 360;
            territories[22][27:19] <= 295;
            
            territories[22][40:35] <= 21; // V
            territories[22][46:41] <= 20; // U
            territories[22][52:47] <= 23; // X
            territories[22][58:53] <= 24; // Y
            territories[22][64:59] <= 25; // Z
            territories[22][70:65] <= 26; // [

            // X
            territories[23][18:9] <= 325;
            territories[23][27:19] <= 340;
            
            territories[23][40:35] <= 25; // Z
            territories[23][46:41] <= 20; // U
            territories[23][52:47] <= 22; // W
            territories[23][58:53] <= 24; // Y
            territories[23][70:59] <= 42; // No more adjacent territories

            // Y
            territories[24][18:9] <= 325;
            territories[24][27:19] <= 398;
            
            territories[24][40:35] <= 25; // Z
            territories[24][46:41] <= 23; // X
            territories[24][52:47] <= 22; // W
            territories[24][70:53] <= 42; // No more adjacent territories

            // Z
            territories[25][18:9] <= 398;
            territories[25][27:19] <= 395;
            
            territories[25][40:35] <= 22; // W
            territories[25][46:41] <= 24; // Y
            territories[25][70:47] <= 42; // No more adjacent territories

            // [
            territories[26][18:9] <= 378;
            territories[26][27:19] <= 230;
            
            territories[26][40:35] <= 18; // S
            territories[26][46:41] <= 21; // V
            territories[26][52:47] <= 22; // W
            territories[26][58:53] <= 35; // ,
            territories[26][64:59] <= 27; // \
            territories[26][70:65] <= 19; // T

            // \
            territories[27][18:9] <= 412;
            territories[27][27:19] <= 152;
            
            territories[27][40:35] <= 26; // [
            territories[27][46:41] <= 28; // ]
            territories[27][52:47] <= 19; // T
            territories[27][58:53] <= 35; // ,
            territories[27][64:59] <= 34; // spacebar
            territories[27][70:65] <= 42; // No more adjacent territories
            
            
            // ]
            territories[28][18:9] <= 425;
            territories[28][27:19] <= 95;
            
            territories[28][40:35] <= 29; // up arrow
            territories[28][46:41] <= 27; // \
            territories[28][52:47] <= 19; // T
            territories[28][58:53] <= 34; // spacebar
            territories[28][70:59] <= 42; // No more adjacent territories
 
            // up arrow
            territories[29][18:9] <= 455;
            territories[29][27:19] <= 75;
            
            territories[29][40:35] <= 32; // left arrow
            territories[29][46:41] <= 30; // down arrow
            territories[29][52:47] <= 33; // "
            territories[29][58:53] <= 34; // spacebar
            territories[29][64:59] <= 28; // ]
            territories[29][70:65] <= 42; // No more adjacent territories
            

            // down arrow
            territories[30][18:9] <= 495;
            territories[30][27:19] <= 58;
            
            territories[30][40:35] <= 29; // up arrow
            territories[30][46:41] <= 32; // left arrow
            territories[30][52:47] <= 31; // right arrow
            territories[30][70:53] <= 42; // No more adjacent territories
            
            // right arrow
            territories[31][18:9] <= 550;
            territories[31][27:19] <= 58;
            
            territories[31][40:35] <= 30; // down arrow
            territories[31][46:41] <= 32; // left arrow
            territories[31][52:47] <= 33; // "
            territories[31][58:53] <= 37; // .
            territories[31][64:59] <= 0; // A
            territories[31][70:65] <= 42; // No more adjacent territories

            // left arrow
            territories[32][18:9] <= 500;
            territories[32][27:19] <= 100;
            
            territories[32][40:35] <= 30; // down arrow
            territories[32][46:41] <= 29; // up arrow
            territories[32][52:47] <= 31; // right arrow
            territories[32][58:53] <= 33; // "
            territories[32][70:59] <= 42; // No more adjacent territories

            // "
            territories[33][18:9] <= 500;
            territories[33][27:19] <= 150;
            
            territories[33][40:35] <= 34; // spacebar
            territories[33][46:41] <= 29; // up arrow
            territories[33][52:47] <= 31; // right arrow
            territories[33][58:53] <= 32; // left arrow
            territories[33][64:59] <= 37; // .
            territories[33][70:65] <= 42; // No more adjacent territories

            // spacebar
            territories[34][18:9] <= 480;
            territories[34][27:19] <= 180;
            
            territories[34][40:35] <= 36; // -
            territories[34][46:41] <= 35; // ,
            territories[34][52:47] <= 27; // \
            territories[34][58:53] <= 33; // "
            territories[34][64:59] <= 26; // [
            territories[34][70:65] <= 29; // up arrow

            // ,
            territories[35][18:9] <= 450;
            territories[35][27:19] <= 220;
            
            territories[35][40:35] <= 34; // spacebar
            territories[35][46:41] <= 26; // [
            territories[35][52:47] <= 36; // -
            territories[35][58:53] <= 27; // \
            territories[35][70:59] <= 42; // No more adjacent territories

            // -
            territories[36][18:9] <= 500;
            territories[36][27:19] <= 250;
            
            territories[36][40:35] <= 34; // spacebar
            territories[36][46:41] <= 35; // ,
            territories[36][52:47] <= 38; // /
            territories[36][70:53] <= 42; // No more adjacent territories
            
            // .
            territories[37][18:9] <= 575;
            territories[37][27:19] <= 130;
            
            territories[37][40:35] <= 33; // "
            territories[37][46:41] <= 31; // right arrow
            territories[37][70:47] <= 42; // No more adjacent territories

            // /
            territories[38][18:9] <= 510;
            territories[38][27:19] <= 332;
            
            territories[38][40:35] <= 39; // ;
            territories[38][46:41] <= 41; // ~
            territories[38][52:47] <= 36; // -
            territories[38][70:53] <= 42; // No more adjacent territories

            // ;
            territories[39][18:9] <= 575;
            territories[39][27:19] <= 315;
            
            territories[39][40:35] <= 40; // =
            territories[39][46:41] <= 41; // ~
            territories[39][52:47] <= 38; // /
            territories[39][70:53] <= 42; // No more adjacent territories

            // =
            territories[40][18:9] <= 588;
            territories[40][27:19] <= 390;
            
            territories[40][40:35] <= 39; // ;
            territories[40][46:41] <= 41; // ~
            territories[40][70:47] <= 42; // No more adjacent territories

            // ~
            territories[41][18:9] <= 530;
            territories[41][27:19] <= 415;
            
            territories[41][40:35] <= 40; // =
            territories[41][46:41] <= 39; // ;
            territories[41][52:47] <= 38; // /
            territories[41][70:53] <= 42; // No more adjacent territories
            
            done_flag <= 3;
            
            end else if (demo) begin
                for (int i = 0; i < $size(territories); i++) begin // Loop through every territory
                    if (i == 24)
                        territories[i][8:7] = 1;
                    else
                        territories[i][8:7] = 0;
                end
                territories[23][34:28] <= 4;
            
            end else if (setup == 1'b0) begin // Updating the territories when needed
                if (t_selected != 42) begin
                    territories[t_selected][34:28] = territories[t_selected][34:28] + 1;
                end else if (battle_calc_flag == 1'b1) begin // If territories need to be updated because of a battle
                    if (territories[t_attack][34:28] > territories[t_defend][34:28]) begin // If attacker has more troops
                        
                        // Change color of defeated territory to attacker's color.
                        territories[t_defend][8:7] = territories[t_attack][8:7];
                    
                        // Change the number of troops on the defeated territory
                        territories[t_defend][34:28] = territories[t_attack][34:28] - territories[t_defend][34:28];
                    
                        // Change the number of troops on the victorious attacking territory
                        territories[t_attack][34:28] = 1;

                    end else begin // Currently this is very wrong and needs to be fixed for calculating casualties and who wins, etc.
                    
                        // Defending territory loses equal amount of troops as the attacker
                        territories[t_defend][34:28] = territories[t_defend][34:28] - (territories[t_attack][34:28] - 1);
                    
                        // Attacking territory loses all but 1 troop
                        territories[t_attack][34:28] = 1;
                    
                    end
                end
           end
    end
    

    
    always_ff @ (posedge Clk) check_winlose: begin
        if (setup == 0) begin
        p1_territory_cnt = 0; 
        p2_territory_cnt = 0;
        p3_territory_cnt = 0;
        for (int i = 0; i < $size(territories); i++) begin // Loop through every territory
            // Need to keep track of the number of territories owned by each person
            // If all territories are the same color at any point in time, that color has won - send win signal to FSM
            // If any player has no territories left, send the losing color to the FSM
            if (territories[i][8:7] == p1_color)
                p1_territory_cnt++;
            else if (territories[i][8:7] == p2_color)
                p2_territory_cnt++;
            else if (territories[i][8:7] == p3_color)
                p3_territory_cnt++;
        end // End of for loop
        
        // Checking the win conditions for each player
        if (p1_territory_cnt == 42)
            p_won_idx = 1;
        else if (p2_territory_cnt == 42)
            p_won_idx = 2;
        else if (p3_territory_cnt == 42)
            p_won_idx = 3;
        
        // Checking the loss conditions for each player
        if (p1_territory_cnt == 0)
            p_lost_idx = 1;
        else if (p2_territory_cnt == 0)
            p_lost_idx = 2;
        else if (p3_territory_cnt == 0)
            p_lost_idx = 3;
        
        if (p_won_idx != 4)
            victory_flag = 1;
        end // End of If setup == 0
    end
    
    
    //Keycode HEX drivers
    HexDriver HexA (
        .clk(Clk),
        .reset(reset_ah),
        .in({keycode0_gpio[31:28], keycode0_gpio[27:24], keycode0_gpio[23:20], keycode0_gpio[19:16]}),
        .hex_seg(hex_segA),
        .hex_grid(hex_gridA)
    );
    
    HexDriver HexB (
        .clk(Clk),
        .reset(reset_ah),
        .in({keycode0_gpio[15:12], keycode0_gpio[11:8], keycode0_gpio[7:4], keycode0_gpio[3:0]}),
        .hex_seg(hex_segB),
        .hex_grid(hex_gridB)
    );
    
    lab6_1_block mb_block_i(
        .clk_100MHz(Clk),
        .gpio_usb_int_tri_i(gpio_usb_int_tri_i),
        .gpio_usb_keycode_0_tri_o(keycode0_gpio),
        .gpio_usb_keycode_1_tri_o(keycode1_gpio),
        .gpio_usb_rst_tri_o(gpio_usb_rst_tri_o),
        .reset_rtl_0(~reset_ah), //Block designs expect active low reset, all other modules are active high
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),
        .usb_spi_miso(usb_spi_miso),
        .usb_spi_mosi(usb_spi_mosi),
        .usb_spi_sclk(usb_spi_sclk),
        .usb_spi_ss(usb_spi_ss)
    );
        
    //clock wizard configured with a 1x and 5x clock for HDMI
    clk_wiz_0 clk_wiz (
        .clk_out1(clk_25MHz),
        .clk_out2(clk_125MHz),
        .reset(reset_ah),
        .locked(locked),
        .clk_in1(Clk)
    );
    
    //VGA Sync signal generator
    vga_controller vga (
        .pixel_clk(clk_25MHz),
        .reset(reset_ah),
        .hs(hsync),
        .vs(vsync),
        .active_nblank(vde),
        .drawX(drawX),
        .drawY(drawY)
    );    

    //Real Digital VGA to HDMI converter
    hdmi_tx_0 vga_to_hdmi (
        //Clocking and Reset
        .pix_clk(clk_25MHz),
        .pix_clkx5(clk_125MHz),
        .pix_clk_locked(locked),
        //Reset is active LOW
        .rst(reset_ah),
        //Color and Sync Signals
        .red(red),
        .green(green),
        .blue(blue),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        
        //aux Data (unused)
        .aux0_din(4'b0),
        .aux1_din(4'b0),
        .aux2_din(4'b0),
        .ade(1'b0),
        
        //Differential outputs
        .TMDS_CLK_P(hdmi_tmds_clk_p),          
        .TMDS_CLK_N(hdmi_tmds_clk_n),          
        .TMDS_DATA_P(hdmi_tmds_data_p),         
        .TMDS_DATA_N(hdmi_tmds_data_n)          
    );

always_comb draw_background:
begin  
    if (vic) begin
        red = r_txt;
        blue = b_txt;
        green = g_txt;
    end else if (menu && press_any_on) begin
        red = r_any;
        blue = b_any;
        green = g_any;
    end else if (menu) begin
        red = r_menu;
        blue = b_menu;
        green = g_menu;
    end else if (t_on) begin // territories text
        red = red_t;
        blue = blue_t;
        green = green_t;
    end else if (txt_on) begin
        red = r_txt;
        blue = b_txt;
        green = g_txt;
    end else begin
        red = r_map;
        blue = b_map;
        green = g_map;
    end
end

//  risk_classic_map_2_example map_instance1(
//    .vga_clk(clk_25MHz),
//    .DrawX(drawX),
//    .DrawY(drawY),
//    .blank(vde),
//    .red(r_map),
//    .green(g_map),
//    .blue(b_map)
//);

classic_example map_inst(
    .vga_clk(clk_25MHz),
    .DrawX(drawX),
    .DrawY(drawY),
    .blank(vde),
    .red(r_map),
    .green(g_map),
    .blue(b_map)
);

menu_example menu_inst(
    .vga_clk(clk_25MHz),
    .DrawX(drawX),
    .DrawY(drawY),
    .blank(vde),
    .red(r_menu),
    .green(g_menu),
    .blue(b_menu)
); 

press_start_example press_any_key_text (
    .vga_clk(clk_25MHz),
    .DrawX(drawX),
    .DrawY(drawY),
    .blank(vde),
    .red(r_any),
    .green(g_any),
    .blue(b_any),
    .on(press_any_on)
);
    
ISDU fsm_inst (
    .Clk(clk_125MHz),
    .Reset(reset_ah),
    .Keycodes(keycode0_gpio),
    .menu_bit(menu),
    .setup(setup),
    .troops_chars(troops_chars),
    .player_input(player_input),
    .p_name(p_name),
    .p_color(p_color),
    .territories(territories),
    .t_selected(t_selected),
    .t_attack(t_attack),
    .t_defend(t_defend),
    .battle_calc_flag(battle_calc_flag),
    .p1_color(p1_color),
    .p2_color(p2_color),
    .p3_color(p3_color),
    .victory_flag(victory_flag),
    .victory_txt(victory_txt),
    .vic(vic),
    .demo_bit(demo)
);

text_mapper draw_text (
    .vga_clk(Clk),
    .DrawX(drawX),
    .DrawY(drawY),
    .blank(vde),
    .troops_chars(troops_chars),
    .player_input(player_input),
    .p_name(p_name),
    .p_color(p_color),
    .territories(territories),
    .red(r_txt),
    .green(g_txt),
    .blue(b_txt),
    .red_t(red_t),
    .green_t(green_t),
    .blue_t(blue_t),
    .txt_on(txt_on),
    .t_on(t_on),
    .setup(setup),
    .vic_on(vic),
    .victory_txt(victory_txt)
);
    
endmodule
