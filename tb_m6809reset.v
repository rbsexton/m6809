`timescale 1ns / 1ps

// Testbench for 6809 SOC, reset code. 

module tb_6809reset;

	// Inputs
	reg reset_b;
	reg clk;
	reg halt_b;

	// Instantiate the Unit Under Test (UUT)
	m6809_integration uut  (
		.reset_b(reset_b), 
		.clk(clk), 
		.halt_b(halt_b) 
	);

  initial
    begin
       $dumpfile("tb_m6809reset");
       $dumpvars(0,uut);
    end
  
  always begin 
    clk =      0; #10;
    clk =      1; #10;
    end

	initial begin
		// Initialize Inputs
		reset_b = 0;
		// Wait 100 ns for global reset to finish
		#100;
    reset_b = 1;

    #500;
    
    $finish; 
    end
    
endmodule

