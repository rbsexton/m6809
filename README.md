# A 6809 Clone in Verilog 

The 6809 is fairly clean 8-bit MCU with rich addressing modes.

These files are Copyright(C) 2021 by Robert Sexton, robert@kudra.com.  Non-Commercial 
and educational use only.

# Project Organization

The CPU itself is in *m6809_core.v*.  It has ports that are similar to the ones 
on a 6809 MCU.  

The integration module, *m6809_integration.v* connects the CPU Core to memories
and peripherals.  

# Design Concepts

The original device uses two clocks.   This is a one clock synchronous design.  

The CPU consists of two interlocked state machines for memory load/store and 
instruction fetch.  That was easier to understand than a single large state machine.

The instruction execution logic is controlled by registered data.   The Fetch/Branch 
code looks at the instructions as they traverse the data bus.

The rest of the design is made up of combinatorial logic. 

The instruction set looks somewhat random in the big list.  The patterns are 
clearer in the the programmers reference.

Things work better if all data passes through the ALU because the ALU owns the 
condition codes register. 

# Simulation

## Simulation with Icarus Verilog.  

```
iverilog -o tb_m6809reset -s tb_6809reset   core6809.v rom-boot.v m6809_integration.v tb_m6809reset.v  && vvp tb_m6809reset

iverilog -gsupported-assertions -g2012  -o tb_m6809 -s tb_6809   m6809_core.v m6809_core_alu8.v m6809_core_alu16.v mem-ram.v mem-rom.v m6809_integration.v tb_m6809.v  && vvp tb_m6809```

iverilog -gsupported-assertions -g2012  -o tb_m6809_core_regmove  -s tb_m6809_core_regmove  m6809_core_regmove_integration.v tb_m6809_core_regmove.v m6809_core_regmove.v mem_ram.v && vvp tb_m6809_core_regmove
```


## Simulation with Verilator

There is a makefile and main.cpp file in *sim/*.   The Verilator git repository 
contains some helpful examples.   

There is a good tutorial on EmbEcosm with some examples of how to bring the verilog state information out to simulator so you can display them and run real code on the simulated CPU -  [EmbEcosm](https://www.embecosm.com/appnotes/ean6/embecosm-or1k-verilator-tutorial-ean6-issue-1.html)

Gisselquist also has examples, but they are a bit out of date 
and closely coupled to the ZipCPU work.  The Verilator examples 
from the offical github repository were easier to work with. (2021)

## Formal Verification with yosys

Yosys can spot logic errors that don't appear in simulation.   Its good at finding instruction decode issues.   The biggest challenge 
is writing assertions.

There is a yosys control file for verification, m6809_core.sby:

```
$ sby -f m6809_core.sby
# If it fails: 
# Open m6809_core/engine_0/trace.vcd with gtkwave or similar.
```


# Resources of note

There are many, many things online.  

Pointers to compilers, assemblers, etc: http://www.brouhaha.com/~eric/embedded/6809/#fpga

Original datasheet (via Wikipedia page) here: https://archive.org/details/bitsavers_motorolada_3224333/page/n7/mode/2up 

The data sheet contains a useful section called the 'Programmers Aid' that 
has a very useful table of instructions.

Dave Dunfield scanned the original Motorola Programming Manual (m6809prog.pdf)
thats the definitive reference on the device.

HTML Version of the programmers guide - Instruction reference: http://atjs.mbnet.fi/mc6809/Information/6809.htm

# Instruction Support 

## Supported
- asla aslb
- asra asrb
- clra clrb
- bra brn
- beq bne bvs bvc bcs bcc bmi bpl 
- coma comb
- eora_imm 
- eorb_imm 
- inca incb
- lda_imm ldb_imm lds_imm ldy_imm ldd_imm ldu_imm ldx_imm
- lda_dir ldb_dir
- lsra lsrb
- ora_imm orb_imm
- rola rolb
- rora rorb

## Unsupported   

- adca_imm adca_dir adca_idx adca_ext
- adcb_imm adcb_dir adcb_idx adcb_ext
- adda_imm adda_dir adda_idx adda_ext
- addb_imm addb_dir addb_idx addb_ext
- addd_imm addd_dir addd_idx addd_ext
- anda_imm anda_dir anda_idx anda_ext
- andb_imm andb_dir andb_idx andb_ext
- andcc_imm
- asl_dir asl_idx asl_ext
- asr_dir asr_idx asr_ext
- lbrn
- bsr lbsr beq bne, and signed branches  
- bita_imm bita_dir bita_idx bita_ext
- bitb_imm bitb_dir bitb_idx bitb_ext
- clr_dir clr_idx clr_ext
- cmpa_imm cmpa_dir cmpa_idx cmpa_ext
- cmpb_imm cmpb_dir cmpb_idx cmpb_ext
- cmpd cmpd_imm cmpd_dir cmpd_idx cmpd_ext
- cmpy cmpy_imm cmpy_dir cmpy_idx cmpy_ext
- cmps cmps_imm cmps_dir cmps_idx cmps_ext
- cmpu cmpu_imm cmpu_dir cmpu_idx cmpu_ext
- cmpx_imm cmpx_dir cmpx_idx cmpx_ext
- com_dir com_idx com_ext
- cwai
- daa
- deca decb
- dec_dir dec_idx dec_ext
- eora_dir eora_idx eora_ext
- eorb_dir eorb_idx eorb_ext
- inc_dir inc_idx inc_ext
- jmp_dir jmp_idx jmp_ext
- jsr_dir jsr_idx jsr_ext
- lda_idx lda_ext
- ldb_idx ldb_ext
- ldd_dir ldd_idx ldd_ext
- lds_dir lds_idx lds_ext
- ldu_dir ldu_idx ldu_ext
- ldx_dir ldx_idx ldx_ext
- ldy_dir ldy_idx ldy_ext
- leas leau leax leay
- lsr_dir lsr_idx lsr_ext
- mul
- nega negb
- neg_dir neg_idx neg_ext
- nop
- ora_dir ora_idx ora_ext
- orb_dir orb_idx orb_ext
- orcc
- pshs pshu
- puls pulu
- rol_dir rol_idx rol_ext
- ror_dir ror_idx ror_ext
- rti
- rts
- sbca_imm sbca_dir sbca_idx sbca_ext
- sbcb_imm sbcb_dir sbcb_idx sbcb_ext
- sex
- sta_dir sta_idx sta_ext
- stb_dir stb_idx stb_ext 
- std_dir std_idx std_ext
- sts sts_dir sts_idx sts_ext
- stu_dir stu_idx stu_ext
- stx_dir stx_idx stx_ext
- sty sty_dir sty_idx sty_ext
- suba_imm suba_dir suba_idx suba_ext
- subb_imm subb_dir subb_idx subb_ext
- subd_imm subd_dir subd_idx subd_ext
- swi swi2 swi3
- sync 
- tfr_imm
- tsta tstb
- tst_dir tst_idx tst_ext
 
# Future Development 

- Support halt_b with clock gating.
- DMA Req/Ack 
- Wait States 
- Wide data bus? 

Much, much to do.
- Support EXC/TFR to load the DP register
- Support LD on all registers in immediate mode
- Store direct 
- Support LD on all registers in direct mode
- Support LD on all registers in extended direct mode
- Push/Pop




