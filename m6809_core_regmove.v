`timescale 1ns / 1ps
// CPU Register Moves
// Push/Pull Transfer/Exchange.
//
// Push/Pop are pretty complex.  
// put it into a single module so that its easier to test/validate.  
//
// This file is Copyright(C) 2021 by Robert Sexton
// Non-commercial use only 
//
// Ports  

module m6809_core_regmove (

  input              reset_b,    // Active Low Reset 
  input              clk,        // Clock
  
  // The start pulse must align with the presence of 
  // the post-byte on din. 
  input              start,      //  
  
  output wire [15:0] addr,       // External Memory address
  output             data_rw_n,  // Memory Write  
  
  input        [7:0] din,        // External Memory data in
  output wire  [7:0] dout,       // External Memory data out     

  // This module needs to take ownership of the system memory bus.
  output wire  bus_oe,
  
  input        [7:0] ir_in,      // Instruction Register
  
  input        [7:0] a_in,
  input        [7:0] b_in,
  input        [7:0] ccr_in,
  input        [7:0] dpr_in,

  input       [15:0] x_in,
  input       [15:0] y_in,

  input       [15:0] s_in,
  input       [15:0] u_in,

  input       [15:0] pc_in,
  
  output       [7:0] a_out,
  output       [7:0] b_out,
  output       [7:0] ccr_out,
  output       [7:0] dpr_out,

  output      [15:0] x_out,
  output      [15:0] y_out,

  output      [15:0] s_out,  
  output      [15:0] u_out,
  
  output      [15:0] pc_out,

  // The module needs strobes to go with register writes
  output wire  a_out_en,
  output wire  b_out_en,
  output wire  ccr_out_en,
  output wire  dpr_out_en,
  output wire  x_out_en,
  output wire  y_out_en,
  output wire  s_out_en,
  output wire  u_out_en,
  output wire  pc_out_en

  );

// ------------------------------------------------------------
// ------------------------------------------------------------
// Instruction Decode 
// ------------------------------------------------------------
// ------------------------------------------------------------
wire inst_pshs                  = ir_in == 8'h34;
wire inst_pshu                  = ir_in == 8'h36;

// Pulls   
wire inst_puls                  = ir_in == 8'h35;
wire inst_pulu                  = ir_in == 8'h37;

wire inst_pull  = inst_puls | inst_pulu; 
wire inst_push  = inst_pshs | inst_pshu; 

wire inst_update_s = inst_pshs | inst_puls;

// The U register is updated/update-able on all pushes and pulls.
wire inst_update_u = inst_pull | inst_push;

// U register handling.
wire inst_pshu_pulu = inst_pshu | inst_pulu;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Handle Writes from PULL/TFR/EXR.
// The big ball of enables and switches. 
// ------------------------------------------------------------
// ------------------------------------------------------------
// ------------------------------------------------------------
// Register Muxes/Enables in post-byte order.
// ------------------------------------------------------------
// ------------------------------------------------------------
wire        ccr_out_en_pul;
wire  [7:0] ccr_out_pul;
assign      ccr_out    = ccr_out_pul;
assign      ccr_out_en = ccr_out_en_pul;

wire        a_out_en_pul;
wire  [7:0] a_out_pul;
assign      a_out    = a_out_pul;
assign      a_out_en = a_out_en_pul;

wire  [7:0] b_out_pul;
wire        b_out_en_pul;
assign      b_out    = b_out_pul;
assign      b_out_en = b_out_en_pul;

wire  [7:0] dpr_out_pul;
wire        dpr_out_en_pul;
assign      dpr_out    = dpr_out_pul;
assign      dpr_out_en = dpr_out_en_pul;

wire        x_out_en_pul;
wire [15:0] x_out_pul;
assign x_out    = x_out_pul;
assign x_out_en = x_out_en_pul;

wire        y_out_en_pul;
wire [15:0] y_out_pul;
assign y_out    = y_out_pul;
assign y_out_en = y_out_en_pul;

// U is updated by push/pop operations.
wire        u_out_en_pul, u_out_en_psh;
wire [15:0] u_out_pul, u_out_psh;
assign      u_out_en = inst_update_u & ( u_out_en_psh | u_out_en_pul);
assign         u_out = 
  {16{u_out_en_pul}} & u_out_pul | 
  {16{u_out_en_psh}} & u_out_psh;


wire        pc_out_en_pul;
wire [15:0] pc_out_pul;
assign      pc_out_en = pc_out_en_pul;
assign      pc_out    = pc_out_pul;

// S isn't part of the post-byte, so put it after.
wire        s_out_en_pul, s_out_en_psh;
wire [15:0] s_out_pul, s_out_psh;
assign      s_out_en = inst_update_s & (s_out_en_psh | s_out_en_pul);
assign         s_out = 
  {16{s_out_en_pul}} & s_out_pul | 
  {16{s_out_en_psh}} & s_out_psh;

// ----------------------------------------------
// Mux Layer for bus arbitration
// ----------------------------------------------

wire data_rw_n_psh;

assign data_rw_n = inst_push ? data_rw_n_psh : 1'b1;

wire    psh_busy,pul_busy;

assign  bus_oe    = psh_busy;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Internal State 
// From the data sheet, page 4.
// ------------------------------------------------------------
// ------------------------------------------------------------

// Staging register for 16-bit ops.
reg [7:0] temp_pshl_q;
always @(posedge clk) temp_pshl_q <= inst_push ? din : temp_pshl_q;

// ------------------------------------------------------------
// The register work list is derived from the postbyte. 
// ------------------------------------------------------------

// Post-Byte worklist ready for register load.
wire [11:0] wl_input = {
  din[7], din[7], din[6], din[6],
  din[5], din[5], din[4], din[4],  
  din[3], din[2], din[1], din[0]  
};

// The output address is driven by either the push or the pull system.

// Address tracks back to the input registers, so it 
// doesn't need to be registered in this module.
wire [15:0] addr_psh;
wire [15:0] addr_pul;

assign addr = 
  {16{psh_busy}} & addr_psh | 
  {16{pul_busy}} & addr_pul  ; 
  
// ------------------------------------------------------------
// ------------------------------------------------------------
// Push
// Do this first because its helpful for test. 
// Generate a work list of bits from pb_q and shift through it.
// ------------------------------------------------------------
// ------------------------------------------------------------

// ---- This is the worklist of registers to push ------
reg [11:0] psh_wl_q; 
assign     psh_busy = |psh_wl_q[11:0];

// Make up a set of bits that we can use to mask off completed ops.
// Each of these bits corresponds to "This bit and everything after"
// Push is done L->R 
wire [10:0] psh_wl_mask = {
  |psh_wl_q[11:11],  |psh_wl_q[11:10],|psh_wl_q[11:9], |psh_wl_q[11:8],
  |psh_wl_q[11:7],   |psh_wl_q[11:6], |psh_wl_q[11:5], |psh_wl_q[11:4],
  |psh_wl_q[11:3],   |psh_wl_q[11:2], |psh_wl_q[11:1]  };

// There are two different masking operations - 
// stripping away the most significant set bit after the transfer 
// and converting worklist from a multi-bit set to a single bit
// that can be be used to trigger the output logic. 
wire [11:0] psh_wl_next        = psh_wl_q & { 1'b0, psh_wl_mask};
wire [11:0] psh_wl_selectedbit = psh_wl_q & ~psh_wl_next;

// Worklist_q management 
wire [11:0] psh_wl_q_next = (start & inst_push) ? wl_input : psh_wl_next; 

always @(posedge clk or negedge reset_b ) begin
  if ( ~reset_b) psh_wl_q <= 12'h0;
  else           psh_wl_q <= psh_wl_q_next; 
 end 

// For pushes, we advance the address before the push
// Generate the new address. 
wire [15:0] u_dec = u_in - 16'h0001;
wire [15:0] s_dec = s_in - 16'h0001;

wire [15:0] psh_addr_next = 
  ({16{inst_pshu_pulu}} & u_dec ) |
  ({16{inst_update_s}} & s_dec ) 
  ;

assign addr_psh = psh_addr_next;

assign dout = 
  ({8{psh_wl_selectedbit[11]}} &  pc_in[15:8]) |   
  ({8{psh_wl_selectedbit[10]}} &  pc_in[ 7:0]) |   

  ({8{psh_wl_selectedbit[9]}} &  u_in[15:8])   |   
  ({8{psh_wl_selectedbit[8]}} &  u_in[ 7:0])   |   

  ({8{psh_wl_selectedbit[7]}} &  y_in[15:8])   |   
  ({8{psh_wl_selectedbit[6]}} &  y_in[ 7:0])   |   

  ({8{psh_wl_selectedbit[5]}} &  x_in[15:8])   |   
  ({8{psh_wl_selectedbit[4]}} &  x_in[ 7:0])   |   

  ({8{psh_wl_selectedbit[3]}} &  dpr_in[ 7:0]) |   
  ({8{psh_wl_selectedbit[2]}} &  b_in[ 7:0])   |   
  ({8{psh_wl_selectedbit[1]}} &  a_in[ 7:0])   |   
  ({8{psh_wl_selectedbit[0]}} &  ccr_in[ 7:0]) 
  ;

// When the register mover is in charge, we own the 
// system registers.
assign s_out_psh     = {16{inst_update_s & psh_busy}} & addr;
assign u_out_psh     = {16{inst_pshu_pulu & psh_busy}} & addr;

assign data_rw_n_psh = ~psh_busy;

// The U register should only get updated by push when we're using 
// it as a stack pointer. 
assign s_out_en_psh  = inst_update_s & psh_busy;
assign u_out_en_psh  = inst_pshu_pulu & psh_busy ;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Pull Operations
// This is derived from to the push code.
// ------------------------------------------------------------
// ------------------------------------------------------------
// Walk the list of registers and generate the addresses for the bus.
// For each 8-bit register, post the address to the bus, and collect the 
// result directly into the register.

// ---- This is the worklist of registers to push ------
reg [11:0] pul_wl_q; 
assign     pul_busy = |pul_wl_q[11:0];

// Make up a set of bits that we can use to mask off completed ops.
// Each of these bits corresponds to "This bit and everything after"
// Pull is done L<-R
wire [10:0] pul_wl_mask = {
  |pul_wl_q[10:0], |pul_wl_q[9:0],|pul_wl_q[8:0],
  |pul_wl_q[7:0],  |pul_wl_q[6:0], |pul_wl_q[5:0],|pul_wl_q[4:0],
  |pul_wl_q[3:0],  |pul_wl_q[2:0], |pul_wl_q[1:0], |pul_wl_q[0:0]  };


// There are two different masking operations - 
// stripping away the most significant set bit after the transfer 
// and converting worklist from a multi-bit set to a single bit
// that can be be used to trigger the output logic. 
wire [11:0] pul_wl_next        = pul_wl_q & { pul_wl_mask, 1'b0 };
wire [11:0] pul_wl_selectedbit = pul_wl_q & ~pul_wl_next;

// Worklist_q management 
wire [11:0] pul_wl_q_next = (start & inst_pull) ? wl_input : pul_wl_next; 

always @(posedge clk or negedge reset_b ) begin
  if ( ~reset_b) pul_wl_q <= 12'h0;
  else           pul_wl_q <= pul_wl_q_next; 
 end 

// Pulls are post-increment.
// Generate the new address. 
wire [15:0] u_inc = u_in + 1'h1;
wire [15:0] s_inc = s_in + 1'h1;

wire [15:0] pul_addr_next = 
  ({16{inst_pshu_pulu}} & u_inc ) |
  ({16{inst_update_s}} & s_inc ) 
  ;

assign addr_pul = 
  ({16{inst_pshu_pulu}} & u_in ) |
  ({16{inst_update_s}} & s_in ) 
  ;

// Staging register for 16-bit ops.  For Pulls, high byte first.
reg [7:0] temp_pull_q;
always @(posedge clk) temp_pull_q <= inst_pull ? din : temp_pull_q;

// The various enables are just bits in the pul_wl_selectedbit register.

assign ccr_out_en_pul = pul_wl_selectedbit[0];
assign ccr_out_pul    = {8{ccr_out_en_pul}} & din;
 
assign a_out_en_pul   = pul_wl_selectedbit[1];
assign a_out_pul      = {8{a_out_en_pul}} & din;

assign b_out_en_pul   = pul_wl_selectedbit[2];
assign b_out_pul      = {8{b_out_en_pul}} & din;

assign dpr_out_en_pul = pul_wl_selectedbit[3];
assign dpr_out_pul    = {8{dpr_out_en_pul}} & din;

assign x_out_en_pul   = pul_wl_selectedbit[5];
assign x_out_pul      = {16{x_out_en_pul}} & { temp_pull_q, din};

assign y_out_en_pul   = pul_wl_selectedbit[7];
assign y_out_pul      = {16{y_out_en_pul}} & { temp_pull_q, din};

assign u_out_en_psh  = ( inst_pshu | inst_pulu ) & psh_busy ;

// How to handle PULU? Prioritize update as a pointer.
assign u_out_en_pul   = pul_wl_selectedbit[9] | ( inst_pshu_pulu & pul_busy );
assign u_out_pul      = inst_pshu_pulu  ? addr : { temp_pull_q, din} ;
  
assign pc_out_en_pul  = pul_wl_selectedbit[11];
assign pc_out_pul      = {16{pc_out_en_pul}} & { temp_pull_q, din};

// Generate the strobes to write the new address back to the source Register.     
assign s_out_en_pul = inst_update_s & pul_busy;

// When the register mover is in charge, we own the 
// system registers.
assign s_out_pul     = {16{inst_update_s & pul_busy}} & pul_addr_next;


// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog support "simple immediate assertions"
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 
always @(posedge clk) begin

  // Only one destination register at a time
  // Don't include S or U.   We need a better assertion.
  assert( (
    a_out_en + b_out_en + 
    ccr_out_en + dpr_out_en +
    x_out_en + y_out_en + pc_out_en
    ) <= 1 );


  // For other ir_q inputs, all of the output enables must be zero.
  if ( (inst_pshs | inst_pshu | inst_puls |inst_pulu) == 0 ) begin 
    assert( (
      a_out_en + b_out_en + ccr_out_en + dpr_out_en +
      x_out_en + y_out_en + s_out_en + u_out_en + pc_out_en
      ) == 0 );
    // assert(data_rw_n == 1'b1); 
    end
    
  //  data_rw_n must only go low when we're doing PSH 
  if ( (inst_pshs | inst_pshu) == 0 ) begin
    assert(data_rw_n == 1'b1); 
    end

  // Push and pull must take turns.
  assert( (psh_busy + pul_busy ) <= 1); 
  
  assert( (u_out_en_pul + u_out_en_psh) <= 1 );
  assert( (s_out_en_pul + s_out_en_psh) <= 1 );
  
  // If we're pushing/pulling u, we must not be 
  // modifying the stack pointer.  The converse is not 
  // true.
  if ( inst_pshu_pulu ) assert( inst_update_s == 0 );

  // When Pulling, only one destination register at a time.
  if ( (inst_puls | inst_pulu) == 1'b1 ) begin
    assert( (ccr_out_en + a_out_en + b_out_en + dpr_out_en +
            x_out_en + y_out_en ) <= 1 );
    end


  end 

// -----------------------------------------
// Formal Verification.
// Initial clock assumptions from 
// https://zipcpu.com/blog/2017/10/19/formal-intro.html     
// -----------------------------------------
`ifdef FORMAL

  reg [7:0] tb_cycle;
  initial tb_cycle = 8'b0; 
  always @(posedge clk) tb_cycle <= tb_cycle + 1'b1;

  reg [15:0] last_addr_q;
  reg        past_valid_addr_q;
  initial past_valid_addr_q = 1'b0; 

  reg	last_clk_q, past_valid_q;
  
  initial past_valid_q = 1'b0; 

  always @(posedge clk) begin 
    past_valid_q <= 1'b1;
    
    // Trigger Once.
    if (  past_valid_addr_q == 0 & psh_busy ) begin 
      past_valid_addr_q <= 1'b1;
      last_addr_q       <= addr;
      end 
      
    if (  past_valid_addr_q == 1 & psh_busy ) begin
      last_addr_q <= addr; 
      assert(  addr == (last_addr_q - 1'b1) ); // It should be going down..
      end 
    end
  
  always @(*)
  	if (!past_valid_q)
  		assume(reset_b == 0);
    
// Because the registers don't belong to this layer,
// let the integration layer own the assumptions.
  
`endif

endmodule
