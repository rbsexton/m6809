`timescale 1ns / 1ps

// integration module for testbenching the register move module.

// Testbench for 6809 Code register moves.  
// The module needs an external RAM and it has to write and re-write 
// externally - owned registers.

module m6809_core_regmove_integration (
  // Inputs
  input reset_b,
  input clk,
  input [2:0] tphase,

  input [7:0] ir_in,       // Instruction Register.  Post-byte comes from din.
  input [7:0] din_ext,     // Externally Driven din.
  input       din_ext_sel, // Externally Driven din.
  input       reg_reset,   // A hook for resetting the registers.
  input start
  );

  wire [15:0] addr;       // External Memory address
  wire        data_rw_n;  // Memory Write  
  
  wire  [7:0] dout;       // External Memory data out
  wire        bus_oe;     

  wire  [7:0] din_int;         
  wire  [7:0] din;       // External Memory In
  
  assign      din = din_ext_sel ? din_ext : din_int;
  
  
  // Registers 
  wire [7:0] a_out;
  wire [7:0] b_out;
  wire [7:0] ccr_out;
  wire [7:0] dpr_out;

  wire [15:0] x_out;
  wire [15:0] y_out;

  wire [15:0] s_out;  
  wire [15:0] u_out;
  
  wire [15:0] pc_out;

   wire  a_out_en;
   wire  b_out_en;
   wire  ccr_out_en;
   wire  dpr_out_en;
   wire  x_out_en;
   wire  y_out_en;
   wire  s_out_en;
   wire  u_out_en;
   wire  pc_out_en;
   wire  dprr_out_en;

   // Define the initial value of all registers.
   reg  [7:0] a_q;   initial a_q   = "A"; 
   reg  [7:0] b_q;   initial b_q   = "B";
   reg  [7:0] ccr_q; initial ccr_q = "C";
   reg  [7:0] dpr_q; initial dpr_q = "D";

   reg  [15:0] x_q; initial x_q    = "_X";
   reg  [15:0] y_q; initial y_q    = "_Y";

   reg [15:0] s_q;  initial s_q    = 16'h0;
   reg [15:0] u_q;  initial u_q    = 16'h80;
   reg [15:0] pc_q; initial pc_q   = 16'h1234;

   always @(posedge clk or posedge reg_reset) begin
    if ( reg_reset ) begin 
      a_q   <= 8'b0; 
      b_q   <= 8'b0; 
      ccr_q <= 8'b0; 
      dpr_q <= 8'b0; 
      x_q   <= 16'b0; 
      y_q   <= 16'b0; 
      u_q   <= 16'b0; 
      pc_q  <= 16'b0; 
      end 
    else begin
      if ( a_out_en )     a_q <= a_out; 
      if ( b_out_en )     b_q <= b_out; 
      if ( ccr_out_en ) ccr_q <= ccr_out; 
      if ( dpr_out_en ) dpr_q <= dpr_out; 
      if ( x_out_en )     x_q <= x_out; 
      if ( y_out_en )     y_q <= y_out; 
      if ( u_out_en )     u_q <= u_out; 
      if ( pc_out_en )   pc_q <= pc_out; 
      // Skip s.  They get reset.
      end
    end 

	// Instantiate the Unit Under Test (UUT)
	m6809_core_regmove uut  (
  	.reset_b(reset_b),   .clk(clk),

    .start(start),
    .ir_in(ir_in),
    
    .addr(addr),
    .data_rw_n(data_rw_n),
    .bus_oe(bus_oe),
    
    .din(din),         .dout(dout),
    
    .a_in(a_q),       .b_in(b_q),
    .ccr_in(ccr_q),
    .dpr_in(dpr_q),

    .x_in(x_q),       .y_in(y_q),
    .s_in(s_q),       .u_in(u_q),
  
    .pc_in(pc_q),
    
    .a_out(a_out),    .b_out(b_out),
    .x_out(x_out),    .y_out(y_out),
    .s_out(s_out),    .u_out(u_out),

    .ccr_out(ccr_out),
    .dpr_out(dpr_out),
    .pc_out(pc_out),
    
    .a_out_en(a_out_en), .b_out_en(b_out_en),
    .x_out_en(x_out_en), .y_out_en(y_out_en),
    .s_out_en(s_out_en),  .u_out_en(u_out_en),

    .pc_out_en(pc_out_en),
    .ccr_out_en(ccr_out_en),
    .dpr_out_en(dpr_out_en)

	   );
  
  always @(posedge clk or negedge reset_b ) begin
    if ( ~reset_b ) begin 
      s_q <= 16'h0;
      end
    else begin 
      if ( s_out_en ) s_q <= s_out;
      end
    end 
  
// ------------------------------------------------------------------------
// This module needs ram.
// ------------------------------------------------------------------------
mem_ram u_ram (
  .clk(clk),
  .sel(1'b1),
  .wr_n(data_rw_n),
  .a(addr[7:0]),
  .dout(din_int),
  .din(dout)
  );


// ------------------------------------------------------------------------
// Internal stuff to support formal validation.
// ------------------------------------------------------------------------
reg [7:0] tb_cycle;

initial tb_cycle = 8'b0; 

always @(posedge clk) tb_cycle <= tb_cycle + 1'b1;

// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog support "simple immediate assertions"
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 
//always @(posedge clk) begin

// Only one destination register at a time
//  assert( (
//    ) <= 1 );
// end 

// -----------------------------------------
// Formal Verification.
// Initial clock assumptions from 
// https://zipcpu.com/blog/2017/10/19/formal-intro.html     
// -----------------------------------------
`ifdef FORMAL

  reg	last_clk_q, past_valid_q;  
  initial past_valid_q = 1'b0; 

  // Assume that the start bit is only high for one cycle.
  // There is no way for there to be back to back starts.
  reg last_start_q;

  always @(posedge clk) begin 
    past_valid_q <= 1'b1;
    last_start_q <= start;
    if ( last_start_q == 1 ) assume(start == 1'b0);
    end 
  
  
  always @(*) begin 
  	if (!past_valid_q)
  		assume(reset_b == 0);
      assume(start   == 0);
    end 
    

// The register input values don't have any role 
// so wire them down.    
  always @(posedge clk) begin     

    assume( ir_in   == 8'h34); // Push

  // Encode there with ASCOO
  //  assume( a_in   == "A");
  //  assume( b_in   == "B");
  //  assume( ccr_in == "C");
  //  assume( dpr_in == "D");

    //assume( x_in == "X");
    //assume( y_in == "Y");
    
  //  assume( s_in == 16'h0000);
//    assume( u_in == 16'h8000);
    end   
  
`endif
      
endmodule

