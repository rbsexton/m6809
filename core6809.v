// CPU Core Layer
//
// General Notes.
// This is a big-endian device.
//
// The 6809 is a memory traffic rich device.

module core6809 (

  input              reset_b,   // Active Low Reset 
  input              clk,       // Clock 
  
  input              halt_b,    // Terminate after the current instruction.
  
  output reg  [15:0] addr,      // External Memory address
  input        [7:0] data_in,   // External Memory data in
  output wire  [7:0] data_out,  // External Memory data out     
  output wire        data_rw_n  // Memory Write  
  
  );

// ------------------------------------------------------------
// ------------------------------------------------------------
// Internal Device State and registers. 
// From the data sheet, page 4.
// ------------------------------------------------------------
// ------------------------------------------------------------

reg  [15:0] x_q;
reg  [15:0] y_q;
reg  [15:0] usp_q;
reg  [15:0] hsp_q;
reg  [15:0] pc_q;   // Per data sheet, address of the NEXT instruction 
reg  [ 7:0] a_q;
reg  [ 7:0] b_q;

wire [15:0] d_q;
assign d_q = { a_q, b_q };

reg  [ 7:0] dp_q;

reg  cc_e_q;
reg  cc_f_q;
reg  cc_h_q;
reg  cc_i_q;
reg  cc_n_q;
reg  cc_z_q;
reg  cc_v_q;
reg  cc_c_q;

wire [7:0] reg_cc; 
assign reg_cc = {   
  cc_e_q, cc_f_q, cc_h_q, cc_i_q, 
  cc_n_q, cc_z_q, cc_v_q, cc_c_q 
  };

reg [7:0] ir_q; // Instruction Register.
reg [7:0] pb_q; // Post-Byte for 16-bit instructions.

// ------------------------------------------------------------
// Instruction decode.
// Wires for every instruction, in alphabetical order.
// Sub-Organize them by addressing mode.
// Hopefully the patterns will become apparent.
// ------------------------------------------------------------

wire inst_abx                   = ir_q == 8'h3a;

// Add with Carry ( 8-bit ) 
wire inst_adca_imm              = ir_q == 8'h89;
wire inst_adca_dir              = ir_q == 8'h99;
wire inst_adca_idx              = ir_q == 8'hA9;
wire inst_adca_ext              = ir_q == 8'hB9;

wire inst_adcb_imm              = ir_q == 8'hC9;
wire inst_adcb_dir              = ir_q == 8'hD9;
wire inst_adcb_idx              = ir_q == 8'hE9;
wire inst_adcb_ext              = ir_q == 8'hF9;

// Add Without Carry ( 8 & 16-bit )
wire inst_adda_imm              = ir_q == 8'h8b;
wire inst_adda_dir              = ir_q == 8'h9b;
wire inst_adda_idx              = ir_q == 8'hab;
wire inst_adda_ext              = ir_q == 8'hbb;

wire inst_addb_imm              = ir_q == 8'hcb;
wire inst_addb_dir              = ir_q == 8'hdb;
wire inst_addb_idx              = ir_q == 8'heb;
wire inst_addb_ext              = ir_q == 8'hfb;

wire inst_addd_imm              = ir_q == 8'hc3;
wire inst_addd_dir              = ir_q == 8'hd3;
wire inst_addd_idx              = ir_q == 8'he3;
wire inst_addd_ext              = ir_q == 8'hf3;

// And ( 8-Bit ) 
wire inst_anda_imm              = ir_q == 8'h84;
wire inst_anda_dir              = ir_q == 8'h94;
wire inst_anda_idx              = ir_q == 8'ha4;
wire inst_anda_ext              = ir_q == 8'hb4;

wire inst_andb_imm              = ir_q == 8'hc4;
wire inst_andb_dir              = ir_q == 8'hd4;
wire inst_andb_idx              = ir_q == 8'he4;
wire inst_andb_ext              = ir_q == 8'hf4;

