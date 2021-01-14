# A 6809 Clone in Verilog 

The 6809 is fairly clean 8-bit MCU.

# Integration 

# Design

The original device uses two clocks.   This is a one clock syncronous design.  

# Organization

The project consists of an integration layer, with ports that are generally 
similar to what you'd see on an actual IC.  

Since this is a memory-mapped device, the peripherals are spliced in to the memory layer.

# Design Concepts
The VHDL simulator thats out there on the web uses a state machine with decode.

This is a state machine.  The instruction set looks somewhat random in the big list,
but the programmers reference makes thing more clear.   

# Simulation 

Basic simulation with Icarus Verilog.  

```iverilog -o tb_m6809reset -s tb_6809reset   core6809.v rom-boot.v m6809_integration.v tb_m6809reset.v  && vvp tb_m6809reset```

```iverilog -gsupported-assertions -g2012  -o tb_m6809reset -s tb_6809reset   core6809.v rom-boot.v m6809_integration.v tb_m6809reset.v  && vvp tb_m6809reset```

# Resources of note

There are many, many things online.  

Pointers to compilers, assemblers, etc: http://www.brouhaha.com/~eric/embedded/6809/#fpga

Original datasheet (via Wikipedia page) here: https://archive.org/details/bitsavers_motorolada_3224333/page/n7/mode/2up 

The data sheet contains a useful section called the 'Programmers Aid' that 
has a very useful table of instruction.

HTML Version of the programmers guide - Instruction reference: http://atjs.mbnet.fi/mc6809/Information/6809.htm
