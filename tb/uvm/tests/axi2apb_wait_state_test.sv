// ==============================================================================
// File: axi2apb_wait_state_test.sv
// Description: Test 4 — APB Wait States Test.
//              Exercises both write and read operations while APB PREADY remains low
//              for multiple cycles (3 and 4 cycles). Verifies that address, control,
//              and data remain stable during wait states, and completion occurs accurately.
// ==============================================================================

`ifndef AXI2APB_WAIT_STATE_TEST_SV
`define AXI2APB_WAIT_STATE_TEST_SV

class axi2apb_wait_state_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_wait_state_test)

  function new(string name = "axi2apb_wait_state_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi2apb_wait_state_vseq vseq;

    phase.raise_objection(this, "Starting axi2apb_wait_state_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 4: APB WAIT STATES TEST (WRITE & READ WITH PREADY LOW)   ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Execute Virtual Sequence on Virtual Sequencer
    `uvm_info(get_type_name(), "Executing axi2apb_wait_state_vseq on Virtual Sequencer...", UVM_LOW)
    vseq = axi2apb_wait_state_vseq::type_id::create("vseq");
    vseq.start(env.v_sequencer);

    #50ns;

    // Direct check of scoreboard metrics
    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Test check failed: matches=%0d (expected 2), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Both wait-state write (3 cycles) and read (4 cycles) verified successfully.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "   TEST 4: APB WAIT STATES TEST PASSED                           ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_wait_state_test");
  endtask : run_phase

endclass : axi2apb_wait_state_test

`endif // AXI2APB_WAIT_STATE_TEST_SV
