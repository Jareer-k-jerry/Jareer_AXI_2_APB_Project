// ==============================================================================
// File: apb_slave_agent.sv
// Description: UVM agent container for APB slave verification components.
//              Encapsulates sequencer, driver, monitor, and configuration.
// ==============================================================================

`ifndef APB_SLAVE_AGENT_SV
`define APB_SLAVE_AGENT_SV

class apb_slave_agent extends uvm_agent;
  `uvm_component_utils(apb_slave_agent)

  apb_slave_sequencer                 sequencer;
  apb_slave_driver                    driver;
  apb_slave_monitor                   monitor;
  apb_slave_config                    cfg;
  uvm_analysis_port #(apb_slave_item) analysis_port;

  function new(string name = "apb_slave_agent", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(apb_slave_config)::get(this, "", "cfg", cfg)) begin
      cfg = apb_slave_config::type_id::create("cfg");
    end

    // Monitor is always instantiated
    monitor = apb_slave_monitor::type_id::create("monitor", this);

    // Driver and sequencer instantiated only when active
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = apb_slave_sequencer::type_id::create("sequencer", this);
      driver    = apb_slave_driver::type_id::create("driver", this);
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end

    monitor.analysis_port.connect(this.analysis_port);
  endfunction : connect_phase

endclass : apb_slave_agent

`endif // APB_SLAVE_AGENT_SV
