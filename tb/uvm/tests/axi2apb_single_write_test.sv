// ==============================================================================
// File: axi2apb_single_write_test.sv
// Description: Test 2 — Single AXI Write with Immediate APB Completion.
//              Generates a legal AXI write transaction, configures the APB slave
//              for immediate 0-wait-state completion, and verifies via scoreboard.
// ==============================================================================

`ifndef AXI2APB_SINGLE_WRITE_TEST_SV
`define AXI2APB_SINGLE_WRITE_TEST_SV

class axi2apb_single_write_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_single_write_test)

  function new(string name = "axi2apb_single_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi2apb_single_write_vseq vseq;

    phase.raise_objection(this, "Starting axi2apb_single_write_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 2: SINGLE AXI WRITE WITH IMMEDIATE APB COMPLETION        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Execute Virtual Sequence on Virtual Sequencer
    vseq = axi2apb_single_write_vseq::type_id::create("vseq");
    vseq.target_addr = 32'h0000_1004;
    vseq.write_data  = 32'h1234_5678;
    vseq.trans_id    = 16'h00A1;
    vseq.user_val    = 10'h05A;
    vseq.wait_cycles = 0;
    vseq.start(env.v_sequencer);

    // Allow time for monitors and scoreboard to sample and check
    #50ns;

    // Direct check of scoreboard metrics
    if (env.scoreboard.matches != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Test check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Single write verified successfully by transaction scoreboard.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "   TEST 2: SINGLE AXI WRITE PASSED                               ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_single_write_test");
  endtask : run_phase

endclass : axi2apb_single_write_test

`endif // AXI2APB_SINGLE_WRITE_TEST_SV
