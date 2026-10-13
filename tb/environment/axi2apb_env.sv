// ==============================================================================
// File: axi2apb_env.sv
// Description: UVM environment container for AXI4-to-APB bridge verification.
//              Instantiates AXI master agent, APB slave agent, and transaction-level
//              scoreboard, wiring their analysis ports together.
// ==============================================================================

`ifndef AXI2APB_ENV_SV
`define AXI2APB_ENV_SV

class axi2apb_env extends uvm_env;
  `uvm_component_utils(axi2apb_env)

  axi_master_agent   axi_agent;
  apb_slave_agent    apb_agent;
  axi2apb_scoreboard scoreboard;

  function new(string name = "axi2apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), "build_phase: constructing verification environment components", UVM_LOW)

    axi_agent  = axi_master_agent::type_id::create("axi_agent", this);
    apb_agent  = apb_slave_agent::type_id::create("apb_agent", this);
    scoreboard = axi2apb_scoreboard::type_id::create("scoreboard", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_type_name(), "connect_phase: connecting agent monitor analysis ports to scoreboard", UVM_LOW)

    // Connect AXI and APB agent analysis ports to the scoreboard exports
    axi_agent.analysis_port.connect(scoreboard.axi_export);
    apb_agent.analysis_port.connect(scoreboard.apb_export);
  endfunction : connect_phase

endclass : axi2apb_env

`endif // AXI2APB_ENV_SV
