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
    axi_single_write_seq          axi_wr_seq;
    apb_slave_single_response_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_single_write_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 2: SINGLE AXI WRITE WITH IMMEDIATE APB COMPLETION        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release
    #100ns;

    fork
      // Process 1: APB Slave reacts with immediate completion (0 wait cycles)
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rsp_seq");
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // Process 2: AXI Master generates single legal write
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_seq");
        axi_wr_seq.target_addr   = 32'h0000_1004;
        axi_wr_seq.write_data    = 32'h1234_5678;
        axi_wr_seq.trans_id      = 16'h00A1;
        axi_wr_seq.user_val      = 10'h05A;
        axi_wr_seq.bready_delay  = 0;
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    // Allow time for monitors and scoreboard to sample and check
    #50ns;

    // Direct check of scoreboard metrics
    if (env.scoreboard.matches != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Test check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Single write verified successfully by transaction scoreboard.", UVM_LOW)
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 2: SINGLE AXI WRITE PASSED                               ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending axi2apb_single_write_test");
  endtask : run_phase

endclass : axi2apb_single_write_test

`endif // AXI2APB_SINGLE_WRITE_TEST_SV
