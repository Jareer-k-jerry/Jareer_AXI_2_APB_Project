// ==============================================================================
// File: axi2apb_single_read_test.sv
// Description: Test 3 — Single AXI Read with Immediate APB Completion.
//              Generates a legal AXI read transaction, configures known APB PRDATA,
//              and checks that the scoreboard verifies address, data, RLAST, and OKAY response.
// ==============================================================================

`ifndef AXI2APB_SINGLE_READ_TEST_SV
`define AXI2APB_SINGLE_READ_TEST_SV

class axi2apb_single_read_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_single_read_test)

  function new(string name = "axi2apb_single_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi2apb_single_read_vseq vseq;

    phase.raise_objection(this, "Starting axi2apb_single_read_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 3: SINGLE AXI READ WITH IMMEDIATE APB COMPLETION         ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Execute Virtual Sequence on Virtual Sequencer
    vseq = axi2apb_single_read_vseq::type_id::create("vseq");
    vseq.target_addr       = 32'h0000_2008;
    vseq.trans_id          = 16'h00B2;
    vseq.user_val          = 10'h07B;
    vseq.default_read_data = 32'hFEED_FACE;
    vseq.wait_cycles       = 0;
    vseq.start(env.v_sequencer);

    // Allow time for monitors and scoreboard to sample and check
    #50ns;

    // Direct check of scoreboard metrics
    if (env.scoreboard.match_count != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Test check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.match_count, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Single read verified successfully by transaction scoreboard (PRDATA=0xFEED_FACE).", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "   TEST 3: SINGLE AXI READ PASSED                                ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_single_read_test");
  endtask : run_phase

endclass : axi2apb_single_read_test

`endif // AXI2APB_SINGLE_READ_TEST_SV
