module ISDU(
    input logic Clk, Reset, 
    input logic[31:0] Keycodes,
	output logic menu_bit, setup,
	output int troops_chars [0:19], player_input [0:30],
	output int p_name [7:0], victory_txt [7:0],
	output logic [1:0] p_color,
	input logic [70:0] territories [42],
	output int t_attack, t_defend, t_selected,
	output logic battle_calc_flag,
	output logic [1:0] p1_color, p2_color, p3_color,
	input logic victory_flag,
	output logic vic,
	output logic demo_bit
);

	enum logic [6:0] {menu, player_1_name, player_1_color, 
	player_2_name, player_2_color, player_3_name, 
	player_3_color, player_1_draft, player_1_attack, player_2_draft, player_2_attack, player_3_draft, player_3_attack, wait_for_selection_1,
	deploy_troop_1, wait_for_selection_2, deploy_troop_2, wait_for_selection_3, deploy_troop_3, waiting_for_attacker_1, waiting_for_defender_1,
	battle_calculation, waiting_for_attacker_2, waiting_for_defender_2, waiting_for_attacker_3, waiting_for_defender_3, victory
	, battle_calculation_2, battle_calculation_3, demo} curr, next;   // Internal state logic
	
	// Player name information
	int p1_name [0:7], p2_name [0:7], p3_name [0:7]; // Int corresponds to IBM code page 437
	int player1_name_len = 0, player2_name_len = 0, player3_name_len = 0;
	
	
	logic [31:0] prev_keycodes;
	
	int troops_count [0:2];
	int territory_idx, territory_idx2, territory_idx3;
	
	int casualties;
	
	// For randomizing turn order using shuffle algorithm in menu state.
	int turn_order [0:2];
	int temp, rand_idx;
	int idx = 0;
	
	// HOW TERRITORIES ARE STRUCTURED
	// Defines 42 71-bit registers to store territory information
    // bits 0-6 = character
    // bits 7-8 = color
    // bits 9-18 = drawX starting position
    // bits 19-27 = drawY starting position
    // bits 28-34 = troop count                      
    // bits 35-70 = adjacent territories, where they are divided by 6 like:
    // 35-40 = 1, 41-46 = 2, 47-52 = 3, 53-58 = 4, 59-64 = 5, 65-70 = 6
	
		
		
    ff_prev_keypress ff_prev_keypress (
    .reset(Reset),
    .D(Keycodes),
    .Q(prev_keycodes),
    .clk(Clk)
    );
    

	always_ff @ (posedge Clk)
	begin
		if (Reset)
			curr <= menu;
        else if (victory_flag)
            curr <= victory;
		else 
		    curr <= next;
	end
   
   
	always_ff @ (posedge Clk)
	begin 
		
		// Default next state is staying at current state
		next = curr;
		
		// Default controls signal values
		menu_bit = 1'b1;
		setup = 1'b1;
		player_input = '{31{0}};
		troops_chars = '{84, 82, 79, 79, 80, 83, 58, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Troops:
		t_selected = 42;
		turn_order = '{1, 2, 3};
		battle_calc_flag = 1'b0;
		vic = 0;
		demo_bit <= 0;

        
        
		// Assign next state
		unique case (curr)
			menu :
			   case (Keycodes)
			     16'h0000:
			         next <= menu;
			     default:
			         next <= player_1_name;
			   endcase
		      
		    player_1_name :
		       case (Keycodes)
		          16'h0028:
		              if (player1_name_len > 0) begin // Makes sure player has typed name before pressing enter
		                 next <= player_1_color; // Go to color picking segment
		             end else begin
		                 next <= player_1_name;
		             end
		          default:
		              next <= player_1_name;
		          endcase
			   
			player_1_color :
		       case (p1_color)
		         2'b11: // If color not picked yet
		             next <= player_1_color; // Stay until player picks color
		         default:
		             next <= player_2_name; // Otherwise, player has picked color, move on to player 2.
			   endcase
			
		     player_2_name :
		       case (Keycodes)
		          16'h0028:
		              if (player2_name_len > 0) begin // Makes sure player has typed name before pressing enter
		                 next <= player_2_color; // Go to color picking segment
		             end else begin
		                 next <= player_2_name;
		             end
		          default:
		              next <= player_2_name;
		          endcase
		          
		     player_2_color :
		       case (p2_color)
		         2'b11: // If color not picked yet
		             next <= player_2_color; // Stay until player picks color
		         default:
		             next <= player_3_name;
			   endcase
			   
			 player_3_name :
		       case (Keycodes)
		          16'h0028:
		              if (player3_name_len > 0) begin // Makes sure player has typed name before pressing enter
		                 next <= player_3_color; // Go to color picking segment
		             end else begin
		                 next <= player_3_name;
		             end
		          default:
		              next <= player_3_name;
		          endcase
		          
		     player_3_color :
		       case (turn_order[0])
		              1:
		                  if (p3_color != 2'b11)
		                      next <= player_1_draft;
		                  else 
		                      next <= player_3_color;
		              2:
		                  if (p3_color != 2'b11)
		                      next <= player_2_draft;
		                  else
		                      next <= player_3_color;
		              3:
		                  if (p3_color != 2'b11)
		                      next <= player_3_draft;
		                  else
		                      next <= player_3_color;
		              default:
		                  next <= player_3_color;
		       endcase
		       
		    player_1_draft : // troops distribution
		       next <= wait_for_selection_1;
		       
		    wait_for_selection_1 :
		      if (troops_count[0] == 0) // Draft phase is done, move to attack phase
		          next <= waiting_for_attacker_1;
		      else if (Keycodes == 16'h0028 && prev_keycodes != Keycodes && territory_idx != 42) // Valid territory Selected
		          next <= deploy_troop_1;
		      else if (Keycodes == 16'h0065 && prev_keycodes != Keycodes) begin
		          next <= demo;
		      end else // Otherwise stay waiting for a territory selection
		          next <= wait_for_selection_1;
              

		     deploy_troop_1 : // Used to decrement troop count and update count for territory
		      next <= wait_for_selection_1;
//		      case (troops_count[0])
//		          1 :
//		              next = player_1_attack; // Change
//		          default :
//		              if (troops_count[0] <= 1) // Shouldn't need to check but for some reason I do.
//		                  next = player_1_attack; // Change
//		              else
//		                  next = wait_for_selection_1;
		      
//		      endcase
		      
		      
		     waiting_for_attacker_1 :
                case (Keycodes)
		          16'h0028 :
		              if (t_attack != 42 && prev_keycodes != 16'h0028) begin
		                  next <= waiting_for_defender_1;
		              end
		          default :
		              next <= waiting_for_attacker_1;
		          
		        endcase
		        
		        
		     waiting_for_defender_1 :
		         case (Keycodes)
		          16'h0028 :
		              if (t_defend != 42 && prev_keycodes != Keycodes)
		                  next <= battle_calculation;
		              else
		                  next <= waiting_for_defender_1;
		          default :
		              next <= waiting_for_defender_1;
		          
		        endcase
		        
		     battle_calculation :
		         if (Keycodes == 16'h0016 && prev_keycodes != Keycodes) begin // Stop has been selected, go to next draft phase
		          next <= player_2_draft;
		         end else if (Keycodes == 16'h0004 && prev_keycodes != Keycodes) begin // Player wants to attack more
		          next <= wait_for_selection_1;
		          t_attack <= 42;
		          t_defend <= 42;
		         end else
		          next <= battle_calculation;
                        
		          
//		    player_1_attack :
//		       if (Keycodes == 16'h0028 && prev_keycodes != Keycodes) begin
//		          next <= player_2_draft;
//		       end else
//		          next <= player_1_attack;
		          
////		       case (Keycodes)
////		          16'h0028: // Enter key pressed
////		              if (turn_order[2] == 1) begin
////		                  if (turn_order[0] == 2) begin
////		                      next = player_2_draft;
////		                  end else
////		                      next = player_3_draft;
////		              end else if (turn_order[1] == 1) begin
////		                  if (turn_order[2] == 2)
////		                      next = player_2_draft;
////		                  else
////		                      next = player_3_draft;
////		              end else begin
////		                  if (turn_order[1] == 2)
////		                      next = player_2_draft;
////		                  else
////		                      next = player_3_draft;
////		              end
////		          default:
////		              next = player_1_attack;
////		       endcase
		       
		       
		    
//		    player_2_draft :
//		       next <= wait_for_selection_2;
		          
		    
//		    wait_for_selection_2 :
//		      if (troops_count[1] == 0) // Draft phase is done, move to attack phase
//		          next <= player_2_attack;
//		      else if (Keycodes == 16'h0028 && prev_keycodes != Keycodes && territory_idx2 != 42) // Valid territory Selected
//		          next <= deploy_troop_2;
//		      else // Otherwise stay waiting for a territory selection
//		          next <= wait_for_selection_2;
		    
		    
//		    deploy_troop_2 : // Used to decrement troop count and update count for territory
//		      next <= wait_for_selection_2;
		    


//		    player_2_attack :
//		      if (Keycodes == 16'h0028 && prev_keycodes != Keycodes) begin
//		          next <= player_3_draft;
//		       end else
//		          next <= player_2_attack;
		 
////		       case (Keycodes)
////		          16'h0028: // Enter key pressed
////		              if (prev_keycodes == 16'h0028)
////		                  next = player_2_attack;    
////		              else if (turn_order[2] == 2) begin
////		                  if (turn_order[0] == 1) begin
////		                      next = player_1_draft;
////		                  end else
////		                      next = player_3_draft;
////		              end else if (turn_order[1] == 2) begin
////		                  if (turn_order[2] == 1)
////		                      next = player_1_draft;
////		                  else
////		                      next = player_3_draft;
////		              end else begin
////		                  if (turn_order[1] == 1)
////		                      next = player_1_draft;
////		                  else
////		                      next = player_3_draft;
////		              end
////		          default:
////		              next = player_2_attack;
////		       endcase
		       
		      
		      
		      player_2_draft : // troops distribution
		       next <= wait_for_selection_2;
		       
		    wait_for_selection_2 :
		      if (troops_count[1] == 0) // Draft phase is done, move to attack phase
		          next <= waiting_for_attacker_2;
		      else if (Keycodes == 16'h0028 && prev_keycodes != Keycodes && territory_idx2 != 42) // Valid territory Selected
		          next <= deploy_troop_2;
		      else // Otherwise stay waiting for a territory selection
		          next <= wait_for_selection_2;
              

		     deploy_troop_2 : // Used to decrement troop count and update count for territory
		      next <= wait_for_selection_2;
//		      case (troops_count[0])
//		          1 :
//		              next = player_1_attack; // Change
//		          default :
//		              if (troops_count[0] <= 1) // Shouldn't need to check but for some reason I do.
//		                  next = player_1_attack; // Change
//		              else
//		                  next = wait_for_selection_1;
		      
//		      endcase
		      
		      
		     waiting_for_attacker_2 :
                case (Keycodes)
		          16'h0028 :
		              if (t_attack != 42 && prev_keycodes != 16'h0028) begin
		                  next <= waiting_for_defender_2;
		              end
		          default :
		              next <= waiting_for_attacker_2;
		          
		        endcase
		        
		        
		     waiting_for_defender_2 :
		         case (Keycodes)
		          16'h0028 :
		              if (t_defend != 42 && prev_keycodes != Keycodes)
		                  next <= battle_calculation_2;
		              else
		                  next <= waiting_for_defender_2;
		          default :
		              next <= waiting_for_defender_2;
		          
		        endcase
		        
		     battle_calculation_2 :
		         if (Keycodes == 16'h0016 && prev_keycodes != Keycodes) begin // Stop has been selected, go to next draft phase
		          next <= player_3_draft;
		         end else if (Keycodes == 16'h0004 && prev_keycodes != Keycodes) begin // Player wants to attack more
		          next <= wait_for_selection_2;
		          t_attack <= 42;
		          t_defend <= 42;
		         end else
		          next <= battle_calculation_2;
		      
		      
		      

		       
//		    player_3_draft :
//		      next <= wait_for_selection_3;
		          
		          
//		    wait_for_selection_3 :
//		      if (troops_count[2] == 0) // Draft phase is done, move to attack phase
//		          next <= player_3_attack;
//		      else if (Keycodes == 16'h0028 && prev_keycodes != Keycodes && territory_idx3 != 42) // Valid territory Selected
//		          next <= deploy_troop_3;
//		      else // Otherwise stay waiting for a territory selection
//		          next <= wait_for_selection_3;
		    
		    
//		    deploy_troop_3 : // Used to decrement troop count and update count for territory
//		      next <= wait_for_selection_3;     
		          
		          
		          
//		    player_3_attack :
//                if (Keycodes == 16'h0028 && prev_keycodes != Keycodes) begin
//		          next <= player_1_draft;
//		       end else
//		          next <= player_3_attack;

////		      if (Keycodes == 16'h0028 && prev_keycodes != Keycodes) begin
////		          troops_count[0] = 4;
////		          territory_idx = 42;
////		          next = wait_for_selection_1;
////		      end


////		       case (Keycodes)
////		          16'h0028: // Enter key pressed  
////		              if (prev_keycodes == 16'h0028)
////		                  next = player_3_attack;  
////		              else if (turn_order[2] == 3) begin
////		                  if (turn_order[0] == 1) begin
////		                      next = player_1_draft;
////		                  end else
////		                      next = player_2_draft;
////		              end else if (turn_order[1] == 3) begin
////		                  if (turn_order[2] == 1)
////		                      next = player_1_draft;
////		                  else
////		                      next = player_2_draft;
////		              end else begin
////		                  if (turn_order[1] == 1)
////		                      next = player_1_draft;
////		                  else
////		                      next = player_2_draft;
////		              end
////		          default:
////		              next = player_3_attack;
////		       endcase   


            player_3_draft : // troops distribution
		       next <= wait_for_selection_3;
		       
		    wait_for_selection_3 :
		      if (troops_count[2] == 0) // Draft phase is done, move to attack phase
		          next <= waiting_for_attacker_3;
		      else if (Keycodes == 16'h0028 && prev_keycodes != Keycodes && territory_idx3 != 42) // Valid territory Selected
		          next <= deploy_troop_3;
		      else // Otherwise stay waiting for a territory selection
		          next <= wait_for_selection_3;
              

		     deploy_troop_2 : // Used to decrement troop count and update count for territory
		      next <= wait_for_selection_3;
//		      case (troops_count[0])
//		          1 :
//		              next = player_1_attack; // Change
//		          default :
//		              if (troops_count[0] <= 1) // Shouldn't need to check but for some reason I do.
//		                  next = player_1_attack; // Change
//		              else
//		                  next = wait_for_selection_1;
		      
//		      endcase
		      
		      
		     waiting_for_attacker_3 :
                case (Keycodes)
		          16'h0028 :
		              if (t_attack != 42 && prev_keycodes != 16'h0028) begin
		                  next <= waiting_for_defender_3;
		              end
		          default :
		              next <= waiting_for_attacker_3;
		          
		        endcase
		        
		        
		     waiting_for_defender_2 :
		         case (Keycodes)
		          16'h0028 :
		              if (t_defend != 42 && prev_keycodes != Keycodes)
		                  next <= battle_calculation_3;
		              else
		                  next <= waiting_for_defender_3;
		          default :
		              next <= waiting_for_defender_3;
		          
		        endcase
		        
		     battle_calculation_3 :
		         if (Keycodes == 16'h0016 && prev_keycodes != Keycodes) begin // Stop has been selected, go to next draft phase
		          next <= player_1_draft;
		         end else if (Keycodes == 16'h0004 && prev_keycodes != Keycodes) begin // Player wants to attack more
		          next <= wait_for_selection_3;
		          t_attack <= 42;
		          t_defend <= 42;
		         end else
		          next <= battle_calculation_3;


            demo :
                next <= waiting_for_attacker_1;
  
            
            
            victory :
                next <= victory;
            
                
			default :;
		endcase
		
		
		
		
		
		
		
		
		
		// Assign control signals based on current state
		case (curr)
			menu :
			begin
			     menu_bit = 1'b1;
			     
			     // Fisher-Yates shuffle algorithm
//                 for (int i = 2; i >= 0; i--) begin
//                    rand_idx = $urandom_range(0, i); // Random index from 0 to i
//                    temp = turn_order[i];
//                    turn_order[i] = turn_order[rand_idx];
//                    turn_order[rand_idx] = temp;
//                    end
			     
			     // Reset signals
			     p1_name = '{8{0}}; 
			     p2_name = '{8{0}};
			     p3_name = '{8{0}};
                 player1_name_len = 0;
                 player2_name_len = 0;
                 player3_name_len = 0;
                 p1_color = 2'b11;
                 p2_color = 2'b11;
                 p3_color = 2'b11;
                 p_color = 2'b11;
//                 territory_idx = 42; 
//                 territory_idx2 = 42;
//                 territory_idx3 = 42;
                 t_attack = 42;
                 t_defend = 42;
                 demo_bit <= 0;
                 
			end
            
            player_1_name :
            begin
                 menu_bit <= 1'b0; // No longer in menu
                 
                 // Displays text that will ask the player to enter the desired name
                 player_input = '{69, 110, 116, 101, 114, 0, 80, 108, 97, 121, 101, 114, 0, 49, 115, 0, 78, 97, 109, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Enter Player 1s Name
                 troops_chars = '{20{0}}; // Clear the troop count text
                 if (Keycodes == 16'h002A && prev_keycodes != Keycodes && player1_name_len > 0) begin // If delete key is pressed
                    p1_name[--player1_name_len] = 0;
                 end else if (Keycodes >= 16'h0004 && Keycodes <= 16'h001D && player1_name_len < 8 && Keycodes != prev_keycodes) begin // If key is pressed
                    p1_name[player1_name_len++] = Keycodes + 61; // Converts hex keycode to decimal
                 end
                 p_name = p1_name; 
            end
            
            player_1_color :
            begin
                menu_bit = 1'b0; // No longer in menu
                troops_chars = '{20{0}}; // Clear the troop count text
                 // Displays text that will ask the player to enter the desired name
                player_input = '{80, 73, 67, 75, 0, 80, 76, 65, 89, 69, 82, 0, 49, 83, 0, 67, 79, 76, 79, 82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Pick Player 1s color
                 if (Keycodes == 16'h0015) begin // If key is pressed
                    p1_color = 2'b00; // Corresponds to red when r is pressed
                 end else if (Keycodes == 16'h000A) begin
                    p1_color = 2'b01; // Corresponds to green when g is pressed
                 end else if (Keycodes == 16'h0012) begin
                    p1_color = 2'b10; // Corresponds to blue when o is pressed
                 end else begin
                    p1_color = 2'b11;
                 end
            end
            
            player_2_name :
            begin
                 menu_bit = 1'b0; // No longer in menu
                 
                 // Displays text that will ask the player to enter the desired name
                 player_input = '{69, 110, 116, 101, 114, 0, 80, 108, 97, 121, 101, 114, 0, 50, 115, 0, 78, 97, 109, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Enter Player 1s Name
                 troops_chars = '{20{0}}; // Clear the troop count text
                 if (Keycodes == 16'h002A && prev_keycodes != Keycodes && player2_name_len > 0) begin // If delete key is pressed
                    p2_name[--player2_name_len] = 0;
                 end else if (Keycodes != 16'h0000 && Keycodes >= 16'h0004 && Keycodes <= 16'h001D && player2_name_len < 8 && Keycodes != prev_keycodes) begin // If key is pressed
                    p2_name[player2_name_len++] = $unsigned(Keycodes) + 61; // Converts hex keycode to decimal
                 end
                 p_name = p2_name; 
            end
            
            player_2_color :
            begin
                menu_bit = 1'b0; // No longer in menu
                p2_color = 2'b11;
                 // Displays text that will ask the player to enter the desired name
                player_input = '{80, 73, 67, 75, 0, 80, 76, 65, 89, 69, 82, 0, 50, 83, 0, 67, 79, 76, 79, 82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Pick Player 1s color
                troops_chars = '{20{0}}; // Clear the troop count text
                 if (Keycodes == 16'h0015 && p1_color != 2'b00) begin // If key is pressed
                    p2_color = 2'b00; // Corresponds to red when r is pressed
                 end else if (Keycodes == 16'h000A && p1_color != 2'b01) begin
                    p2_color = 2'b01; // Corresponds to green when g is pressed
                 end else if (Keycodes == 16'h0012 && p1_color != 2'b10) begin
                    p2_color = 2'b10; // Corresponds to blue when o is pressed
                 end else begin
                    p2_color = 2'b11;
                 end
            end
            
            player_3_name :
            begin
                 menu_bit = 1'b0; // No longer in menu
                 
                 // Displays text that will ask the player to enter the desired name
                 player_input = '{69, 110, 116, 101, 114, 0, 80, 108, 97, 121, 101, 114, 0, 51, 115, 0, 78, 97, 109, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Enter Player 1s Name
                 troops_chars = '{20{0}}; // Clear the troop count text
                 if (Keycodes == 16'h002A && prev_keycodes != Keycodes && player3_name_len > 0) begin // If delete key is pressed
                    p3_name[--player3_name_len] = 0;
                 end else if (Keycodes != 16'h0000 && Keycodes >= 16'h0004 && Keycodes <= 16'h001D && player3_name_len < 8 && Keycodes != prev_keycodes) begin // If key is pressed
                    p3_name[player3_name_len++] = $unsigned(Keycodes) + 61; // Converts hex keycode to decimal
                 end
                 p_name = p3_name;     
            end
            
            player_3_color :
            begin
                menu_bit <= 1'b0; // No longer in menu
                p3_color <= 2'b11;
                 // Displays text that will ask the player to enter the desired name
                player_input <= '{80, 73, 67, 75, 0, 80, 76, 65, 89, 69, 82, 0, 51, 83, 0, 67, 79, 76, 79, 82, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; // Word = Pick Player 1s color
                troops_chars <= '{20{0}}; // Clear the troop count text
                 if (Keycodes == 16'h0015 && p1_color != 2'b00 && p2_color != 2'b00) begin // If key is pressed
                    p3_color <= 2'b00; // Corresponds to red when r is pressed
                 end else if (Keycodes == 16'h000A && p1_color != 2'b01 && p2_color != 2'b01) begin
                    p3_color <= 2'b01; // Corresponds to green when g is pressed
                 end else if (Keycodes == 16'h0012 && p1_color != 2'b10 && p2_color != 2'b10) begin
                    p3_color <= 2'b10; // Corresponds to blue when o is pressed
                 end else begin
                    p3_color <= 2'b11;
                 end
            end
            
            ///////////// Player 1 draft phase /////////////
            
            player_1_draft :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                troops_count[0] <= 5;
                t_attack <= 42;
                t_defend <= 42;
                p_name <= p1_name;
                p_color <= p1_color;
            end
            
            wait_for_selection_1 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p1_name;
              p_color <= p1_color;
              troops_chars[9] <= troops_count[0] + 48;
              // player_input[0:1] = '{87, 49};
              player_input <= '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 68, 69, 80, 76, 79, 89, 0, 84, 79}; // Select A territory to deploy to
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                territory_idx <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                territory_idx <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                territory_idx <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                territory_idx <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                territory_idx <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                territory_idx <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                territory_idx <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                territory_idx <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                territory_idx <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                territory_idx <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                territory_idx <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                territory_idx <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                territory_idx <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                territory_idx <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                territory_idx <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                territory_idx <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                territory_idx <= 29;
              end
            end
            
            deploy_troop_1 :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                if (territories[territory_idx][8:7] == p1_color) begin // Make sure territory is player's territory
                    t_selected = territory_idx; // Send territory to overhead for troop to be added to it.
                    troops_count[0] = troops_count[0] - 1;
                end
            end
            
            ///////////// Player 1 attack phase /////////////
            
            waiting_for_attacker_1 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;              
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 84, 84, 65, 67, 75, 73, 78, 71, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 0, 0, 0, 0}; // Select Attacking territory
              troops_chars = '{20{0}}; // Clear the troop count text
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_attack <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_attack <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_attack <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_attack <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_attack <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_attack <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_attack <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_attack <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_attack <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_attack <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_attack <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_attack <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_attack <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_attack <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_attack <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_attack <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_attack <= 29;
              end
              
              // Check to make sure that the territory belongs to the player and that it has more thanc 1 troop occupying it
              if (territories[t_attack][8:7] != p1_color || territories[t_attack][34:28] == 1)
                t_attack = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack from in the top left of the screen
                troops_chars[0] = territories[t_attack][6:0];
            end
            
            waiting_for_defender_1 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p1_name;
              p_color <= p1_color;
              troops_chars = '{20{0}}; // Clear the troop count text
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 0, 0};
              
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_defend <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_defend <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_defend <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_defend <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_defend <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_defend <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_defend <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_defend <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_defend <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_defend <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_defend <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_defend <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_defend <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_defend <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_defend <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_defend <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_defend <= 29;
              end
              
              // Check to make sure that the territory is not owned by the player and that the territory is adjacent to attacking territory
              if (territories[t_defend][8:7] == p1_color || (territories[t_attack][40:35] != t_defend &&
              territories[t_attack][46:41] != t_defend && territories[t_attack][52:47] != t_defend &&
              territories[t_attack][58:53] != t_defend && territories[t_attack][64:59] != t_defend &&
              territories[t_attack][70:65] != t_defend))
                t_defend = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack in the top left of the screen
                troops_chars[0] = territories[t_defend][6:0]; 
            end
            
            battle_calculation :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                battle_calc_flag = 1'b1;
                troops_chars = '{20{0}}; // Clear the troop count text
                player_input = '{80, 82, 69, 83, 83, 0, 65, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 79, 82, 0, 83, 0, 84, 79, 0, 83, 84, 79, 80, 0}; // Press A to attack or S to stop
            end
            
            player_1_attack :
            begin
                setup = 1'b0;
                menu_bit = 1'b0;
                p_name = p1_name;
                p_color = p1_color;
                troops_chars = '{20{0}}; // Clear the troop count text
                player_input[0:5] = '{65, 84, 84, 65, 67, 75}; // Attack
            end
            
            ///////////// Player 2 draft phase /////////////
            
//            player_2_draft :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                troops_count[1] = 5;
                
//            end
            
//            wait_for_selection_2 :
//            begin
//              setup = 1'b0;
//              menu_bit = 1'b0;
//              p_name = p2_name;
//              p_color = p2_color;
//              troops_chars[9] = troops_count[1] + 48;
//              //player_input[0:1] = '{87, 50};
//              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 68, 69, 80, 76, 79, 89, 0, 84, 79}; // Select A territory to deploy to
//              // Change territory_idx based on key pressed
//              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
//                territory_idx2 = Keycodes - 4; // Index for territory
//              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
//                territory_idx2 = 34;
//              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
//                territory_idx2 = 36;
//              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
//                territory_idx2 = 40;
//              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
//                territory_idx2 = 26;
//              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
//                territory_idx2 = 28;
//              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
//                territory_idx2 = 27;
//              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
//                territory_idx2 = 39;
//              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
//                territory_idx2 = 33;
//              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
//                territory_idx2 = 41;
//              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
//                territory_idx2 = 35;
//              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
//                territory_idx2 = 37;
//              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
//                territory_idx2 = 38;
//              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
//                territory_idx2 = 31;
//              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
//                territory_idx2 = 32;
//              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
//                territory_idx2 = 30;
//              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
//                territory_idx2 = 29;
//              end
//            end
            
            
//            deploy_troop_2 :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                if (territories[territory_idx2][8:7] == p2_color) begin // Make sure territory is player's territory
//                    troops_count[1] = troops_count[1] - 1;
//                    t_selected = territory_idx2; // Send territory to overhead for troop to be added to it.
//                end
//            end
            
//            ///////////// Player 2 attack phase /////////////
            
//            player_2_attack :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                p_name = p2_name;
//                p_color = p2_color;
//                troops_chars = '{20{0}}; // Clear the troop count text
//                player_input[0:5] = '{65, 84, 84, 65, 67, 75}; // Attack
//            end

            
            player_2_draft :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                troops_count[1] <= 5;
                t_attack <= 42;
                t_defend <= 42;
                p_name <= p2_name;
                p_color <= p2_color;
            end
            
            wait_for_selection_2 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p2_name;
              p_color <= p2_color;
              troops_chars[9] <= troops_count[1] + 48;
              // player_input[0:1] = '{87, 49};
              player_input <= '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 68, 69, 80, 76, 79, 89, 0, 84, 79}; // Select A territory to deploy to
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                territory_idx2 <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                territory_idx2 <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                territory_idx2 <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                territory_idx2 <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                territory_idx2 <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                territory_idx2 <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                territory_idx2 <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                territory_idx2 <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                territory_idx2 <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                territory_idx2 <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                territory_idx2 <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                territory_idx2 <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                territory_idx2 <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                territory_idx2 <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                territory_idx2 <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                territory_idx2 <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                territory_idx2 <= 29;
              end
            end
            
            deploy_troop_2 :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                if (territories[territory_idx2][8:7] == p2_color) begin // Make sure territory is player's territory
                    t_selected = territory_idx2; // Send territory to overhead for troop to be added to it.
                    troops_count[1] = troops_count[1] - 1;
                end
            end
            
            ///////////// Player 2 attack phase /////////////
            
            waiting_for_attacker_2 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;              
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 84, 84, 65, 67, 75, 73, 78, 71, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 0, 0, 0, 0}; // Select Attacking territory
              troops_chars = '{20{0}}; // Clear the troop count text
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_attack <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_attack <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_attack <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_attack <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_attack <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_attack <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_attack <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_attack <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_attack <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_attack <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_attack <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_attack <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_attack <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_attack <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_attack <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_attack <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_attack <= 29;
              end
              
              // Check to make sure that the territory belongs to the player and that it has more thanc 1 troop occupying it
              if (territories[t_attack][8:7] != p2_color || territories[t_attack][34:28] == 1)
                t_attack = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack from in the top left of the screen
                troops_chars[0] = territories[t_attack][6:0];
            end
            
            waiting_for_defender_2 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p2_name;
              p_color <= p2_color;
              troops_chars = '{20{0}}; // Clear the troop count text
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 0, 0};
              
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_defend <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_defend <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_defend <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_defend <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_defend <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_defend <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_defend <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_defend <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_defend <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_defend <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_defend <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_defend <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_defend <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_defend <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_defend <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_defend <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_defend <= 29;
              end
              
              // Check to make sure that the territory is not owned by the player and that the territory is adjacent to attacking territory
              if (territories[t_defend][8:7] == p2_color || (territories[t_attack][40:35] != t_defend &&
              territories[t_attack][46:41] != t_defend && territories[t_attack][52:47] != t_defend &&
              territories[t_attack][58:53] != t_defend && territories[t_attack][64:59] != t_defend &&
              territories[t_attack][70:65] != t_defend))
                t_defend = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack in the top left of the screen
                troops_chars[0] = territories[t_defend][6:0]; 
            end
            
            battle_calculation_2 :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                battle_calc_flag = 1'b1;
                troops_chars = '{20{0}}; // Clear the troop count text
                player_input = '{80, 82, 69, 83, 83, 0, 65, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 79, 82, 0, 83, 0, 84, 79, 0, 83, 84, 79, 80, 0}; // Press A to attack or S to stop
            end


            
//            ///////////// Player 3 draft phase /////////////
            
//            player_3_draft :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                troops_count[2] = 3;
//            end
            
//            wait_for_selection_3 :
//            begin
//              setup = 1'b0;
//              menu_bit = 1'b0;
//              p_name = p3_name;
//              p_color = p3_color;
//              troops_chars[9] = troops_count[2] + 48;
//              //player_input[0:1] = '{87, 51};
//              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 68, 69, 80, 76, 79, 89, 0, 84, 79}; // Select A territory to deploy to
//              // Change territory_idx based on key pressed
//              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
//                territory_idx3 = Keycodes - 4; // Index for territory
//              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
//                territory_idx3 = 34;
//              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
//                territory_idx3 = 36;
//              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
//                territory_idx3 = 40;
//              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
//                territory_idx3 = 26;
//              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
//                territory_idx3 = 28;
//              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
//                territory_idx3 = 27;
//              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
//                territory_idx3 = 39;
//              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
//                territory_idx3 = 33;
//              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
//                territory_idx3 = 41;
//              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
//                territory_idx3 = 35;
//              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
//                territory_idx3 = 37;
//              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
//                territory_idx3 = 38;
//              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
//                territory_idx3 = 31;
//              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
//                territory_idx3 = 32;
//              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
//                territory_idx3 = 30;
//              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
//                territory_idx3 = 29;
//              end
//            end
            
//            deploy_troop_3 :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                if (territories[territory_idx3][8:7] == p3_color) begin // Make sure territory is player's territory
//                    troops_count[2] = troops_count[2] - 1;
//                    t_selected = territory_idx3; // Send territory to overhead for troop to be added to it.
//                end
//            end
            
//            ///////////// Player 3 attack phase /////////////
            
//            player_3_attack :
//            begin
//                setup = 1'b0;
//                menu_bit = 1'b0;
//                p_name = p3_name;
//                p_color = p3_color;
//                troops_chars = '{20{0}}; // Clear the troop count text
//                player_input[0:5] = '{65, 84, 84, 65, 67, 75}; // Attack
//            end



            player_3_draft :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                troops_count[2] <= 5;
                t_attack <= 42;
                t_defend <= 42;
                p_name <= p3_name;
                p_color <= p3_color;
            end
            
            wait_for_selection_3 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p3_name;
              p_color <= p3_color;
              troops_chars[9] <= troops_count[2] + 48;
              // player_input[0:1] = '{87, 49};
              player_input <= '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 68, 69, 80, 76, 79, 89, 0, 84, 79}; // Select A territory to deploy to
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                territory_idx3 <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                territory_idx3 <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                territory_idx3 <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                territory_idx3 <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                territory_idx3 <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                territory_idx3 <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                territory_idx3 <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                territory_idx3 <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                territory_idx3 <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                territory_idx3 <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                territory_idx3 <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                territory_idx3 <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                territory_idx3 <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                territory_idx3 <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                territory_idx3 <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                territory_idx3 <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                territory_idx3 <= 29;
              end
            end
            
            deploy_troop_3 :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                if (territories[territory_idx2][8:7] == p3_color) begin // Make sure territory is player's territory
                    t_selected = territory_idx3; // Send territory to overhead for troop to be added to it.
                    troops_count[2] = troops_count[2] - 1;
                end
            end
            
            ///////////// Player 2 attack phase /////////////
            
            waiting_for_attacker_3 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;              
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 84, 84, 65, 67, 75, 73, 78, 71, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 0, 0, 0, 0}; // Select Attacking territory
              troops_chars = '{20{0}}; // Clear the troop count text
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_attack <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_attack <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_attack <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_attack <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_attack <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_attack <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_attack <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_attack <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_attack <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_attack <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_attack <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_attack <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_attack <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_attack <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_attack <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_attack <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_attack <= 29;
              end
              
              // Check to make sure that the territory belongs to the player and that it has more thanc 1 troop occupying it
              if (territories[t_attack][8:7] != p3_color || territories[t_attack][34:28] == 1)
                t_attack = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack from in the top left of the screen
                troops_chars[0] = territories[t_attack][6:0];
            end
            
            waiting_for_defender_3 :
            begin
              setup <= 1'b0;
              menu_bit <= 1'b0;
              p_name <= p3_name;
              p_color <= p3_color;
              troops_chars = '{20{0}}; // Clear the troop count text
              player_input = '{83, 69, 76, 69, 67, 84, 0, 65, 0, 84, 69, 82, 82, 73, 84, 79, 82, 89, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 0, 0};
              
              // Change territory_idx based on key pressed
              if ((Keycodes <= 16'h001D && Keycodes >= 16'h0004) && Keycodes != prev_keycodes) begin // Letter selected
                t_defend <= Keycodes - 4; // Index for territory
              end else if (Keycodes == 16'h002C && Keycodes != prev_keycodes) begin // space
                t_defend <= 34;
              end else if (Keycodes == 16'h002D && Keycodes != prev_keycodes) begin // -
                t_defend <= 36;
              end else if (Keycodes == 16'h002E && Keycodes != prev_keycodes) begin // =
                t_defend <= 40;
              end else if (Keycodes == 16'h002F && Keycodes != prev_keycodes) begin // [
                t_defend <= 26;
              end else if (Keycodes == 16'h0030 && Keycodes != prev_keycodes) begin // ]
                t_defend <= 28;
              end else if (Keycodes == 16'h0031 && Keycodes != prev_keycodes) begin // \
                t_defend <= 27;
              end else if (Keycodes == 16'h0033 && Keycodes != prev_keycodes) begin // ;
                t_defend <= 39;
              end else if (Keycodes == 16'h0034 && Keycodes != prev_keycodes) begin // "
                t_defend <= 33;
              end else if (Keycodes == 16'h0035 && Keycodes != prev_keycodes) begin // ~
                t_defend <= 41;
              end else if (Keycodes == 16'h0036 && Keycodes != prev_keycodes) begin // ,
                t_defend <= 35;
              end else if (Keycodes == 16'h0037 && Keycodes != prev_keycodes) begin // .
                t_defend <= 37;
              end else if (Keycodes == 16'h0038 && Keycodes != prev_keycodes) begin // /
                t_defend <= 38;
              end else if (Keycodes == 16'h004F && Keycodes != prev_keycodes) begin // ->
                t_defend <= 31;
              end else if (Keycodes == 16'h0050 && Keycodes != prev_keycodes) begin // <-
                t_defend <= 32;
              end else if (Keycodes == 16'h0051 && Keycodes != prev_keycodes) begin // down arrow
                t_defend <= 30;
              end else if (Keycodes == 16'h0052 && Keycodes != prev_keycodes) begin // up arrow
                t_defend <= 29;
              end
              
              // Check to make sure that the territory is not owned by the player and that the territory is adjacent to attacking territory
              if (territories[t_defend][8:7] == p3_color || (territories[t_attack][40:35] != t_defend &&
              territories[t_attack][46:41] != t_defend && territories[t_attack][52:47] != t_defend &&
              territories[t_attack][58:53] != t_defend && territories[t_attack][64:59] != t_defend &&
              territories[t_attack][70:65] != t_defend))
                t_defend = 42; // Make into invalid territory, eg: cant advance to next state.
              else // Otherwise display the character for the territory to attack in the top left of the screen
                troops_chars[0] = territories[t_defend][6:0]; 
            end
            
            battle_calculation_3 :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                battle_calc_flag = 1'b1;
                troops_chars = '{20{0}}; // Clear the troop count text
                player_input = '{80, 82, 69, 83, 83, 0, 65, 0, 84, 79, 0, 65, 84, 84, 65, 67, 75, 0, 79, 82, 0, 83, 0, 84, 79, 0, 83, 84, 79, 80, 0}; // Press A to attack or S to stop
            end


            demo :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                demo_bit <= 1;
            end


            victory :
            begin
                setup <= 1'b0;
                menu_bit <= 1'b0;
                p_name <= p1_name;
                p_color <= p1_color;
                victory_txt <= '{86, 73, 67, 84, 79, 82, 89, 1};
                vic <= 1'b1;
            end
            
            
			default : ;
		endcase
	end
	
    


endmodule



