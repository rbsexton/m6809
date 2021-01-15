# A 6809 Clone in Verilog 

The 6809 is fairly clean 8-bit MCU with rich addressing modes.  

# Project Organization

The CPU itself is in *m6809_core.v*.  It has ports that are similar to the ones 
on a 6809 MCU.  

The integration module, *m6809_integration.v* connects the CPU Core to memories
and peripherals.  

# Design Concepts

The original device uses two clocks.   This is a one clock synchronous design.  

The CPU consists of two interlocked state machines for memory load/store and 
instruction fetch.  That was easier to understand than a single large state machine.

The rest of the design is made up of combinatorial logic. 

The instruction set looks somewhat random in the big list.  The patterns are 
clearer in the the programmers reference.

Things work better if all data passes through the ALU because the ALU owns the 
condition codes register. 

# Simulation 

Basic simulation with Icarus Verilog.  

```iverilog -o tb_m6809reset -s tb_6809reset   core6809.v rom-boot.v m6809_integration.v tb_m6809reset.v  && vvp tb_m6809reset```

```iverilog -gsupported-assertions -g2012  -o tb_m6809 -s tb_6809   m6809_core.v mem-ram.v mem-rom.v m6809_integration.v tb_m6809.v  && vvp tb_m6809```

# Resources of note

There are many, many things online.  

Pointers to compilers, assemblers, etc: http://www.brouhaha.com/~eric/embedded/6809/#fpga

Original datasheet (via Wikipedia page) here: https://archive.org/details/bitsavers_motorolada_3224333/page/n7/mode/2up 

The data sheet contains a useful section called the 'Programmers Aid' that 
has a very useful table of instruction.

HTML Version of the programmers guide - Instruction reference: http://atjs.mbnet.fi/mc6809/Information/6809.htm
