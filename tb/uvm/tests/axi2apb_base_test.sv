// ==============================================================================
// File: axi2apb_base_test.sv
// Description: Common base test class providing standard environment construction,
//              virtual interface handles, and topology printing.
// ==============================================================================

`ifndef AXI2APB_BASE_TEST_SV
`define AXI2APB_BASE_TEST_SV

class axi2apb_base_test extends uvm_test;
  `uvm_component_utils(axi2apb_base_test)

  axi2apb_env      env;
  axi_master_agent axi_agent;
  apb_slave_agent  apb_agent;

  virtual axi4_if  axi_vif;
  virtual apb_if   apb_vif;

  function new(string name = "axi2apb_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi2apb_env::type_id::create("env", this);

    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "axi_vif", axi_vif));
    void'(uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", apb_vif));
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    axi_agent = env.axi_agent;
    apb_agent = env.apb_agent;
  endfunction : connect_phase

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    if (uvm_report_enabled(UVM_HIGH, UVM_INFO, get_type_name())) begin
      `uvm_info(get_type_name(), "=== UVM Component Topology ===", UVM_HIGH)
      uvm_top.print_topology();
    end
  endfunction : end_of_elaboration_phase

endclass : axi2apb_base_test

`endif // AXI2APB_BASE_TEST_SV
