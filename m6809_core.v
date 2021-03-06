`timescale 1ns / 1ps
// CPU Core Layer
//
// General Notes.
// This is a big-endian device.
//
// The 6809 is a memory traffic rich device.
//
// This file is Copyright(C) 2021 by Robert Sexton
// Non-commercial use only 

module m6809_core (

  input              reset_b,   // Active Low Reset 
  input              clk,       // Clock 
  
  //input              halt_b,    // Terminate after the current instruction.
  
  output wire [15:0] addr,      // External Memory address
  output             data_rw_n, // Memory Write  

  input        [7:0] din,   // External Memory data in
  output wire  [7:0] data_out   // External Memory data out     
  
  );

assign data_out = 8'b0; // Tie off

// ------------------------------------------------------------
// ------------------------------------------------------------
// Internal Device State and registers. 
// From the data sheet, page 4.
// ------------------------------------------------------------
// ------------------------------------------------------------

reg  [ 7:0] a_q  /* verilator public */;
reg  [ 7:0] b_q  /* verilator public */;
reg  [ 7:0] dp_q /* verilator public */;
reg  [ 7:0] cc_q /* verilator public */; 

//wire [15:0] d_q = { a_q, b_q };
reg  [15:0] x_q;
reg  [15:0] y_q;
reg  [15:0] u_q;
reg  [15:0] s_q;
reg  [15:0] pc_q;   // Per data sheet, address of the NEXT instruction 

// Bit offsets for the condition code register 
localparam CC_E = 3'd7; // Entire
localparam CC_F = 3'd6; // FIRQ Mask
localparam CC_H = 3'd5; // Half Carry 
localparam CC_I = 3'd4; // IRQ Mask  
localparam CC_N = 3'd3; // Negative 
localparam CC_Z = 3'd2; // Zero  
localparam CC_V = 3'd1; // Overflow 
localparam CC_C = 3'd0; // Carry 

reg [7:0] ir_q;     // Fetch 0 Instruction Register.
reg [7:0] pb_q;     // Fetch 1 Post-Byte for 16-bit instructions.
reg [7:0] fetch2_q; // Fetch 2 .
// reg [7:0] fetch3_q; // Fetch 3 .


// ------------------------------------------------
// Publish the address bus to verilator.
`ifdef verilator
   function [15:0] get_core_addr;
      // verilator public
      get_core_addr = addr;
   endfunction // get_core_addr
