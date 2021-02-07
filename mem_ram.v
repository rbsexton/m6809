`timescale 1ns / 1ps
// Emulate an external sync memory.

module mem_ram (

  input  wire clk,
  input  wire sel,
  input  wire wr_n,
  
  input  wire  [7:0] a,

  output wire  [7:0] dout,
  input  wire  [7:0] din
  );

  reg [7:0] mem [255:0];

always @(posedge clk) begin
  if ( ~wr_n & sel ) mem[a] <= din;
  end
  
assign dout = mem[a];   

initial begin 
  mem[0] = 8'hff;
  mem[1] = 8'b0;
  mem[2] = 8'b0;
  mem[3] = 8'b0;
  

  end 


endmodule