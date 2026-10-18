// ==============================================================================
// File: axi2apb_virtual_sequencer.sv
// Description: UVM Virtual Sequencer coordinating AXI Master and APB Slave
//              sub-sequencers for cross-protocol synchronized stimulus generation.
// ==============================================================================

`ifndef AXI2APB_VIRTUAL_SEQUENCER_SV
`define AXI2APB_VIRTUAL_SEQUENCER_SV

class axi2apb_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(axi2apb_virtual_sequencer)

  // Target Sub-Sequencer Handles
  axi_master_sequencer axi_seqr;
  apb_slave_sequencer  apb_seqr;

  function new(string name = "axi2apb_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

endclass : axi2apb_virtual_sequencer

`endif // AXI2APB_VIRTUAL_SEQUENCER_SV