`endif

// --------------------------------------------
// One-hot Instruction Fetch state.  Not strictly 
// the fetch state.  
// Direct fetches include both 8 and 16-bit data.
// One Big State Machine.  The Page2/3 opcodes are 
// handled as additional bits captured on the first fetch
// These states start when the instruction is on the data bus  
// inh  : -> !                       (abx)
// imm8r : -> f_a0 -> !              (adda,addb)
// imm16r: -> f_a0 -> f_a1 !         (add)
// ext16r: -> f_a0 -> f_a1 !         (ldd)
// dir8r : -> f_a0 -> r_m0 !         (adda,addb)
// dir16r: -> f_a0 -> r_m0 -> r_m1 ! (addd)
// dir8w : -> f_a0 -> w_m0 !         (sta)
// ext8w : -> f_a0 -> f_a1 -> w_m1 ! (sta)
// dir16w: -> f_a0 -> w_m0 -> w_m1 ! (std)

// psh/pop: -> f_a0 -> w_m0 -> w_m1 ...  ! 

// Indexing takes more work.
// idx8r : -> f_a0 -> w_m0 -> w_m1 ! (std)


// fetchop -> page2 -> fetchop ->   
// --------------------------------------------
reg  [7:0] fetch_state;

localparam st_fetch_wait   = 8'h01; // Data Wait 
localparam st_fetch_ir     = 8'h02; // Byte 0: IR Fetch                            
localparam st_fetch_pb_imm = 8'h04; // Byte 1: Post Byte / Immediate Fetch   
localparam st_fetch_b2     = 8'h08; // Byte 2   
localparam st_fetch_b3     = 8'h10; // Byte 3   
localparam st_fetch_lsu_turn = 8'h20; // The LSU needs at minimum 1 cycle.  
localparam st_fetch_lsu_wait = 8'h40; // Fetch data via direct access.    

wire fetch_wait            = fetch_state[0];
wire fetch_ir              = fetch_state[1];
wire fetch_pb_imm          = fetch_state[2];
wire fetch_b2              = fetch_state[3];
wire fetch_b3              = fetch_state[4];
wire fetch_lsu_turn        = fetch_state[5];
wire fetch_lsu_wait        = fetch_state[6];
// wire fetch_dir1            = fetch_state[7];

// ------------------------------------------------------------
// ------------------------------------------------------------
// Instruction Execution decode.
// Wires for every instruction, in alphabetical order.
// Sub-Organize them by addressing mode.
// These signals should become active when all instruction 
// and argument fetches are complete.  
//
// The instruction fetch logic has its own decode.
//
// One thing thats a bit of a mess is that we have one and two byte 
// instructions.   There aren't that many two byte instructions,
// just enough to make the instruction fetcher more complicated.
// The data sheet refers to these as page2 and page3 

// ------------------------------------------------------------
// ------------------------------------------------------------
reg [3:2] ipage; // One-Hot exended instruction. 

wire inst_abx                   = ir_q == 8'h3a;

// Add with Carry ( 8-bit ) 
wire inst_adca_imm              = ir_q == 8'h89 & fetch_ir;
wire inst_adca_dir              = ir_q == 8'h99;
wire inst_adca_idx              = ir_q == 8'hA9;
wire inst_adca_ext              = ir_q == 8'hB9 & fetch_ir;

wire inst_adcb_imm              = ir_q == 8'hC9 & fetch_ir;
wire inst_adcb_dir              = ir_q == 8'hD9;
wire inst_adcb_idx              = ir_q == 8'hE9;
wire inst_adcb_ext              = ir_q == 8'hF9 & fetch_ir;

// Add Without Carry ( 8 & 16-bit )
wire inst_adda_imm              = ir_q == 8'h8b & fetch_ir;
wire inst_adda_dir              = ir_q == 8'h9b;
wire inst_adda_idx              = ir_q == 8'hab;
wire inst_adda_ext              = ir_q == 8'hbb & fetch_ir;

wire inst_addb_imm              = ir_q == 8'hcb & fetch_ir;
wire inst_addb_dir              = ir_q == 8'hdb;
wire inst_addb_idx              = ir_q == 8'heb;
wire inst_addb_ext              = ir_q == 8'hfb & fetch_pb_imm;

wire inst_addd_imm              = ir_q == 8'hc3;
wire inst_addd_dir              = ir_q == 8'hd3;
wire inst_addd_idx              = ir_q == 8'he3;
wire inst_addd_ext              = ir_q == 8'hf3 & fetch_ir;

// And ( 8-Bit ) 
wire inst_anda_imm              = ir_q == 8'h84 & fetch_ir;
wire inst_anda_dir              = ir_q == 8'h94;
wire inst_anda_idx              = ir_q == 8'ha4;
wire inst_anda_ext              = ir_q == 8'hb4 & fetch_ir;

wire inst_andb_imm              = ir_q == 8'hc4 & fetch_ir;
wire inst_andb_dir              = ir_q == 8'hd4;
wire inst_andb_idx              = ir_q == 8'he4;
wire inst_andb_ext              = ir_q == 8'hf4 & fetch_ir;

wire inst_andcc_imm             = ir_q == 8'h1c & fetch_ir;

// Arithmetic Shift Left (ASL)
wire inst_asla                  = ir_q == 8'h48; // Done 
wire inst_aslb                  = ir_q == 8'h58; // Done 

wire inst_asl_dir               = ir_q == 8'h08;
wire inst_asl_idx               = ir_q == 8'h68;
wire inst_asl_ext               = ir_q == 8'h78 & fetch_ir;

// Arithmetic Shift Right (ASR)
wire inst_asra                  = ir_q == 8'h47; // Done 
wire inst_asrb                  = ir_q == 8'h57; // Done 

wire inst_asr_dir               = ir_q == 8'h07;
wire inst_asr_idx               = ir_q == 8'h67;
wire inst_asr_ext               = ir_q == 8'h77 & fetch_ir;

// Simple Branches 
wire inst_bra                   = ir_q == 8'h20; 
wire inst_brn                   = ~ipage[2] & ir_q == 8'h21;  
wire inst_lbrn                  =  ipage[2] & ir_q == 8'h21;

wire inst_bsr                   = ir_q == 8'h8d;
wire inst_lbsr                  = ir_q == 8'h17;

wire inst_bmi                   = ir_q == 8'h2b;
wire inst_bpl                   = ir_q == 8'h2a;
wire inst_beq                   = ir_q == 8'h27;
wire inst_bne                   = ir_q == 8'h26;
wire inst_bvs                   = ir_q == 8'h29;
wire inst_bvc                   = ir_q == 8'h28;
wire inst_bcs                   = ir_q == 8'h25; // Done 
wire inst_bcc                   = ir_q == 8'h24; // Done

// Bit tests 
wire inst_bita_imm              = ir_q == 8'h85 & fetch_ir;
wire inst_bita_dir              = ir_q == 8'h95;
wire inst_bita_idx              = ir_q == 8'ha5;
wire inst_bita_ext              = ir_q == 8'hb5 & fetch_ir;

wire inst_bitb_imm              = ir_q == 8'hc5 & fetch_ir;
wire inst_bitb_dir              = ir_q == 8'hd5;
wire inst_bitb_idx              = ir_q == 8'he5;
wire inst_bitb_ext              = ir_q == 8'hf5 & fetch_ir;

// Clear Instructions
wire inst_clra                  = ir_q == 8'h4f; // Done 
wire inst_clrb                  = ir_q == 8'h5f; // Done 

wire inst_clr_dir               = ir_q == 8'h0f;
wire inst_clr_idx               = ir_q == 8'h6f;
wire inst_clr_ext               = ir_q == 8'h7f & fetch_ir;

// Compares 
wire inst_cmpa_imm              = ir_q == 8'h81;
wire inst_cmpa_dir              = ir_q == 8'h91;
wire inst_cmpa_idx              = ir_q == 8'ha1;
wire inst_cmpa_ext              = ir_q == 8'hb1 & fetch_ir;

wire inst_cmpb_imm              = ir_q == 8'hc1;
wire inst_cmpb_dir              = ir_q == 8'hd1;
wire inst_cmpb_idx              = ir_q == 8'he1;
wire inst_cmpb_ext              = ir_q == 8'hf1 & fetch_ir;

// Some of the compares take two bytes to decode.
wire inst_cmpd_imm              = ipage[2] & ir_q == 8'h83;
wire inst_cmpd_dir              = ipage[2] & ir_q == 8'h93;
wire inst_cmpd_idx              = ipage[2] & ir_q == 8'ha3;
wire inst_cmpd_ext              = ipage[2] & ir_q == 8'hb3;

wire inst_cmpy_imm              = ipage[2] & ir_q == 8'h8c;
wire inst_cmpy_dir              = ipage[2] & ir_q == 8'h9c;
wire inst_cmpy_idx              = ipage[2] & ir_q == 8'hac;
wire inst_cmpy_ext              = ipage[2] & ir_q == 8'hbc;

wire inst_cmps_imm              = ipage[3] & ir_q == 8'h8c;
wire inst_cmps_dir              = ipage[3] & ir_q == 8'h9c;
wire inst_cmps_idx              = ipage[3] & ir_q == 8'hac;
wire inst_cmps_ext              = ipage[3] & ir_q == 8'hbc;

wire inst_cmpu_imm              = ipage[3] & ir_q == 8'h83;
wire inst_cmpu_dir              = ipage[3] & ir_q == 8'h93;
wire inst_cmpu_idx              = ipage[3] & ir_q == 8'ha3;
wire inst_cmpu_ext              = ipage[3] & ir_q == 8'hb3;

wire inst_cmpx_imm              = ~ipage[2] & ~ipage[3] & ir_q == 8'h8c;
wire inst_cmpx_dir              = ~ipage[2] & ~ipage[3] & ir_q == 8'h9c;
wire inst_cmpx_idx              = ~ipage[2] & ~ipage[3] & ir_q == 8'hac;
wire inst_cmpx_ext              = ~ipage[2] & ~ipage[3] & ir_q == 8'hbc & fetch_ir;

// Complement Instructions
wire inst_coma                  = ir_q == 8'h43;
wire inst_comb                  = ir_q == 8'h53;

wire inst_com_dir               = ir_q == 8'h03;
wire inst_com_idx               = ir_q == 8'h63;
wire inst_com_ext               = ir_q == 8'h73 & fetch_ir;

// CWAI 
wire inst_cwai                   = ir_q == 8'h3c;

// Decimal Adjust 
wire inst_daa                    = ir_q == 8'h19;

// Decrement 
wire inst_deca                  = ir_q == 8'h4a;
wire inst_decb                  = ir_q == 8'h5a;

wire inst_dec_dir               = ir_q == 8'h0a;
wire inst_dec_idx               = ir_q == 8'h6a;
wire inst_dec_ext               = ir_q == 8'h7a & fetch_ir;

// Exclusive Or 
wire inst_eora_imm              = ir_q == 8'h88 & fetch_ir;
wire inst_eora_dir              = ir_q == 8'h98;
wire inst_eora_idx              = ir_q == 8'ha8;
wire inst_eora_ext              = ir_q == 8'hb8 & fetch_ir;

wire inst_eorb_imm              = ir_q == 8'hc8 & fetch_ir;
wire inst_eorb_dir              = ir_q == 8'hd8; 
wire inst_eorb_idx              = ir_q == 8'he8;
wire inst_eorb_ext              = ir_q == 8'hf8 & fetch_ir;

// Increment  
wire inst_inca                  = ir_q == 8'h4c; // Done
wire inst_incb                  = ir_q == 8'h5c; // Done 

wire inst_inc_dir               = ir_q == 8'h0c;
wire inst_inc_idx               = ir_q == 8'h6c;
wire inst_inc_ext               = ir_q == 8'h7c & fetch_ir;

// Jump 
wire inst_jmp_dir               = ir_q == 8'h0e;
wire inst_jmp_idx               = ir_q == 8'h6e;
wire inst_jmp_ext               = ir_q == 8'h7e & fetch_ir;

// Jump to subroutine
wire inst_jsr_dir               = ir_q == 8'h9d;
wire inst_jsr_idx               = ir_q == 8'had;
wire inst_jsr_ext               = ir_q == 8'hbd;

// Many, Many forms of Load
wire inst_lda_imm               = ir_q == 8'h86 & fetch_ir; // Done
wire inst_lda_dir               = ir_q == 8'h96 & fetch_lsu_wait;
wire inst_lda_idx               = ir_q == 8'ha6;
wire inst_lda_ext               = ir_q == 8'hb6 & fetch_ir;

wire inst_ldb_imm               = ir_q == 8'hc6 & fetch_ir ; // Done 
wire inst_ldb_dir               = ir_q == 8'hd6 & fetch_lsu_wait;
wire inst_ldb_idx               = ir_q == 8'he6;
wire inst_ldb_ext               = ir_q == 8'hf6;

wire inst_ldd_imm               = ir_q == 8'hcc & fetch_ir; 
wire inst_ldd_dir               = ir_q == 8'hdc;
wire inst_ldd_idx               = ir_q == 8'hec;
wire inst_ldd_ext               = ir_q == 8'hfc;

wire inst_lds_imm               =  ipage[2] & ir_q == 8'hce & fetch_ir;
wire inst_lds_dir               =  ipage[2] & ir_q == 8'hde;
wire inst_lds_idx               =  ipage[2] & ir_q == 8'hee;
wire inst_lds_ext               =  ipage[2] & ir_q == 8'hfe;

wire inst_ldu_imm               = ~ipage[2] & ir_q == 8'hce & fetch_ir;
wire inst_ldu_dir               = ~ipage[2] & ir_q == 8'hde;
wire inst_ldu_idx               = ~ipage[2] & ir_q == 8'hee;
wire inst_ldu_ext               = ~ipage[2] & ir_q == 8'hfe;

wire inst_ldx_imm               = ~ipage[2] & ir_q == 8'h8e & fetch_ir;
wire inst_ldx_dir               = ~ipage[2] & ir_q == 8'h9e;
wire inst_ldx_idx               = ~ipage[2] & ir_q == 8'hae;
wire inst_ldx_ext               = ~ipage[2] & ir_q == 8'hbe;

wire inst_ldy_imm               =  ipage[2] & ir_q == 8'h8e & fetch_ir;
wire inst_ldy_dir               =  ipage[2] & ir_q == 8'h9e;
wire inst_ldy_idx               =  ipage[2] & ir_q == 8'hae;
wire inst_ldy_ext               =  ipage[2] & ir_q == 8'hbe;

// Load Effective Address 
wire inst_leas                  = ir_q == 8'h32;
wire inst_leau                  = ir_q == 8'h33;
wire inst_leax                  = ir_q == 8'h30;
wire inst_leay                  = ir_q == 8'h31;

// Logical Shift Left is the same thing as 
// Arithmetic shift left. 

// Logical Shift Right
wire inst_lsra                  = ir_q == 8'h44;
wire inst_lsrb                  = ir_q == 8'h54;

wire inst_lsr_dir               = ir_q == 8'h04;
wire inst_lsr_idx               = ir_q == 8'h64;
wire inst_lsr_ext               = ir_q == 8'h74;

// Multiply 
wire inst_mul                   = ir_q == 8'h3d;

// Negate 
wire inst_nega                  = ir_q == 8'h40;
wire inst_negb                  = ir_q == 8'h50;

wire inst_neg_dir               = ir_q == 8'h00 & fetch_ir;
wire inst_neg_idx               = ir_q == 8'h60;
wire inst_neg_ext               = ir_q == 8'h70;

// NOP 
wire inst_nop                   = ir_q == 8'h12;

// Or  
wire inst_ora_imm               = ir_q == 8'h8a & fetch_ir;
wire inst_ora_dir               = ir_q == 8'h9a;
wire inst_ora_idx               = ir_q == 8'haa;
wire inst_ora_ext               = ir_q == 8'hba;

wire inst_orb_imm               = ir_q == 8'hca & fetch_ir;
wire inst_orb_dir               = ir_q == 8'hda;
wire inst_orb_idx               = ir_q == 8'hea;
wire inst_orb_ext               = ir_q == 8'hfa & fetch_ir;

wire inst_orcc                  = ir_q == 8'h1a;

// Pushes   
wire inst_pshs                  = ir_q == 8'h34;
wire inst_pshu                  = ir_q == 8'h36;

// Pulls   
wire inst_puls                  = ir_q == 8'h35;
wire inst_pulu                  = ir_q == 8'h37;

// Rotate Left 
wire inst_rola                  = ir_q == 8'h49;
wire inst_rolb                  = ir_q == 8'h59;

wire inst_rol_dir               = ir_q == 8'h09;
wire inst_rol_idx               = ir_q == 8'h69;
wire inst_rol_ext               = ir_q == 8'h79;

// Rotate Right  
wire inst_rora                  = ir_q == 8'h46;
wire inst_rorb                  = ir_q == 8'h56;

wire inst_ror_dir               = ir_q == 8'h06;
wire inst_ror_idx               = ir_q == 8'h66;
wire inst_ror_ext               = ir_q == 8'h76;

// Return from Interrupt 
wire inst_rti                   = ir_q == 8'h3b;

// Return from Subroutine 
wire inst_rts                   = ir_q == 8'h39;

// Subtract with Carry 
wire inst_sbca_imm              = ir_q == 8'h82 & fetch_ir;
wire inst_sbca_dir              = ir_q == 8'h92;
wire inst_sbca_idx              = ir_q == 8'ha2;
wire inst_sbca_ext              = ir_q == 8'hb2;

wire inst_sbcb_imm              = ir_q == 8'hc2 & fetch_ir;
wire inst_sbcb_dir              = ir_q == 8'hd2; 
wire inst_sbcb_idx              = ir_q == 8'he2;
wire inst_sbcb_ext              = ir_q == 8'hf2;

// Sign Extend 
wire inst_sex                   = ir_q == 8'h1d;

// The many forms of store. 
wire inst_sta_dir               = ir_q == 8'h97;
wire inst_sta_idx               = ir_q == 8'ha7;
wire inst_sta_ext               = ir_q == 8'hb7;

wire inst_stb_dir               = ir_q == 8'hd7;
wire inst_stb_idx               = ir_q == 8'he7;
wire inst_stb_ext               = ir_q == 8'hf7;

wire inst_std_dir               = ir_q == 8'hdd;
wire inst_std_idx               = ir_q == 8'hed;
wire inst_std_ext               = ir_q == 8'hfd;

wire inst_sts_dir               =  ipage[2] & ir_q == 8'hdf;
wire inst_sts_idx               =  ipage[2] & ir_q == 8'hef;
wire inst_sts_ext               =  ipage[2] & ir_q == 8'hff;

wire inst_stu_dir               = ~ipage[2] & ir_q == 8'hdf;
wire inst_stu_idx               = ~ipage[2] & ir_q == 8'hef;
wire inst_stu_ext               = ~ipage[2] & ir_q == 8'hff;

wire inst_stx_dir               = ~ipage[2] & ir_q == 8'h9f;
wire inst_stx_idx               = ~ipage[2] & ir_q == 8'haf;
wire inst_stx_ext               = ~ipage[2] & ir_q == 8'hbf;

wire inst_sty_dir               =  ipage[2] & ir_q == 8'h9f;
wire inst_sty_idx               =  ipage[2] & ir_q == 8'haf;
wire inst_sty_ext               =  ipage[2] & ir_q == 8'hbf;

// Subtract without  Carry 
wire inst_suba_imm              = ir_q == 8'h80 & fetch_ir;
wire inst_suba_dir              = ir_q == 8'h90;
wire inst_suba_idx              = ir_q == 8'ha0;
wire inst_suba_ext              = ir_q == 8'hb0;

wire inst_subb_imm              = ir_q == 8'hc0 & fetch_ir;
wire inst_subb_dir              = ir_q == 8'hd0; 
wire inst_subb_idx              = ir_q == 8'he0;
wire inst_subb_ext              = ir_q == 8'hf0;

wire inst_subd_imm              = ~ipage[2] & ~ipage[3] & ir_q == 8'h83;
wire inst_subd_dir              = ~ipage[2] & ~ipage[3] & ir_q == 8'h93; 
wire inst_subd_idx              = ~ipage[2] & ~ipage[3] & ir_q == 8'ha3;
wire inst_subd_ext              = ~ipage[2] & ~ipage[3] & ir_q == 8'hb3;

// Various forms of SWI 
wire inst_swi                   = ~ipage[2] & ~ipage[3] & ir_q == 8'h3f;
wire inst_swi2                  = ipage[2] &ir_q == 8'h3f;
wire inst_swi3                  = ipage[3] &ir_q == 8'h3f;

// Sync 
wire inst_sync                  = ir_q == 8'h13;

// Transfer 
wire inst_tfr_imm               = ir_q == 8'h1f;

// Test  
wire inst_tsta                  = ir_q == 8'h4d;
wire inst_tstb                  = ir_q == 8'h5d;

wire inst_tst_dir               = ir_q == 8'h0d;
wire inst_tst_idx               = ir_q == 8'h6d;
wire inst_tst_ext               = ir_q == 8'h7d;

// ------------------------------------------------------------
// ------------------------------------------------------------
// Instruction set metadata.  These apply to already fetched 
// instruction data. Note that these signals need to persist 
// througout the instruction cycle.
// ------------------------------------------------------------
// ------------------------------------------------------------

wire inst_amode_inh = 
  ir_q[7:4] == 4'h1 |
  ir_q[7:4] == 4'h4 |
  ir_q[7:4] == 4'h5; 
   
wire inst_amode_imm = 
  ir_q[7:4] == 4'h2 |       // Short Branches.
  ir_q[7:3] == 5'b1000_0  | // 8[0-7] 
  ir_q[7:2] == 6'b1000_10 | // 8[8-b]
  ir_q[7:0] == 8'h8d      | //    
  ir_q[7:3] == 5'b1100_0;
    
wire inst_amode_im2 = 
  ir_q[7:3] == 5'b1100_1  |  // C[8-F]
  ir_q[7:1] == 7'b1000_111 ; // 8[EF]  

// There are two direct modes - 8 & 16
// lda = 96, ldb=d6  
wire inst_amode_dir1 =
  ir_q[7:4] == 4'h9  | // 9[0-f] 
  ir_q[7:4] == 4'hd    // d[0-f]
  ;

// There are two direct modes - 8 & 16
// ldd=dc, lds=10de, ldu=de ldx=9e ldy=109e  
wire inst_amode_dir2 = 0; 
//  inst_ldd_dir | inst_lds_dir | inst_ldx_dir | inst_ldy_dir | inst_ldu_dir
//  ; 

  
wire inst_amode_idx = ir_q[7:4] == 4'ha | ir_q[7:4] == 4'he; // 2+ Bytes  

wire inst_amode_ext = ir_q[7:4] == 4'hb | ir_q[7:4] == 4'hf; // 3 Bytes  

// ------------------------------------------------------------
// ------------------------------------------------------------
// Fetch/Branch Classifier
// Control the first step of the fetch/branch state machine
// The sorted list of opcodes is very helpful. 
// We only need to look at DIN for the first operation so 
// that we can spot immediate operators
// ------------------------------------------------------------
// ------------------------------------------------------------

wire fc_imm = 
  din[7:4] == 4'h4        | // 4[0-f]
  din[7:4] == 4'h5          // 5[0-f]
  ;

wire fc_ext = din[7:1] == 7'b0001_000; // Extended Instructions
    
//wire fc_r2 = 
//  din[7:4] == 4'h0        | // 0[-f]
//  din[7:1] == 7'b0001_001 | // 1[23]
//  din[7:0] == 8'b0001_1100| // 1[C]
//  din[7:0] == 8'b0001_1101| // 1[D]
//  din[7:1] == 7'b0001_1110| // 1[EF]
//  din[7:4] == 4'h2        | // 2[0-F]   Short Branches.
//  din[7:3] == 5'b1000_0   | // 8[0-7] 
//  din[7:2] == 6'b1000_10  | // 8[8-b]
//  din[7:3] == 4'b1001     | // 9[0-f] 
//  din[7:3] == 4'b1101     | // d[0-f]    
//  din[7:3] == 5'b1100_0     // c[0-7]
//  ;
  
// 3 Byte Read 
//wire fc_r3 = 
//  din[7:1] == 7'b0001_101 | // 1[ab]
//  din[7:2] == 6'b0001_01  | // 1[4-7]
//  din[7:3] == 5'b1100_1   | // c[8-f]
//  din[7:1] == 7'b1000_111   // 8[ef]
//  ;  

// ------------------------------------------------------------------------
// ------------------------------------------------------------------------
// Arithmetic Logic Unit and Condition Codes
// Run everything though an ALU so that its 
// easier to capture condition codes. 
// 
// Two ALUs - 8 and 16
// Double length Instructions
// addd cmp ldd/s/u/x/y leas/u/x/y std subd  
// ------------------------------------------------------------------------
// ------------------------------------------------------------------------

// ---------------------------------------------------------
// 8-Bit ALU 
// ---------------------------------------------------------

// Input From A, Output to A 
wire alu8_in0_a = 
  inst_adca_imm | inst_adca_dir | inst_adca_idx | inst_adca_ext | inst_adda_imm |
  inst_adda_dir | inst_adda_idx | inst_adda_ext | inst_anda_imm | inst_anda_dir |
  inst_anda_idx | inst_anda_ext | inst_asla     | inst_asra     | inst_bita_imm | inst_bita_dir |
  inst_bita_idx | inst_bita_ext | inst_cmpa_imm | inst_cmpa_dir | inst_cmpa_idx |
  inst_cmpa_ext | inst_coma     | inst_daa      | inst_deca     | inst_eora_imm | inst_eora_dir |
  inst_eora_idx | inst_eora_ext | inst_inca     |
  inst_lda_idx  | inst_lda_ext  | inst_lsra     | inst_nega     | inst_ora_imm  | inst_ora_dir |
  inst_ora_idx  | inst_ora_ext  | inst_rola     | inst_rola     | inst_rora     | inst_sbca_imm |
  inst_sbca_dir | inst_sbca_idx | inst_sbca_ext | inst_sta_dir  | inst_sta_idx  | inst_sta_ext |
  inst_suba_imm | inst_suba_dir | inst_suba_idx | inst_suba_ext | inst_tsta      
  ; 

// Input LSU, Output to A 
wire alu8_in0_lsu = 
  inst_lda_dir | inst_ldb_dir;

// Input From B, Output to B 
wire alu8_in0_b = 
  inst_adcb_imm | inst_adcb_dir | inst_adcb_idx | inst_adcb_ext | inst_addb_imm |
  inst_addb_dir | inst_addb_idx | inst_addb_ext | inst_andb_imm | inst_andb_dir |
  inst_andb_idx | inst_andb_ext | inst_aslb     | inst_asrb     | inst_bitb_imm | inst_bitb_dir |
  inst_bitb_idx | inst_bitb_ext | inst_cmpb_imm | inst_cmpb_dir | inst_cmpb_idx |
  inst_cmpb_ext | inst_comb     | inst_decb     | inst_eorb_imm | inst_eorb_dir |
  inst_eorb_idx | inst_eorb_ext | inst_incb     |
  inst_ldb_idx  | inst_ldb_ext  | inst_lsrb     | inst_negb     | inst_orb_imm  | inst_orb_dir |
  inst_orb_idx  | inst_orb_ext  | inst_rolb     | inst_rolb     | inst_rorb     | inst_sbcb_imm |
  inst_sbcb_dir | inst_sbcb_idx | inst_sbcb_ext | inst_stb_dir  | inst_stb_idx  | inst_stb_ext |
  inst_subb_imm | inst_subb_dir | inst_subb_idx | inst_subb_ext | inst_tstb 
  ; 

// Pass-through operations 
wire alu8_in0_imm = 
   inst_lda_imm | inst_ldb_imm
  ;

// Immediate Arguments on B input 
wire alu8_in1_imm = 
  inst_adca_imm | inst_adda_imm | inst_anda_imm | inst_bita_imm |
  inst_cmpa_imm | inst_eora_imm | inst_lda_imm  | inst_ora_imm  |
  inst_sbca_imm | inst_suba_imm |

  inst_adcb_imm | inst_addb_imm | inst_andb_imm | inst_bitb_imm |
  inst_cmpb_imm | inst_eorb_imm | inst_ldb_imm  | inst_orb_imm  |
  inst_sbcb_imm | inst_subb_imm
  ;

wire alu8_hot = alu8_in0_a | alu8_in0_b| alu8_in0_imm | alu8_in1_imm | alu8_in0_lsu;

// Output Register destination
wire alu8_dest_a    = alu8_in0_a | inst_lda_imm | inst_lda_dir; 
wire alu8_dest_b    = alu8_in0_b | inst_ldb_imm | inst_ldb_dir; 


// Mux the inputs into ALU Port 0  
wire [7:0] alu8_in0 = 
  {8{alu8_in0_a   }} & a_q  |
  {8{alu8_in0_b   }} & b_q  |
  {8{alu8_in0_imm }} & pb_q |
  {8{alu8_in0_lsu }} & lsu_result[7:0] 
  ;

wire [7:0] alu8_in1 = {
  alu8_in1_imm ? pb_q :
  8'h0 
  };

wire [4:0] alu8_cc;
wire [7:0] alu8_out;

m6809_core_alu8 u_alu8 (
  .alu_in_a(alu8_in0),  // LHS 
  .alu_in_b(alu8_in1),  // RHS
  .op(ir_q[3:0]),     // Operation in 6809 Encoding
  .op7(ir_q[7]),    // Disambiguation bit. 
  .c_in(cc_q[CC_C]),      // Carry In 
  .v_in(cc_q[CC_C]), 
  .h_in(cc_q[CC_H]),
  
  .val_clock(clk),  
   
  .alu_out(alu8_out),      
  .c_out(alu8_cc[0]),   
  .v_out(alu8_cc[1]), 
  .z_out(alu8_cc[2]), 
  .n_out(alu8_cc[3]), 
  .h_out(alu8_cc[4])  
  );

// ---------------------------------------------------------
// 16-Bit ALU.   No Half-Carry support  
// ---------------------------------------------------------

wire  [4:0] alu16_cc;
wire [15:0] alu16_out;

// Pass-through operations 
wire alu16_in0_imm = 
   inst_ldd_imm | inst_lds_imm | inst_ldu_imm | inst_ldx_imm | inst_ldy_imm
  ;

wire alu16_hot = alu16_in0_imm;

// Output Register destination
wire alu16_dest_d    = inst_ldd_imm; 
wire alu16_dest_s    = inst_lds_imm; 
wire alu16_dest_u    = inst_ldu_imm; 
wire alu16_dest_x    = inst_ldx_imm; 
wire alu16_dest_y    = inst_ldy_imm; 

wire [15:0] alu16_in0 = {
    alu16_in0_imm ? { pb_q, fetch2_q }  :
    16'h0 
    };

  // wire [15:0] alu16_in1 = 16'b0;

  m6809_core_alu16 u_alu16 (
    .alu_in_a(alu16_in0),  // LHS 
    //.alu_in_b(alu16_in1),  // RHS
    .op(ir_q[3:0]),        // Operation in 6809 Encoding
    .op6(ir_q[6]),         // Disambiguation bit.
    .page2(ipage[2]), 
    .page3(ipage[3]), 
    .c_in(cc_q[CC_C]),      // Carry In 
    .v_in(cc_q[CC_C]), 
    .h_in(cc_q[CC_H]),
    
    .val_clock(clk),  
     
    .alu_out(alu16_out),      
    .c_out(alu16_cc[0]),   
    .v_out(alu16_cc[1]), 
    .z_out(alu16_cc[2]), 
    .n_out(alu16_cc[3]), 
    .h_out(alu16_cc[4])  
    );


// ----------------------------------------------
// ALU Condition Code management.
// ----------------------------------------------
wire [7:0] cc_q_next;

assign cc_q_next[3:0]  = {
  alu8_hot  ?  alu8_cc[3:0] :
  alu16_hot ? alu16_cc[3:0] :
  cc_q[ 3:0]
  };
   
assign cc_q_next[CC_H] = {
  alu8_hot  ?  alu8_cc[4] :
  alu16_hot ? alu16_cc[4] :
  cc_q[CC_H]
  };

// Condition code register bits pass through
assign cc_q_next[CC_E] = cc_q[CC_E];   
assign cc_q_next[CC_F] = cc_q[CC_F];   
assign cc_q_next[CC_I] = cc_q[CC_I];   

// Update the registers.   Tie this into the reset signal.  
always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    cc_q <= 8'b1101_0000;
    end 
  else begin 
    cc_q <= cc_q_next;
    end 
  end

// -------------------------------------------------------------
// -------------------------------------------------------------
// Register file operations 
// -------------------------------------------------------------
// -------------------------------------------------------------

// Support for the transfer opcode.

// ----------- Register A ------------
wire [7:0] a_q_nxt = {
  alu8_dest_a   ? alu8_out :
  inst_ldd_imm ? alu16_out[15:8] :
  a_q 
  };
    
// ----------- Register B ------------
wire [7:0] b_q_nxt = {
  alu8_dest_b   ? alu8_out :
  inst_ldb_imm ? alu8_out :
  inst_ldd_imm ? alu16_out[7:0] :
  b_q 
  };

// ----------- Register X ------------
wire [15:0] x_q_nxt = {
  inst_ldx_imm ? alu16_out[15:0] :
  x_q 
  };

// ----------- Register Y ------------
wire [15:0] y_q_nxt = {
  inst_ldy_imm ? alu16_out[15:0] :
  y_q 
  };


// ----------- Register U ------------
wire [15:0] u_q_nxt = {
  inst_ldu_imm ? alu16_out[15:0] :
  u_q 
  };

// -- Register S (Stack Pointer ) ----
wire [15:0] s_q_nxt = {
  inst_lds_imm ? alu16_out[15:0] :
  s_q 
  };


// ----------- Register S ------------
// PC is managed by the fetcher.

// ----------- Register DP -----------
// DP Appears to only be available via tfr/exc 

// Update the registers.   Tie this into the reset signal.  
always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    a_q  <= 8'h00;    b_q  <= 8'h00;
    dp_q <= 8'hff;
    x_q <= 16'h00;    y_q <= 16'h00;
    u_q <= 16'h00;    s_q <= 16'h00;
    end 
  else begin 
    a_q <= a_q_nxt;
    b_q <= b_q_nxt;
    
    x_q <= x_q_nxt;
    y_q <= y_q_nxt;
    u_q <= u_q_nxt;
    s_q <= s_q_nxt;
    end 
  end

// ------------------------------------------------------------
// Memory Access mux.   Per the data sheet 
// program counter points the the next instruction to be 
// executed.   This subsection covers address generation 
// and the first layer of things that drive it - 
// either the program counter or the LSU
// ------------------------------------------------------------
reg  [15:0] addr_d;

wire        addr_source_i; // Chooses LSU or Instruction fetch. 

assign addr = (
  addr_source_i ? pc_q :
  addr_d
  );

// ------------------------------------------------------------
// Handshake between LSU and instruction fetches
// The Instruction Fetch/Execute system is in charge.
// The LSU Unit owns the address bus.
// ------------------------------------------------------------
// reg [3:0] lsu_load_dest; // Encoded in Transfer/Exchange Form

localparam REG_DEST_PC = 4'b0101;
// wire lsu_load_pc = lsu_load_dest == REG_DEST_PC; 

// ------------------------------------------------------------
// The Load/Store Unit
// Handle data moves separately from instruction fetches.
// The LSU handles the pc fetch at reset.
//
// State machine notes.  
// The LSU will need to handle loads initiated by different instructions
// in a variety of address modes.   There will ultimately be some 
// sort of ALU like construction in here.
//
// The data sheet shows an extra cycle for all of the memory loads 
// That makes sense, because the data we need isn't registered 
// until its too late to update the address bus.
// ------------------------------------------------------------
wire [15:0] addr_d_next;
wire [15:0] addr_d_plus1 = addr_d + 1;
wire [15:0] addr_d_inst; // The address from the instruction side.

reg   [4:0] lsu_state;
wire  [4:0] lsu_state_next;

reg   [7:0] lsu_msb;      // We need to stage this
wire  [7:0] lsu_msb_next; 

wire [15:0] lsu_result; // This gets grabbed by the register.

localparam st_lsu_por_msb         = 5'h01;
localparam st_lsu_por_lsb         = 5'h02;
localparam st_lsu_idle            = 5'h04;
localparam st_lsu_ld_msb          = 5'h08;
localparam st_lsu_ld_lsb          = 5'h10;

wire lsu_por_msb = lsu_state[0];
wire lsu_por_lsb = lsu_state[1];
wire lsu_idle    = lsu_state[2];
wire lsu_ld_msb  = lsu_state[3]; // Initial State
wire lsu_ld_lsb  = lsu_state[4];

// The address bus belongs to the instruction fetch 
// system when the LSU isn't using it.
assign addr_source_i = lsu_idle ;

// The LSU is the only thing that can do writes.
assign data_rw_n = 1'b1; // Default to read.

assign lsu_state_next =
  ( {5{ lsu_por_msb}} & st_lsu_por_lsb                                     ) |
  ( {5{ lsu_por_lsb}} & st_lsu_idle                                        ) |

  ( {5{ lsu_ld_msb}} & st_lsu_ld_lsb                                       ) |
  ( {5{ lsu_ld_lsb}} & st_lsu_idle                                         ) |

  ( {5{ lsu_idle & ~fetch_lsu_turn }} & st_lsu_idle                        ) |  
  ( {5{ lsu_idle &  fetch_lsu_turn & inst_amode_dir1  }} & st_lsu_ld_lsb )
  ;

// Where we're in the idle state, input the next 
assign addr_d_next = 
  ( {16{ lsu_por_msb}} & addr_d_plus1 ) |
  ( {16{ lsu_idle & inst_amode_dir1 }}    & addr_d_inst  ) |
  ( {16{ lsu_ld_msb}} & addr_d_plus1 )
  ;

assign lsu_result = { lsu_msb, din }; // Port memory data straight into register

assign lsu_msb_next = (lsu_ld_msb|lsu_por_msb) ? din : lsu_msb;

always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    lsu_state <= st_lsu_por_msb;
    addr_d    <= 16'hfffe;
    end 
  else begin 
    lsu_state <= lsu_state_next;
    addr_d    <= addr_d_next;
    lsu_msb   <= lsu_msb_next;
    end 
  end

// ------------------------------------------------------------
// ------------------------------------------------------------
// Instruction/Argument Fetch / Branch Control
// Its possible to skip the ir and go directly to execution for
// inherent instructions.   That would create timing delays,
// so pipeline via the ir.   The longest opcode is made up 
// of 4 bytes
//
// States are defined at the top, prior to the instruction decoder
// Note - The address fetcher is closest to the data bus, 
// so its appropriate to look at the input data on the wire.
// One complicating factor is the fact that the IR can 
// conflict with the data on the wire.
// ------------------------------------------------------------
always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    // lsu_load_dest <= REG_DEST_PC; // Fetch the PC first.
    end 
  else begin 
    end 
  end

// We need to do some instruction decode to decide whats next
// After the IR has been loaded, we control the state machine 
// by looking at the already fetched data.
wire fc_multibyte = ~fc_imm & ~fc_ext;

wire [7:0] fetch_state_next = {
  (fetch_wait      &  lsu_ld_msb)    ? st_fetch_wait :
  (fetch_wait      &  lsu_ld_lsb)    ? st_fetch_wait :
  (fetch_wait      &  lsu_por_lsb)   ? st_fetch_ir   :

  // For extended instructions and immediates we 
  // will stay in fetch_ir 
  (fetch_ir       & fc_imm       )     ? st_fetch_ir     : 
  (fetch_ir       & fc_ext       )     ? st_fetch_ir     : 
  (fetch_ir       & fc_multibyte )     ? st_fetch_pb_imm :

  (fetch_pb_imm   & inst_amode_imm ) ? st_fetch_ir    :
  (fetch_pb_imm   & inst_amode_im2 ) ? st_fetch_b2    :
  (fetch_pb_imm   & inst_amode_ext ) ? st_fetch_b2    :
  
  (fetch_pb_imm   & inst_amode_ext  ) ? st_fetch_b2   :
  (fetch_pb_imm   & inst_amode_dir1 ) ? st_fetch_lsu_turn :

  (fetch_lsu_turn & inst_amode_dir1 ) ? st_fetch_lsu_wait : // One Cycle  
  
  (fetch_lsu_wait                   ) ? st_fetch_ir : 
  
  
  (fetch_b2                        ) ? st_fetch_ir :

  fetch_state
};

// Logic to manage the ipage registers. 
// Preserve it when not in fetch_ir
// We need an edge detector to spot the first visit to fetch_ir 
reg fetch_ir_last;
always @(posedge clk) fetch_ir_last <= fetch_ir; 

wire [3:2] ipage_next =
  {2{  fetch_ir & ~fetch_ir_last & fc_ext }} & { din[0], ~din[0] } |
  {2{  fetch_ir &  fetch_ir_last          }} & ipage[3:2]          |
  {2{ ~fetch_ir                           }} & ipage[3:2]
  ;
  
wire [7:0] ir_q_next = fetch_ir     ? din : ir_q;
wire [7:0] pb_q_next = fetch_pb_imm ? din : pb_q;
   
wire [7:0] fetch2_q_next = { 
  fetch_b2 ? din :
  fetch2_q 
  };

// Data Fetch 
assign addr_d_inst = 
  {16{inst_amode_dir1}} & { dp_q, pb_q } 
  ;

always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    ir_q     <=  8'h0;
    ipage    <=  2'b00;
    pb_q     <=  8'b0;
    fetch2_q <= 8'b0; 
    // fetch3_q <= 8'b0;     
    end 
  else begin 
    ir_q     <= ir_q_next;
    ipage    <= ipage_next;
    pb_q     <= pb_q_next;
    fetch2_q <= fetch2_q_next;
    end 
  end

// The system should start up in LSU Mode to fetch the IR.
always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    fetch_state <= st_fetch_wait ;
    end 
  else begin 
    fetch_state <= fetch_state_next;
    end 
  end


//------------------------------------------
// Program Counter/Branch Control 
// This advances when there are no branches.
//------------------------------------------
wire [15:0] pc_q_1     = pc_q + 1;

// Short Branches
wire        inst_sbranch = ir_q[7:4] == 4'h2; 
wire [15:0] pc_q_sbranch = pc_q_1 + { {8{din[7]}} , din};

// Trigger the branch action.
// Note that BRN (21) is a no-op - tested correct.
wire do_branch =
  inst_sbranch & fetch_pb_imm & (
    ( ir_q[3:0] == 4'h0               ) | // BRA
    ( ir_q[3:0] == 4'h4 & ~cc_q[CC_C] ) | // BCC / BHS
    ( ir_q[3:0] == 4'h5 &  cc_q[CC_C] ) | // BCS / BLO
    ( ir_q[3:0] == 4'h6 & ~cc_q[CC_Z] ) | // BNE
    ( ir_q[3:0] == 4'h7 &  cc_q[CC_Z] ) | // BEQ 
    ( ir_q[3:0] == 4'h8 & ~cc_q[CC_V] ) | // BVC
    ( ir_q[3:0] == 4'h9 &  cc_q[CC_V] ) | // BVS
    ( ir_q[3:0] == 4'hA & ~cc_q[CC_N] ) | // BPL
    ( ir_q[3:0] == 4'hB &  cc_q[CC_N] )   // BMI
  ); 

// Increment is the norm.
// Let the PC advance on the step prior to wait.
wire lsu_busy = fetch_lsu_wait;
wire fetch_active = fetch_ir | fetch_pb_imm | fetch_b2 | fetch_b3; 
wire [15:0] pc_q_next = {
  fetch_active                  ? pc_q_1       :
  lsu_por_lsb                   ? lsu_result   :
  lsu_busy                      ? pc_q         :
  ( fetch_pb_imm &  do_branch ) ? pc_q_sbranch :
  pc_q 
  };

always @(posedge clk or negedge reset_b ) begin 
  if ( ~reset_b ) begin 
    pc_q <= 16'b0;
    end 
  else begin 
    pc_q <= pc_q_next;
    end 
  end

// ------------------------------------------------------------------------
// Validation Assertions.
// icarus verilog support "simple immediate assertions"
// ------------------------------------------------------------------------

// Do some sanity checks on every clock 
always @(posedge clk) begin

  // Only one addressing mode at a time.
  assert( (
    inst_amode_inh +
    inst_amode_imm + inst_amode_im2 +
    inst_amode_dir1 + inst_amode_dir2 + inst_amode_idx + inst_amode_ext
    ) <= 1 );

  // Only one fetch class at a time 
  assert( (
      fc_imm + fc_ext
    ) <= 1 );

  // Only one source for each side.
  assert( ( alu8_in0_a + alu8_in0_b + alu8_in0_imm + alu8_in0_lsu ) <= 1 );
  assert( (                          alu16_in0_imm  ) <= 1 );

  assert( (                           alu8_in1_imm  ) <= 1 );
    
  // Only one destination register at a time 
  assert( ( alu8_dest_a + alu8_dest_b ) <= 1 );
  assert( ( alu16_dest_d + alu16_dest_s + alu16_dest_u + alu16_dest_x + alu16_dest_y) <= 1 );

  // Only one alu at at time 
  assert( ( alu8_hot + alu16_hot ) <= 1 );

  // We should never see more than one instruction active at a time.
  assert( ( 
    inst_abx +
    inst_adca_imm + inst_adca_dir + inst_adca_idx + inst_adca_ext +
    inst_adcb_imm + inst_adcb_dir + inst_adcb_idx + inst_adcb_ext +
    inst_adda_imm + inst_adda_dir + inst_adda_idx + inst_adda_ext +
    inst_addb_imm + inst_addb_dir + inst_addb_idx + inst_addb_ext +
    inst_addd_imm + inst_addd_dir + inst_addd_idx + inst_addd_ext +
    inst_anda_imm + inst_anda_dir + inst_anda_idx + inst_anda_ext +
    inst_andb_imm + inst_andb_dir + inst_andb_idx + inst_andb_ext +
    inst_andcc_imm +
    inst_asla + inst_aslb +
    inst_asl_dir + inst_asl_idx + inst_asl_ext +
    inst_asra + inst_asrb +
    inst_asr_dir + inst_asr_idx + inst_asr_ext +
    inst_bra + inst_brn + inst_lbrn +
    inst_bsr + inst_lbsr +
    inst_bmi + inst_bpl + inst_beq + inst_bne + inst_bvs + inst_bvc + inst_bcs + inst_bcc +
    inst_bita_imm + inst_bita_dir + inst_bita_idx + inst_bita_ext +
    inst_bitb_imm + inst_bitb_dir + inst_bitb_idx + inst_bitb_ext +
    inst_clra + inst_clrb +
    inst_clr_dir +
    inst_clr_idx +
    inst_clr_ext +
    inst_cmpa_imm + inst_cmpa_dir + inst_cmpa_idx + inst_cmpa_ext +
    inst_cmpb_imm + inst_cmpb_dir + inst_cmpb_idx + inst_cmpb_ext +
    inst_cmpd_imm + inst_cmpd_dir + inst_cmpd_idx + inst_cmpd_ext +
    inst_cmpy_imm + inst_cmpy_dir + inst_cmpy_idx + inst_cmpy_ext +
    inst_cmps_imm + inst_cmps_dir + inst_cmps_idx + inst_cmps_ext +
    inst_cmpu_imm + inst_cmpu_dir + inst_cmpu_idx + inst_cmpu_ext +
    inst_cmpx_imm + inst_cmpx_dir + inst_cmpx_idx + inst_cmpx_ext +
    inst_coma + inst_comb +
    inst_com_dir + inst_com_idx + inst_com_ext +
    inst_cwai +
    inst_daa +
    inst_deca + inst_decb +
    inst_dec_dir + inst_dec_idx + inst_dec_ext +
    inst_eora_imm + inst_eora_dir + inst_eora_idx + inst_eora_ext +
    inst_eorb_imm + inst_eorb_dir + inst_eorb_idx + inst_eorb_ext +
    inst_inca + inst_incb + 
    inst_inc_dir + inst_inc_idx + inst_inc_ext +
    inst_jmp_dir + inst_jmp_idx + inst_jmp_ext +
    inst_jsr_dir + inst_jsr_idx + inst_jsr_ext +
    inst_lda_imm + inst_lda_dir + inst_lda_idx + inst_lda_ext +
    inst_ldb_imm + inst_ldb_dir + inst_ldb_idx + inst_ldb_ext +
    inst_ldd_imm + inst_ldd_dir + inst_ldd_idx + inst_ldd_ext +
    inst_lds_imm + inst_lds_dir + inst_lds_idx + inst_lds_ext +
    inst_ldu_imm + inst_ldu_dir + inst_ldu_idx + inst_ldu_ext +
    inst_ldx_imm + inst_ldx_dir + inst_ldx_idx + inst_ldx_ext +
    inst_ldy_imm + inst_ldy_dir + inst_ldy_idx + inst_ldy_ext +
    inst_leas + inst_leau + inst_leax + inst_leay +
    inst_lsra + inst_lsrb +
    inst_lsr_dir + inst_lsr_idx + inst_lsr_ext +
    inst_mul +
    inst_nega + inst_negb +
    inst_neg_dir + inst_neg_idx + inst_neg_ext +
    inst_nop +
    inst_ora_imm + inst_ora_dir + inst_ora_idx + inst_ora_ext +
    inst_orb_imm + inst_orb_dir + inst_orb_idx + inst_orb_ext +
    inst_orcc +
    inst_pshs + inst_pshu + inst_puls + inst_pulu +
    inst_rola + inst_rolb +
    inst_rol_dir + inst_rol_idx + inst_rol_ext +
    inst_rora + inst_rorb +
    inst_ror_dir + inst_ror_idx + inst_ror_ext +
    inst_rti + inst_rts +
    inst_sbca_imm + inst_sbca_dir + inst_sbca_idx + inst_sbca_ext +
    inst_sbcb_imm + inst_sbcb_dir + inst_sbcb_idx + inst_sbcb_ext +
    inst_sex +
    inst_sta_dir + inst_sta_idx + inst_sta_ext +
    inst_stb_dir + inst_stb_idx + inst_stb_ext + inst_std_dir +
    inst_std_idx + inst_std_ext +
    inst_sts_dir + inst_sts_idx + inst_sts_ext +
    inst_stu_dir + inst_stu_idx + inst_stu_ext +
    inst_stx_dir + inst_stx_idx + inst_stx_ext +
    inst_sty_dir + inst_sty_idx + inst_sty_ext +
    inst_suba_imm + inst_suba_dir + inst_suba_idx + inst_suba_ext +
    inst_subb_imm + inst_subb_dir + inst_subb_idx + inst_subb_ext +
    inst_subd_imm + inst_subd_dir + inst_subd_idx + inst_subd_ext +
    inst_swi + inst_swi2 + inst_swi3 +
    inst_sync +
    inst_tfr_imm +
    inst_tsta + inst_tstb +
    inst_tst_dir + inst_tst_idx + inst_tst_ext
        
    ) <= 1 );

    // We should never see more than one branch instruction active at a time.
    assert( (
      inst_bra + inst_brn + inst_lbrn + 
      inst_bsr + inst_lbsr +
      inst_bmi + inst_bpl + inst_beq + inst_bne + 
      inst_bvs + inst_bvc + inst_bcs + inst_bcc 
    ) <= 1 );


  end

// -----------------------------------------
// Formal Verification.
// Initial clock assumptions from 
// https://zipcpu.com/blog/2017/10/19/formal-intro.html     
// -----------------------------------------
`ifdef FORMAL

  reg	last_clk_q, past_valid_q;
  
  initial past_valid_q = 1'b0; 

  always @(posedge clk)
    past_valid_q <= 1'b1;
  
  always @(*)
  	if (!past_valid_q)
  		assume(reset_b == 0);
  

`endif






endmodule
