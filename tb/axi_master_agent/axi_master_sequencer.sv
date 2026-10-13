// ==============================================================================
// File: axi_master_sequencer.sv
// Description: UVM sequencer parameterized with axi_master_item.
// ==============================================================================

`ifndef AXI_MASTER_SEQUENCER_SV
`define AXI_MASTER_SEQUENCER_SV

class axi_master_sequencer extends uvm_sequencer #(axi_master_item);
  `uvm_component_utils(axi_master_sequencer)

  function new(string name = "axi_master_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

endclass : axi_master_sequencer

`endif // AXI_MASTER_SEQUENCER_SV