wire inst_andcc_imm             = ir_q == 8'h1c;

// Arithmetic Shift Left (ASL)
wire inst_asla                  = ir_q == 8'h48;
wire inst_aslb                  = ir_q == 8'h58;

wire inst_asl_dir               = ir_q == 8'h08;
wire inst_asl_idx               = ir_q == 8'h68;
wire inst_asl_ext               = ir_q == 8'h78;

// Arithmetic Shift Right (ASR)
wire inst_asra                  = ir_q == 8'h47;
wire inst_asrb                  = ir_q == 8'h57;

wire inst_asr_dir               = ir_q == 8'h07;
wire inst_asr_idx               = ir_q == 8'h67;
wire inst_asr_ext               = ir_q == 8'h77;

// Bit tests 
wire inst_bita_imm              = ir_q == 8'h85;
wire inst_bita_dir              = ir_q == 8'h95;
wire inst_bita_idx              = ir_q == 8'ha5;
wire inst_bita_ext              = ir_q == 8'hb5;

wire inst_bitb_imm              = ir_q == 8'hc5;
wire inst_bitb_dir              = ir_q == 8'hd5;
wire inst_bitb_idx              = ir_q == 8'he5;
wire inst_bitb_ext              = ir_q == 8'hf5;

// Clear Instructions
wire inst_clra                  = ir_q == 8'h4f;
wire inst_clrb                  = ir_q == 8'h5f;

wire inst_clr_dir               = ir_q == 8'h0f;
wire inst_clr_idx               = ir_q == 8'h6f;
wire inst_clr_ext               = ir_q == 8'h7f;

// Compares 
wire inst_cmpa_imm              = ir_q == 8'h81;
wire inst_cmpa_dir              = ir_q == 8'h91;
wire inst_cmpa_idx              = ir_q == 8'ha1;
wire inst_cmpa_ext              = ir_q == 8'hb1;

wire inst_cmpb_imm              = ir_q == 8'hc1;
wire inst_cmpb_dir              = ir_q == 8'hd1;
wire inst_cmpb_idx              = ir_q == 8'he1;
wire inst_cmpb_ext              = ir_q == 8'hf1;

// Some of the compares take two bytes to decode.
wire inst_cmpd                  = ir_q == 8'h10;
wire inst_cmpd_imm              = pb_q == 8'h83;
wire inst_cmpd_dir              = pb_q == 8'h93;
wire inst_cmpd_idx              = pb_q == 8'ha3;
wire inst_cmpd_ext              = pb_q == 8'hb3;

wire inst_cmpy                  = ir_q == 8'h10;
wire inst_cmpy_imm              = pb_q == 8'h8c;
wire inst_cmpy_dir              = pb_q == 8'h9c;
wire inst_cmpy_idx              = pb_q == 8'hac;
wire inst_cmpy_ext              = pb_q == 8'hbc;

wire inst_cmps                  = ir_q == 8'h11;
wire inst_cmps_imm              = pb_q == 8'h8c;
wire inst_cmps_dir              = pb_q == 8'h9c;
wire inst_cmps_idx              = pb_q == 8'hac;
wire inst_cmps_ext              = pb_q == 8'hbc;

wire inst_cmpu                  = ir_q == 8'h11;
wire inst_cmpu_imm              = pb_q == 8'h83;
wire inst_cmpu_dir              = pb_q == 8'h93;
wire inst_cmpu_idx              = pb_q == 8'ha3;
wire inst_cmpu_ext              = pb_q == 8'hb3;

wire inst_cmpx_imm              = ir_q == 8'h8c;
wire inst_cmpx_dir              = ir_q == 8'h9c;
wire inst_cmpx_idx              = ir_q == 8'hac;
wire inst_cmpx_ext              = ir_q == 8'hbc;

// Complement Instructions
wire inst_coma                  = ir_q == 8'h43;
wire inst_comb                  = ir_q == 8'h53;

