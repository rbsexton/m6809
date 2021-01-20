// 8-Bit ALU
// 
// CPU Core Layer
// Maybe a little abstraction will help.
//
// This file is Copyright(C) 2021 by Robert Sexton
// Non-commercial use only 


module alu8 (
  input        [7:0] alu_in_a,  // LHS 
  input        [7:0] alu_in_b,  // RHS
  input        [3:0] op,        // Operation in 6809 Encoding
  input              op7,       // Disambiguation bit. 
  input              c_in,      // Carry In 
  input              v_in, 
  input              h_in,  
   
  input              val_clock, // Clocked assertions for test.

  output wire [ 7:0] alu_out,  
  output wire        c_out,   
  output wire        z_out, 
  output wire        n_out, 
  output wire        v_out, 
  output wire        h_out  
  
  );

// Operation decode.  The opcodes collide
// Load and Store are forms of test.
// And and Bit test are the same operation, with different 
// destinations for the result.
wire op_neg = op[3:0] == 4'h0 & ~op7;
wire op_sub = op[3:0] == 4'h0 &  op7; 
wire op_cmp = op[3:0] == 4'h1; 
wire op_sbc = op[3:0] == 4'h2;
wire op_com = op[3:0] == 4'h3; 
wire op_lsr = op[3:0] == 4'h4 & ~op7; 
wire op_and = op[3:0] == 4'h4 &  op7; 
wire op_bit = op[3:0] == 4'h5; 
wire op_ror = op[3:0] == 4'h6 & ~op7; 
wire op_ld  = op[3:0] == 4'h6 &  op7; 
wire op_asr = op[3:0] == 4'h7 & ~op7; 
wire op_st  = op[3:0] == 4'h7 &  op7; 
wire op_eor = op[3:0] == 4'h8 &  op7; 
wire op_lsl = op[3:0] == 4'h8 & ~op7; 
wire op_asl = op_lsl; 
wire op_adc = op[3:0] == 4'h9 &  op7; 
wire op_rol = op[3:0] == 4'h9 & ~op7; 
wire op_ora = op[3:0] == 4'ha &  op7; 
wire op_dec = op[3:0] == 4'ha & ~op7; 
wire op_add = op[3:0] == 4'hb; 
wire op_inc = op[3:0] == 4'hc;
wire op_tst = op[3:0] == 4'hd; 
wire op_clr = op[3:0] == 4'hf; 

// ----------------------------------------------
// ALU Condition Codes.
// ----------------------------------------------

wire [7:0] alu_in_a_inv         = alu_in_a ^ 8'hff       ;
wire [8:0] alu_in_a_pl_cin      = alu_in_a + {7'b0, c_in};
wire [8:0] alu_in_a_mi_cin      = alu_in_a +    {8{c_in}}; // 'Borrow'

wire [7:0] alu_in_b_inv        = alu_in_b ^ 8'hff        ;
wire [8:0] alu_in_b_2c         = alu_in_b_inv + 8'h01    ;


// All operations produce a carry bit.
wire [8:0] alu_out_neg =                alu_in_a_inv + 8'h01;

wire [8:0] alu_out_sub =              alu_in_a + alu_in_b_2c;
wire [8:0] alu_out_sbc =      alu_in_a_mi_cin  + alu_in_b_2c;
wire [8:0] alu_out_add = {   { 1'b0, alu_in_a} + { 1'b0, alu_in_b} };
wire [8:0] alu_out_adc =   alu_in_a_pl_cin + { 1'b0, alu_in_b};

wire [8:0] alu_out_com = { 1'b0,               alu_in_a_inv };
wire [8:0] alu_out_lsr = { alu_in_a[0], 1'b0, alu_in_a[7:1] };
wire [8:0] alu_out_and = { c_in,        alu_in_a & alu_in_b };

wire [8:0] alu_out_ror = { alu_in_a[0], c_in, alu_in_a[7:1] };
wire [8:0] alu_out_asr = { alu_in_a[0], alu_in_a[7],alu_in_a[7:1] };

wire [8:0] alu_out_eor = { c_in,        alu_in_a ^ alu_in_b };
wire [8:0] alu_out_asl = {                   alu_in_a, 1'b0 };
wire [8:0] alu_out_adc = {       alu_in_a + alu_in_b + c_in };

wire [8:0] alu_out_rol = {                   alu_in_a, c_in };
wire [8:0] alu_out_dec = {                 alu_in_a + 8'hff };
wire [8:0] alu_out_add = {              alu_in_a + alu_in_b };
wire [8:0] alu_out_inc =                         alu_in_a + 1;

wire [8:0] alu_out_sex = {                 {9{alu_in_a[7]}} };
wire [8:0] alu_out_ora = { c_in,        alu_in_a | alu_in_b };
wire [8:0] alu_out_tst = { c_in,                   alu_in_a };
wire [8:0] alu_out_clr = { 1'b0,                      8'h00 };

assign { c_out, alu_out } = 
  ( {9{op_neg}} & alu_out_neg ) | 
  ( {9{op_sub}} & alu_out_sub ) |
  ( {9{op_cmp}} & alu_out_sub ) |
  ( {9{op_sbc}} & alu_out_sbc ) |
  
  ( {9{op_com}} & alu_out_com ) |
  ( {9{op_lsr}} & alu_out_lsr ) |
  ( {9{op_and}} & alu_out_and ) |
  ( {9{op_bit}} & alu_out_and ) | 
  
  ( {9{op_ror}} & alu_out_ror ) |
  ( {9{op_ld }} & alu_out_tst ) |
  ( {9{op_asr}} & alu_out_asr ) |
  ( {9{op_st }} & alu_out_tst ) |

  ( {9{op_eor}} & alu_out_eor ) |
  ( {9{op_lsl}} & alu_out_asl ) |
  ( {9{op_asl}} & alu_out_asl ) |
  ( {9{op_adc}} & alu_out_adc ) |

  ( {9{op_rol}} & alu_out_rol ) |
  ( {9{op_dec}} & alu_out_dec ) |
  ( {9{op_add}} & alu_out_add ) |
  ( {9{op_inc}} & alu_out_lsr ) |

  ( {9{op_ora}} & alu_out_ora ) |
  ( {9{op_tst}} & alu_out_tst ) |
  ( {9{op_clr}} & alu_out_clr )
  ;
 
// assign c_out  = alu_out[8];
assign n_out  = alu_out[7];
assign z_out  = ~( |alu_out[7:0]);

// V is another special case.  Its 
// cleared by several operations, 
// and preserved by others.  
assign v_out = {
  op_and | op_eor | op_ora | op_tst ? 1'b0 :
  op_asr | op_lsr | op_ror ? v_in          :
  c_out ^ c_in
  };

wire [4:0] hsum  = alu_in_a + alu_in_a + c_in;
wire       h     = hsum[4];

// H is only defined for these two, otherwise preserved.
assign h_out = (op_adc | op_add ) ? h : h_in; 


// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog apparently support "simple immediate assertions"
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 

  // Only one operation at a time.
  // ASL and LSL are the same thing.
  always @(posedge val_clock) begin 
    assert( (
      op_neg + op_sub + op_cmp + op_sbc +
      op_com + op_lsr + op_and + op_bit +
      op_ror + op_ld  + op_asr + op_st  +
      op_eor + op_lsl +          op_adc + // ASL Omitted
      op_rol + op_dec + op_add + op_inc +
      op_ora + op_tst + op_clr 
      ) <= 1 );
    end 
    
endmodule