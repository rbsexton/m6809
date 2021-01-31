`timescale 1ns / 1ps
// CPU Register Moves
// Push/Pull Transfer/Exchange.
//
// Push/Pop are pretty complex.  
// put it into a single module so that its easier to test/validate.  
//
// This file is Copyright(C) 2021 by Robert Sexton
// Non-commercial use only 

module m6809_core_regmove (

  input              reset_b,    // Active Low Reset 
  input              clk,        // Clock
  
  input              start,      // Trigger when we take over. 
  
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

// Tie things off until they are ready.

assign  a_out   = "A";
assign  b_out   = "A";
assign  ccr_out = "C";
assign  dpr_out = "D";
assign  x_out   = "XX";
assign  y_out   = "YY";
assign  pc_out  = "PV";

// assign  s_out   = "ST";  
// assign  u_out   = "U";

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

wire do_pull  = inst_puls | inst_pulu; 
wire do_push  = inst_pshs | inst_pshu; 

wire update_s = inst_pshs | inst_puls;
wire update_u = inst_pshu | inst_pulu;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Handle Writes from PULL/TFR/EXR.
// The big ball of enables and switches. 
// ------------------------------------------------------------
// ------------------------------------------------------------
// ----------------------------------------------
// Mux Layer for register loads.
// ----------------------------------------------
// ------------------- ENABLES ------------------
wire        a_out_en_pul;
wire        b_out_en_pul;
wire        ccr_out_en_pul;
wire        dpr_out_en_pul;
wire        x_out_en_pul;
wire        y_out_en_pul;
wire        s_out_en_pul, s_out_en_psh;
wire        u_out_en_pul, u_out_en_psh;
wire        pc_out_en_pul;

assign      a_out_en = a_out_en_pul;
assign      b_out_en = b_out_en_pul;

assign      ccr_out_en = ccr_out_en_pul;
assign      dpr_out_en = dpr_out_en_pul;

assign      x_out_en = x_out_en_pul;
assign      y_out_en = y_out_en_pul;

// These two are the stack pointers themselves,
// so they get changed often.
assign      u_out_en = update_s & u_out_en_psh;
assign      s_out_en = update_s & s_out_en_psh;

assign      pc_out_en = pc_out_en_pul;

// ------------------- DATA  ------------------
wire [15:0] s_out_pul, s_out_psh;
wire [15:0] u_out_pul, u_out_psh;

assign s_out = update_s ?  s_out_psh : "ST";
assign u_out = update_u ?  u_out_psh : "UV";

wire  [7:0] a_out_pul;
wire  [7:0] b_out_pul;
wire  [7:0] ccr_out_pul;
wire  [7:0] dpr_out_pul;
wire [15:0] x_out_pul;
wire [15:0] y_out_pul;

assign a_out   = a_out_pul;
assign b_out   = b_out_pul;
assign ccr_out = ccr_out_pul;
assign dpr_out = dpr_out_pul;
assign x_out   = x_out_pul;
assign y_out   = y_out_pul;

assign s_out   = s_out_pul;

assign u_out   = u_out_pul;

// ----------------------------------------------
// Mux Layer for bus arbitration
// ----------------------------------------------

wire data_rw_n_psh;

assign data_rw_n = do_push ? data_rw_n_psh : 1'b1;

wire    psh_busy;
assign  bus_oe    = psh_busy;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Internal State 
// From the data sheet, page 4.
// ------------------------------------------------------------
// ------------------------------------------------------------
reg [7:0] pb;    // The post-byte contains the to-do list.
reg       byte0; // We have state to manage.

// Staging register for 16-bit ops.
reg [7:0] temp_pshl_q;
always @(posedge clk) temp_pshl_q <= do_push ? din : temp_pshl_q;

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

// Post-Byte worklist ready for register load.
wire [11:0] psh_wl_input = {
  din[7], din[7], din[6], din[6],
  din[5], din[5], din[4], din[4],  
  din[3], din[2], din[1], din[0]  
};

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
wire [11:0] psh_wl_q_next = (start & do_push) ? psh_wl_input : psh_wl_next; 

always @(posedge clk or negedge reset_b ) begin
  if ( ~reset_b) psh_wl_q <= 12'h0;
  else           psh_wl_q <= psh_wl_q_next; 
 end 

// For pushes, we advance the address before the push
// Generate the new address. 
wire [15:0] u_dec = u_in - 16'h0001;
wire [15:0] s_dec = s_in - 16'h0001;

wire [15:0] psh_addr_next = 
  ({16{update_u}} & u_dec ) |
  ({16{update_s}} & s_dec ) 
  ;

// Address tracks back to the input registers, so it 
// doesn't need to be registered in this module.
assign addr = ~reset_b ? 16'b0 : psh_addr_next;

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
assign s_out_psh     = {16{update_s & psh_busy}} & addr;
assign u_out_psh     = {16{update_u & psh_busy}} & addr;

assign data_rw_n_psh = ~psh_busy;

assign s_out_en_psh  = update_s & psh_busy;
assign u_out_en_psh  = update_u & psh_busy;

// Count the bits.  Is this necessary?
//reg  [3:0] psh_wl_len_q;
//wire [3:0] psh_wl_len_input = ( 
//  psh_wl_input[11] + psh_wl_input[10] +psh_wl_input[9] +psh_wl_input[8] +
//  psh_wl_input[7] + psh_wl_input[6] +psh_wl_input[6] +psh_wl_input[4] +
//  psh_wl_input[3] + psh_wl_input[2] +psh_wl_input[1] +psh_wl_input[0] 
//  );
//wire [3:0] psh_wl_len_next =  start ? psh_wl_len_input : (psh_wl_len_q - 1'b1);
//always @(posedge clk) psh_wl_len_q <= psh_wl_len_next;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Pull Operations
// Generate a worklist of bits from pb_q and shift through it.
// ------------------------------------------------------------
// ------------------------------------------------------------
  
// PULL 
// Walk the list of registers and generate the addresses for the bus.
// For each 8-bit register, post the address to the bus, and collect the 
// result directly into the register.


// Tie off as-yet unused nets.
wire pb_wl_pul_busy = 1'b0; // Tie off. 

assign a_out_en_pul   = 1'b0;
assign b_out_en_pul   = 1'b0;

assign ccr_out_en_pul = 1'b0;
assign dpr_out_en_pul = 1'b0;

assign x_out_en_pul   = 1'b0;
assign y_out_en_pul   = 1'b0;

assign u_out_en_pul   = 1'b0;
assign s_out_en_pul   = 1'b0;

assign pc_out_en_pul = 1'b0;


// Generate the strobes to write the new address back to the source Register.     
assign u_out_en_pul = update_s & pb_wl_pul_busy;
assign s_out_en_pul = update_u & pb_wl_pul_busy;



// wire [11:0] pb_wl_pul = {
//   pb_in[7], pb_in[7], pb_in[6], pb_in[6],
//   pb_in[5], pb_in[5], pb_in[4], pb_in[4],  
//   pb_in[3], pb_in[2], pb_in[1], pb_in[0]  
// }

// reg [11:0] wl_pul_q; 
// wire pb_wl_pul_busy = |wl_pul_q[11:0];

// Make up a set of bits that we can use to mask off completed ops.
// Each of these bits corresponds to "This bit and everything underneath
/* wire [11:0] wl_done = {
  |wl_pul[11:0], |wl_pul[10:0], |wl_pul[9:0], |wl_pul[8:0],
   |wl_pul[7:0], |wl_pul[6:0],  |wl_pul[5:0], |wl_pul[4:0],
   |wl_pul[3:0], |wl_pul[2:0],  |wl_pul[1:0], wl_pul[0] }

always @(posedge clk) begin {
  wl_pul <= start & do_pull ? pb_wl_pul : wl_pul; 
 end 

wire [7:0] pb_pull_next; 

wire [7:0] assign  
*/


// Staging register for 16-bit ops.
/*
reg [7:0] temp_pull_q;
always @(posedge clk) temp_pull_q <= do_pull ? din : temp_pull_q;
*/

// Generate the new address. 
/* wire [15:0] pull_next = {
  update_s ? s_in + 1'b1;
  update_u ? u_in + 1'b1;
  }
*/


// Assign the Register output muxes.  These are listed in 
// pq_q_unpacked order.  For 16-bit registers, use the 
// second bit.    Bit 6/9 is a special case.  It varies by 
// instruction.

/*
assign ccr_out_pul = pb_wl_pul[0] & din; 
assign a_out_pul   = pb_wl_pul[1] & din; 
assign b_out_pul   = pb_wl_pul[2] & din; 
assign dpr_out_pul = pb_wl_pul[3] & din; 
assign x_out_pul   = pb_wl_pul[5] & { din, temp_pull_q}; 
assign y_out_pul   = pb_wl_pul[7] & { din, temp_pull_q}; 

assign u_out_pul   = (pb_wl_pul[9] & inst_pulu ) & { din, temp_pull_q}; 
assign s_out_pul   = (pb_wl_pul[9] & inst_pulu ) & { din, temp_pull_q}; 

assign pc_out_pul  = pb_wl_pul[7] & { din, temp_pull_q};
*/
  
// Use an if-then-else structure.   Start with the 8 start cases, 
// and then handle the follow-ups. 
/*
assign { pb_pull_next pb_pull_b0 } = { 
  inst_puls & start & pb_in[0] ? { 0'b1, {pb_in[7:1],1'b0} } :
  inst_puls & start & pb_in[1] ? { 0'b1, {pb_in[7:2],2'b0} } :
  inst_puls & start & pb_in[2] ? { 0'b1, {pb_in[7:3],3'b0} } :
  inst_puls & start & pb_in[3] ? { 0'b1, {pb_in[7:4],4'b0} } :
  inst_puls & start & pb_in[4] ? { 0'b1, {pb_in[7:5],5'b0} } :
  inst_puls & start & pb_in[5] ? { 0'b1, {pb_in[7:6],6'b0} } :
  inst_puls & start & pb_in[6] ? { 0'b1, {pb_in[7:7],7'b0} } :
  inst_puls & start & pb_in[7] ? { 0'b1,             8'b0  } :

  inst_puls & pb_in[1] ?           { 0'b1, {pb_in[7:2],2'b0} } : // A
  inst_puls & pb_in[2] ?           { 0'b1, {pb_in[7:3],3'b0} } : // B
  inst_puls & pb_in[3] ?           { 0'b1, {pb_in[7:4],4'b0} } : // DPR
  inst_puls & pb_in[4] & ~pb_pull_b0 ? { 1'b1, {pb_in[7:5],5'b0} } : // X
  inst_puls & pb_in[4] &  pb_pull_b0 ? { 0'b1, {pb_in[7:5],5'b0} } : // X
  inst_puls & pb_in[5] & ~pb_pull_b0 ? { 1'b1, {pb_in[7:6],6'b0} } : // Y 
  inst_puls & pb_in[5] &  pb_pull_b0 ? { 0'b1, {pb_in[7:6],6'b0} } : // Y 
  inst_puls & pb_in[6] & ~pb_pull_b0 ? { 1'b1, {pb_in[7:7],7'b0} } : // U 
  inst_puls & pb_in[6] &  pb_pull_b0 ? { 0'b1, {pb_in[7:7],7'b0} } : // U 
  inst_puls & pb_in[7] & ~pb_pull_b0 ? { 1'b1,              8'b0 } :
     

  }; 
*/











// For Push and 
//------------------------------------------
// PUSH/POP State 
// There are a total of 12 possible states
// that go in opposite directions. 
//------------------------------------------
//ref [3:0] pushpop_state;
localparam st_pshpop_idle = 4'h0;
localparam st_pshpop_pcl  = 4'h1;
//localparam st_pshpop_pcl  = 4'h2;
localparam st_pshpop_pch  = 4'h3;
localparam st_pshpop_ush  = 4'h4;
localparam st_pshpop_usl  = 4'h5;
localparam st_pshpop_iyl  = 4'h6;
localparam st_pshpop_iyh  = 4'h7;
localparam st_pshpop_ixl  = 4'h8;
localparam st_pshpop_ixh  = 4'h9;
localparam st_pshpop_dpr  = 4'ha;
localparam st_pshpop_accb = 4'hb;
localparam st_pshpop_acca = 4'hc;
localparam st_pshpop_ccr  = 4'hd;

// Do this with a prioritized encoder.
//wire [3:0] next_pushpop_state = {
//  pushpop_state == st_pshpop_idle & 


  
//pushpop_state
//}


// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog support "simple immediate assertions"
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 
always @(posedge clk) begin

  // Only one destination register at a time
  assert( (
    a_out_en + b_out_en + 
    ccr_out_en + dpr_out_en +
    x_out_en + y_out_en + s_out_en + u_out_en + pc_out_en
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
    assert(data_rw_n == 1'b0); 
    end
    
  // Only one destination register at time 
  // This one might be impossible.
  assert( (update_s + update_u) <= 1 );

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