wire inst_com_dir               = ir_q == 8'h03;
wire inst_com_idx               = ir_q == 8'h63;
wire inst_com_ext               = ir_q == 8'h73;

// CWAI 
wire inst_cwai                   = ir_q == 8'h3c;

// Decimal Adjust 
wire inst_daa                    = ir_q == 8'h19;

// Decrement 
wire inst_deca                  = ir_q == 8'h4a;
wire inst_decb                  = ir_q == 8'h5a;

wire inst_dec_dir               = ir_q == 8'h0a;
wire inst_dec_idx               = ir_q == 8'h6a;
wire inst_dec_ext               = ir_q == 8'h7a;

// Exclusive Or 
wire inst_eora_imm              = ir_q == 8'h88;
wire inst_eora_dir              = ir_q == 8'h98;
wire inst_eora_idx              = ir_q == 8'ha8;
wire inst_eora_ext              = ir_q == 8'hb8;

wire inst_eorb_imm              = ir_q == 8'hc8;
wire inst_eorb_dir              = ir_q == 8'hd8; 
wire inst_eorb_idx              = ir_q == 8'he8;
wire inst_eorb_ext              = ir_q == 8'hf8;

// Increment  
wire inst_inca                  = ir_q == 8'h4c;
wire inst_incb                  = ir_q == 8'h5c;

wire inst_inc_dir               = ir_q == 8'h0c;
wire inst_inc_idx               = ir_q == 8'h6c;
wire inst_inc_ext               = ir_q == 8'h7c;

// Jump 
wire inst_jmp_dir               = ir_q == 8'h0e;
wire inst_jmp_idx               = ir_q == 8'h6e;
wire inst_jmp_ext               = ir_q == 8'h7e;

// Jump to subroutine
wire inst_jsr_dir               = ir_q == 8'h9d;
wire inst_jsr_idx               = ir_q == 8'had;
wire inst_jsr_ext               = ir_q == 8'hbd;

// Many, Many forms of Load
wire inst_lda_imm              = ir_q == 8'h86;
wire inst_lda_dir              = ir_q == 8'h96;
wire inst_lda_idx              = ir_q == 8'ha6;
wire inst_lda_ext              = ir_q == 8'hb6;

wire inst_ldb_imm              = ir_q == 8'hc6;
wire inst_ldb_dir              = ir_q == 8'hd6;
wire inst_ldb_idx              = ir_q == 8'he6;
wire inst_ldb_ext              = ir_q == 8'hf6;

wire inst_ldd_imm              = ir_q == 8'hcc;
wire inst_ldd_dir              = ir_q == 8'hdc;
wire inst_ldd_idx              = ir_q == 8'hec;
wire inst_ldd_ext              = ir_q == 8'hfc;

wire inst_lds                  = ir_q == 8'h10;
wire inst_lds_imm              = pb_q == 8'hce;
wire inst_lds_dir              = pb_q == 8'hde;
wire inst_lds_idx              = pb_q == 8'hee;
wire inst_lds_ext              = pb_q == 8'hfe;

wire inst_ldu_imm              = ir_q == 8'hce;
wire inst_ldu_dir              = ir_q == 8'hde;
wire inst_ldu_idx              = ir_q == 8'hee;
wire inst_ldu_ext              = ir_q == 8'hfe;

wire inst_ldx_imm              = ir_q == 8'h8e;
wire inst_ldx_dir              = ir_q == 8'h9e;
wire inst_ldx_idx              = ir_q == 8'hae;
wire inst_ldx_ext              = ir_q == 8'hbe;

wire inst_ldy                  = ir_q == 8'h10;
wire inst_ldy_imm              = pb_q == 8'h8e;
wire inst_ldy_dir              = pb_q == 8'h9e;
wire inst_ldy_idx              = pb_q == 8'hae;
wire inst_ldy_ext              = pb_q == 8'hbe;

