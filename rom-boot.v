// Emulate an external async memory
// This module is only large enough to contain the reset vectors and a 
// very, very small amount of code.


module rom_boot (
  input  wire       sel,
  input  wire [3:0] a,
  output wire [7:0] dout
  );

// This does not need to be clocked.

assign dout = {
  a == 4'h0 ? 8'h4f : // CLRA  
  a == 4'h1 ? 8'h4c : // Inc A
  a == 4'h2 ? 8'h5c : // Inc B 
  a == 4'h3 ? 8'h12 : // NOP
  a == 4'h4 ? 8'h12 :
  a == 4'h5 ? 8'h12 :
  a == 4'h6 ? 8'h12 :
  a == 4'h7 ? 8'h12 :
  a == 4'h8 ? 8'h12 :
  a == 4'h9 ? 8'h12 :
  a == 4'hA ? 8'h00 :
  a == 4'hB ? 8'h00 :
  a == 4'hC ? 8'h00 :
  a == 4'hD ? 8'h00 :
  a == 4'hE ? 8'hff :
              8'hf0  // 0xf
  };

endmodule