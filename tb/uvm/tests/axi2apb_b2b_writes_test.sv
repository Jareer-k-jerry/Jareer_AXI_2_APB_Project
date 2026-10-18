// ==============================================================================
// File: axi2apb_b2b_writes_test.sv
// Description: Directed Test — Back-to-Back AXI Writes.
//
//   Verifies consecutive back-to-back write transactions through the AXI2APB
//   bridge. Validates AW and W buffer pipelining, consecutive APB write cycles,
//   and write response generation across multiple transfers without idle gaps.
//
//   Strategy:
//     1. APB reactive slave configured to respond to 4 consecutive write transfers.
//     2. AXI Master issues 4 consecutive writes to distinct addresses:
//          - Write 1: addr = 0x0000_2000, data = 0xCAFE_0001, ID = 0x0021
//          - Write 2: addr = 0x0000_2004, data = 0xCAFE_0002, ID = 0x0022
//          - Write 3: addr = 0x0000_2008, data = 0xCAFE_0003, ID = 0x0023
//          - Write 4: addr = 0x0000_200C, data = 0xCAFE_0004, ID = 0x0024
//     3. Scoreboard verifies all 4 writes matched with 0 errors.
// ==============================================================================

`ifndef AXI2APB_B2B_WRITES_TEST_SV
`define AXI2APB_B2B_WRITES_TEST_SV

class axi2apb_b2b_writes_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_b2b_writes_test)

  localparam int NUM_B2B_WRITES = 4;

  function new(string name = "axi2apb_b2b_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi2apb_b2b_writes_vseq vseq;

    phase.raise_objection(this, "Starting axi2apb_b2b_writes_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           TEST: BACK-TO-BACK AXI WRITES PIPELINE TEST           ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Execute Virtual Sequence on Virtual Sequencer
    `uvm_info(get_type_name(), "Executing axi2apb_b2b_writes_vseq on Virtual Sequencer...", UVM_LOW)
    vseq = axi2apb_b2b_writes_vseq::type_id::create("vseq");
    vseq.num_writes = NUM_B2B_WRITES;
    vseq.start(env.v_sequencer);

    #60ns;

    // Verify scoreboard metrics
    if (env.scoreboard.matches != NUM_B2B_WRITES || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, NUM_B2B_WRITES, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d back-to-back writes verified successfully by scoreboard.", NUM_B2B_WRITES), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "           TEST: BACK-TO-BACK AXI WRITES PASSED                  ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_b2b_writes_test");
  endtask : run_phase

endclass : axi2apb_b2b_writes_test

`endif // AXI2APB_B2B_WRITES_TEST_SV
