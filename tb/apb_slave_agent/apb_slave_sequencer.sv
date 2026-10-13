// ==============================================================================
// File: apb_slave_sequencer.sv
// Description: UVM sequencer parameterized with apb_slave_item.
// ==============================================================================

`ifndef APB_SLAVE_SEQUENCER_SV
`define APB_SLAVE_SEQUENCER_SV

class apb_slave_sequencer extends uvm_sequencer #(apb_slave_item);
  `uvm_component_utils(apb_slave_sequencer)

  function new(string name = "apb_slave_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

endclass : apb_slave_sequencer

`endif // APB_SLAVE_SEQUENCER_SV
