// Integration layer that interfaces with the outside world.
// This should roughly correspond to the SOC itself 
//
// General Notes.
// This is a big-endian device.
//
// This file is Copyright(C) 2021 by Robert Sexton
// Non-commercial use only 


module m6809_integration (

  input              reset_b,       // Active Low Reset 
  input              clk,           // Clock 

  input              halt_b         // Terminate after the current instruction.
    
  );

// --------------------------------------------------------------------
// --------------------------------------------------------------------
wire [15:0] address;
wire [ 7:0] core_data_out;
wire [ 7:0] core_data_in;

wire        data_rw_n;

// --------------------------------------------------------------------
// Ram/Rom here
// --------------------------------------------------------------------

// Divide the memory space in half
wire sel_rom =  address[15];
wire sel_ram = ~address[15];

wire [ 7:0] core_data_in_rom;
wire [ 7:0] core_data_in_ram;

// Mux data from memory devices.
assign core_data_in = {
  sel_rom ? core_data_in_rom :
  core_data_in_ram
  };

rom_boot u_rom (
  .sel                   (sel_rom),
  .a                     (address[7:0]),
  .dout                  (core_data_in_rom)
  );

ram u_ram (
  .clk                   (clk), 
  .sel                   (sel_ram),
  .a                     (address[7:0]),
  .dout                  (core_data_in_ram),
  .din                   (core_data_out)
  );

// --------------------------------------------------------------------
// Instantiate the core.
// --------------------------------------------------------------------
m6809_core ucore ( 
  .reset_b               (reset_b),
  .clk                   (clk),
  .halt_b                (halt_b),
  
  .addr                  (address),
  .din                   (core_data_in),
  .data_out              (core_data_out),
  .data_rw_n             (data_rw_n)
  );
  
endmodule