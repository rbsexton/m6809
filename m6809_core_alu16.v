// 16-Bit ALU
// 
// The 16-bit ALU has far fewer features.
// Instructions that use it:
// add compares loads sign extend stores subtract multiply 
// No Half Carry 

module alu16 (
  input        [15:0] alu_in_a,  // LHS 
  input        [15:0] alu_in_b,  // RHS
  input        [3:0] op,        // Operation in 6809 Encoding
  input              op6,       // Disambiguation bit. 
  input              page2,     // Opcode Page  
  input              page3,     // Opcode Page 
  input              c_in,      // Carry In 
  input              v_in, 
  input              h_in,  
   
  input              val_clock, // Clocked assertions for test.

  output wire [15:0] alu_out,  
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

wire op_add  = op[3:0] == 4'h3 & ~page2 & ~page3 &  op6; // [c-f]3 
wire op_subd = op[3:0] == 4'h3 & ~page2 & ~page3 & ~op6; // [8-f]3 
wire op_cmpd = op[3:0] == 4'h3 &  page2; // Two-Byte 
wire op_cmpu = op[3:0] == 4'h3 &  page3; // Two-Byte 

wire op_cmps = op[3:0] == 4'hc &  page3; // Two-Byte 
wire op_cmpx = op[3:0] == 4'hc &  ~op6 ;   // [8-b]C 
wire op_cmpy = op[3:0] == 4'hc &  page2; // Two-Byte 
wire op_ldd  = op[3:0] == 4'hc &  op6  ;   // [c-f]c 

wire op_std  = op[3:0] == 4'hd &  op6;   // [d-f]d 
wire op_sex  = op[3:0] == 4'hd & ~op6;   // 1d

wire op_lds  = op[3:0] == 4'he & page2; // [c-f]c 
wire op_ldu  = op[3:0] == 4'he &  op6;  // [c-f]e  
wire op_ldx  = op[3:0] == 4'he & ~op6;  // [8-b]e
wire op_ldy  = op[3:0] == 4'he & page2;  

wire op_sts  = op[3:0] == 4'hf & page2; // [d-f]f 
wire op_stx  = op[3:0] == 4'hf & ~op6;    // [9-b]f
wire op_sty  = op[3:0] == 4'hf & page2; // [9-b]f 
wire op_stu  = op[3:0] == 4'hf & op6  ; // [d-f]f  

// There is no test, but thats what a lot of these are 
wire op_tst = 
  op_ldd | op_lds | op_ldu | op_ldx | op_ldy |
  op_sts | op_stx | op_sty | op_stu;

// ----------------------------------------------
// ALU Condition Codes.
// ----------------------------------------------

//wire [7:0] alu_in_a_inv = alu_in_a ^ 16'hff;
//wire [7:0] alu_in_b_inv = alu_in_b ^ 8'hff;
//wire [8:0] alu_out_add = {              alu_in_a + alu_in_b };
//wire [8:0] alu_out_sex = {                 {9{alu_in_a[7]}} };
//wire [8:0] alu_out_clr = { 1'b0,                      8'h00 };

// All operations produce a carry bit.
wire [16:0] alu_out_tst = { c_in,                   alu_in_a };

// assign { c_out, alu_out } = {17{op_tst}} & alu_out_tst;
// assign { c_out, alu_out } = alu_out_tst;

assign { c_out, alu_out } = 
  ({17{op_tst}} & alu_out_tst)
  ;

assign n_out  = alu_out[15];
assign z_out  = ~( |alu_out[15:0]);

// V is another special case.  Its 
// cleared by several operations, 
// and preserved by others.
assign v_out = v_in;   
// assign v_out = {
//  op_and | op_eor | op_ora | op_tst ? 1'b0 :
//  op_asr | op_lsr | op_ror ? v_in          :
//  c_out ^ c_in
//  };

// No Half-Carry 
assign h_out = h_in; 


// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog apparently support "simple immediate assertions"
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 

  // Only one operation at a time.
  // ASL and LSL are the same thing.
  always @(posedge val_clock) begin 
    assert( (
      op_add + op_subd + op_cmpd + op_cmpu +
      op_cmps + op_cmpx + op_cmpy + op_ldd +
      op_std + op_sex +
      op_lds + op_ldu + op_ldx + op_ldy +
      op_sts + op_stx + op_sty + op_stu
      ) <= 1 );
    end 
    
endmodule