// 16-Bit ALU
// 
// The 16-bit ALU has far fewer features.
// Instructions that use it:
// add compares loads sign extend stores subtract multiply 

CPU Core Layer
// M

module alu16 (
  input        [15:0] alu_in_a,  // LHS 
  input        [15:0] alu_in_b,  // RHS
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
wire op_add = op[3:0] == 4'h3; 
wire op_cmp = op[3:0] == 4'h1; // Two-Byte 

wire op_sub  = op[3:0] == 4'h0 &  op7; 
wire op_ldd  = op[3:0] == 4'hC; 
wire op_lds  = op[3:0] == 4'hC; 
wire op_ldu  = op[3:0] == 4'hC; 
wire op_st  = op[3:0] == 4'h7 &  op7; 
wire op_sex = op[3:0] == 4'hd; 

// ----------------------------------------------
// ALU Condition Codes.
// ----------------------------------------------

// wire [7:0] alu_in_a_inv = alu_in_a ^ 16'hff;
wire [7:0] alu_in_b_inv = alu_in_b ^ 8'hff;

// All operations produce a carry bit.
wire [8:0] alu_out_sub =         alu_in_a + alu_in_b_inv + 1;
wire [8:0] alu_out_add = {              alu_in_a + alu_in_b };
wire [8:0] alu_out_sex = {                 {9{alu_in_a[7]}} };
wire [8:0] alu_out_tst = { c_in,                   alu_in_a };
wire [8:0] alu_out_clr = { 1'b0,                      8'h00 };

assign { c_out, alu_out } = 
  ( {9{op_sub}} & alu_out_sub ) |
  ( {9{op_cmp}} & alu_out_sub ) |
  ( {9{op_ld }} & alu_out_tst ) |
  ( {9{op_st }} & alu_out_tst ) |
  ( {9{op_add}} & alu_out_add ) |
  ( {9{op_sex}} & alu_out_sex ) |
  ( {9{op_tst}} & alu_out_tst ) 
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
      op_sex + op_ora + op_tst + op_clr 
      ) <= 1 );
    end 
    
endmodule