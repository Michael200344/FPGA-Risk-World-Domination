module ff_prev_keypress(
    input logic clk, reset,
    input logic [31:0] D,
    output logic  [31:0] Q
    );
    
    always_ff @ (posedge clk or posedge reset) begin
        if (reset) begin
            Q <= '{32{0}};
        end else begin
            Q <= D;
        end
    end
endmodule

module ff_prev_territory_idx (
    input logic clk, reset,
    input int D,
    output int Q
    );
    
    always_ff @ (posedge clk or posedge reset) begin
        if (reset) begin
            Q <= 0;
        end else begin
            Q <= D;
        end
    end
endmodule
