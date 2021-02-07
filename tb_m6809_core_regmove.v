`timescale 1ns / 1ps

// Testbench for 6809 Register move module.
// Integration notes - The start/enable pulse should 
// happen on the update of the post-byte register.
// The post-byte should get captured directly off of the input.

module tb_m6809_core_regmove;

	// Inputs
	reg reset_b;
	reg clk;
  
  reg [7:0] ir_in;       // Instruction Register
  reg [7:0] din_ext;     // externally driven din. 
  reg       din_ext_sel; // select  
  reg start;
  reg reg_reset;         // Hook to zero all the user registers.

  reg [2:0] tphase; 

  m6809_core_regmove_integration i (
    .reset_b(reset_b),
    .clk(clk),
    .tphase(tphase),
    .ir_in(ir_in),
    .din_ext(din_ext),     // Externally Driven din.
    .din_ext_sel(din_ext_sel), // Externally Driven din.
    .reg_reset(reg_reset),

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
    tphase    = 0;
		reset_b   = 0;
    reg_reset = 0;
    start     = 0; 
    ir_in     = 8'h34; // PSHS
    din_ext   = 8'h00; 
    din_ext_sel = 0; 
		// Wait for global reset to finish
		#30;
    reset_b = 1;
    tphase  = 1;

    #20;

    ir_in = 8'h34; // PSHS 
    #20;

    start   = 1;
    din_ext = 8'hff; // Random.  
    din_ext_sel = 1; 
    #20;
    start = 0;
    din_ext_sel = 0; 

    #20;
    din_ext_sel = 0; 
    

    #300;
    reg_reset = 1;
    #20;
    reg_reset = 0;
    
    
    tphase  = 2;
    ir_in   = 8'h35; // PULS
    #20;

    start   = 1;
    din_ext = 8'hfe; //  
    din_ext_sel = 1; 
    #20;

    din_ext_sel = 0; 

    
    start = 0;
    
    
    
    #300;
    $finish; 
    end
    
endmodule

