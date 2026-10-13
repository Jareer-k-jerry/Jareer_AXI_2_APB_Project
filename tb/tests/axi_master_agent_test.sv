// ==============================================================================
// File: axi_master_agent_test.sv
// Description: Directed test to validate Phase 2 AXI master agent integration.
//              Instantiates the AXI master agent, initiates a directed write
//              sequence followed by a directed read sequence, and verifies completion.
// ==============================================================================

`ifndef AXI_MASTER_AGENT_TEST_SV
`define AXI_MASTER_AGENT_TEST_SV

class axi_master_agent_test extends uvm_test;
  `uvm_component_utils(axi_master_agent_test)

  axi_master_agent axi_agent;

  function new(string name = "axi_master_agent_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), "=== [build_phase] Building AXI Master Agent Test ===", UVM_LOW)
    axi_agent = axi_master_agent::type_id::create("axi_agent", this);
  endfunction : build_phase

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info(get_type_name(), "=== [end_of_elaboration_phase] Test topology: ===", UVM_LOW)
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  virtual task run_phase(uvm_phase phase);
    axi_single_write_seq wr_seq;
    axi_single_read_seq  rd_seq;

    phase.raise_objection(this, "Starting axi_master_agent_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           PHASE 2: AXI MASTER AGENT TEST STARTED                ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release
    #100ns;

    // Step 1: Run directed AXI write sequence
    `uvm_info(get_type_name(), "--- Executing Directed AXI Write ---", UVM_LOW)
    wr_seq = axi_single_write_seq::type_id::create("wr_seq");
    wr_seq.target_addr = 32'h0000_1000;
    wr_seq.write_data  = 32'hA5A5_5A5A;
    wr_seq.trans_id    = 16'h0001;
    wr_seq.user_val    = 10'h001;
    wr_seq.start(axi_agent.sequencer);

    #20ns;

    // Step 2: Run directed AXI read sequence
    `uvm_info(get_type_name(), "--- Executing Directed AXI Read ---", UVM_LOW)
    rd_seq = axi_single_read_seq::type_id::create("rd_seq");
    rd_seq.target_addr = 32'h0000_1000;
    rd_seq.trans_id    = 16'h0002;
    rd_seq.user_val    = 10'h002;
    rd_seq.start(axi_agent.sequencer);

    #50ns;

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           PHASE 2: AXI MASTER AGENT TEST PASSED                 ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending axi_master_agent_test");
  endtask : run_phase

endclass : axi_master_agent_test

`endif // AXI_MASTER_AGENT_TEST_SV