// Load Effective Address 
wire inst_leas                  = ir_q == 8'h32;
wire inst_leau                  = ir_q == 8'h33;
wire inst_leax                  = ir_q == 8'h30;
wire inst_leay                  = ir_q == 8'h31;

// Logical Shift Left
wire inst_lsla                  = ir_q == 8'h48;
wire inst_lslb                  = ir_q == 8'h58;

wire inst_lsl_dir               = ir_q == 8'h08;
wire inst_lsl_idx               = ir_q == 8'h68;
wire inst_lsl_ext               = ir_q == 8'h78;

// Logical Shift Right
wire inst_lsra                  = ir_q == 8'h44;
wire inst_lsrb                  = ir_q == 8'h54;

wire inst_lsr_dir               = ir_q == 8'h04;
wire inst_lsr_idx               = ir_q == 8'h64;
wire inst_lsr_ext               = ir_q == 8'h74;



// NOP 
wire inst_nop                    = ir_q == 8'h12;

// ------------------------------------------------------------
// State machines.
// Align the states with memory accesses.
// ------------------------------------------------------------

reg  [3:0] state; 

localparam st_reset           = 4'd0;
localparam st_reset_fetch_msb = 4'd1; // Reset Vector MSB Fetch  
localparam st_reset_fetch_lsb = 4'd2; // Reset Vector LSB Fetch 
localparam st_fetch_ir        = 4'd3; // Reset IR Fetch 

// Break the states out into one-hot signals.
// use them in combinatorial logic to drive the state machine.
wire do_reset       =    state == st_reset;
wire do_fetchr_msb  =    state == st_reset_fetch_msb; // First fetch from reset.
wire do_fetchr_lsb  =    state == st_reset_fetch_lsb; // Second fetch from reset.
wire do_fetch_ir    =    state == st_fetch_ir;        // Fetch the first byte.

// Product of Sums for master state machine.
wire [3:0] state_nxt = (
  ( {4{do_reset      }} & st_reset_fetch_msb ) | 
  ( {4{do_fetchr_msb }} & st_reset_fetch_lsb ) |
  ( {4{do_fetchr_lsb }} & st_fetch_ir ) |
  ( {4{do_fetch_ir   }} & st_fetch_ir  )  
  );

always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    state <= st_reset;
    end 
  else begin 
    state <= state_nxt;
    end 
  end


// ------------------------------------------------------------
// Memory Control
// Notes on the memory fetcher.    Per the data sheet, the 
// program counter points the the next instruction to be 
// executed.   This system manages the pc register.    
// ------------------------------------------------------------

// When in reset, force this to FFFE  
always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    addr <= 16'hfffe;
    end 
  else begin 
    addr <= addr_next;
    end 
  end
   

wire [15:0] addr_next; 

// Address Generation logic product of sums notation.
// The Program counter state machine is closely coupled 
// to the address generation state machine.
assign addr_next = (
  ( {16{ do_reset     }} & 16'hfffe ) |
  ( {16{do_fetchr_msb }} & 16'hffff ) |
  ( {16{do_fetchr_lsb }} & pc_q     ) |
  ( {16{do_fetch_ir   }} & pc_q + 1 ) 
);

// Program Counter Control.
// This needs to point to the next thing to fetch.
wire [15:0] pc_q_next = (
  ( {16{do_reset      }} & 16'h0000                ) |
  ( {16{do_fetchr_msb }} & { data_in, 8'b0 }       ) |
  ( {16{do_fetchr_lsb }} & { pc_q[15:8], data_in } ) |
  ( {16{do_fetch_ir   }} & pc_q + 1                ) 
);

always @(posedge clk) begin 
    pc_q <= pc_q_next;
  end



// ----------------------------------------
// Interfaces with the rest of the system
// Assemble 16-bit things into a single register for 16-bit fetches.
reg [15:0] mem_capture;

// ----------------------------------------
// Internals 
// ----------------------------------------


endmodule