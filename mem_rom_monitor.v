`timescale 1ns / 1ps
// Emulate an external async memory
// This file contains 2k of code, loaded via 
// the verilog load command.
// hexdump -v -e '"   mem[%_ad]=" 1/1 "8Xh%02X" ";\n"'  monitor.bin | sed s/X/\'/ > rom-include.v

module mem_rom_monitor (
  input  wire       sel,
  input  wire [12:0] a,
  output wire [7:0] dout
  );

// This does not need to be clocked.
reg [7:0] mem [8191:0];


//  $display("Loading monitor");
//  $readmemb("monitor.mem", memory);
//

initial begin
 `include "rom-include.v" 
 end 

assign dout = sel ? mem[a] : 8'b0; 

endmodule