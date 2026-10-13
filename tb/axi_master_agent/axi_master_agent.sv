// ==============================================================================
// File: axi_master_agent.sv
// Description: UVM agent container for AXI master verification components.
//              Encapsulates sequencer, driver, and monitor.
// ==============================================================================

`ifndef AXI_MASTER_AGENT_SV
`define AXI_MASTER_AGENT_SV

class axi_master_agent extends uvm_agent;
  `uvm_component_utils(axi_master_agent)

  axi_master_sequencer                 sequencer;
  axi_master_driver                    driver;
  axi_master_monitor                   monitor;
  uvm_analysis_port #(axi_master_item) analysis_port;

  function new(string name = "axi_master_agent", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always instantiated
    monitor = axi_master_monitor::type_id::create("monitor", this);

    // Driver and Sequencer instantiated only when active
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = axi_master_sequencer::type_id::create("sequencer", this);
      driver    = axi_master_driver::type_id::create("driver", this);
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end

    monitor.analysis_port.connect(this.analysis_port);
  endfunction : connect_phase

endclass : axi_master_agent

`endif // AXI_MASTER_AGENT_SV
