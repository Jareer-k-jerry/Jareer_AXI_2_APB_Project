// ==============================================================================
// File: apb_slave_config.sv
// Description: Configuration class for APB slave agent.
// ==============================================================================

`ifndef APB_SLAVE_CONFIG_SV
`define APB_SLAVE_CONFIG_SV

class apb_slave_config extends uvm_object;
  `uvm_object_utils(apb_slave_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit          enable_memory_model  = 1'b1;
  int unsigned default_wait_cycles  = 0;
  bit          default_error_inject = 1'b0;

  function new(string name = "apb_slave_config");
    super.new(name);
  endfunction : new

endclass : apb_slave_config

`endif // APB_SLAVE_CONFIG_SV
