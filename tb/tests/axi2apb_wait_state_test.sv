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
    axi_single_write_seq          axi_wr_seq;
    axi_single_read_seq           axi_rd_seq;
    apb_slave_single_response_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_wait_state_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 4: APB WAIT STATES TEST (WRITE & READ WITH PREADY LOW)   ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // -------------------------------------------------------------------------
    // Phase 1: Write transaction with 3 APB wait cycles
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "Executing Write transfer with 3 APB wait states...", UVM_LOW)
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_wr_wait_rsp");
        apb_rsp_seq.wait_cycles  = 3;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_seq");
        axi_wr_seq.target_addr   = 32'h0000_3000;
        axi_wr_seq.write_data    = 32'hAAAA_5555;
        axi_wr_seq.trans_id      = 16'h00C1;
        axi_wr_seq.user_val      = 10'h0CC;
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    #30ns;

    // -------------------------------------------------------------------------
    // Phase 2: Read transaction with 4 APB wait cycles
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "Executing Read transfer with 4 APB wait states...", UVM_LOW)
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rd_wait_rsp");
        apb_rsp_seq.wait_cycles       = 4;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = 32'hAAAA_5555; // Expected read-back from memory
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_seq");
        axi_rd_seq.target_addr   = 32'h0000_3000;
        axi_rd_seq.trans_id      = 16'h00C2;
        axi_rd_seq.user_val      = 10'h0DD;
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

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
