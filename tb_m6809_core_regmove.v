`timescale 1ns / 1ps

// Testbench for 6809 Register move module.
// Integration notes - The start/enable pulse should 
// happen on the update of the post-byte register.
// The post-byte should get captured directly off of the input.

module tb_m6809_core_regmove;

	// Inputs
	reg reset_b;
	reg clk;
  
  reg [7:0] ir_in;      // Instruction Register
  reg [7:0] din;        // Post-Byte
  reg start;

  m6809_core_regmove_integration i (
    .reset_b(reset_b),
    .clk(clk),
    .ir_in(ir_in),
    .din(din),
    .start(start)
    )
  ;

  initial
    begin
       $dumpfile("tb_m6809_regmove");
       $dumpvars(0,i);
    end
  
  always begin 
    clk =      0; #10;
    clk =      1; #10;
    end

	initial begin
		// Initialize Inputs
		reset_b = 0;
    start   = 0; 
    ir_in   = 8'h34; // PSHS
    din     = 8'h00; 
		// Wait for global reset to finish
		#30;
    reset_b = 1;

    #20;

    ir_in = 8'h34; // PSHS 
    #20;

    start = 1;
    din = 8'hff; // Random.  
    #20;
    
    start = 0;

    #500;
    
    $finish; 
    end
    
endmodule

