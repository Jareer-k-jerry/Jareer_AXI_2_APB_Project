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
    axi_single_read_seq           axi_rd_seq;
    apb_slave_single_response_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_single_read_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 3: SINGLE AXI READ WITH IMMEDIATE APB COMPLETION         ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release
    #100ns;

    fork
      // Process 1: APB Slave reacts with known PRDATA value (0 wait cycles)
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rsp_seq");
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = 32'hFEED_FACE;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // Process 2: AXI Master generates single legal read
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_seq");
        axi_rd_seq.target_addr   = 32'h0000_2008;
        axi_rd_seq.trans_id      = 16'h00B2;
        axi_rd_seq.user_val      = 10'h07B;
        axi_rd_seq.rready_delay  = 0;
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

    // Allow time for monitors and scoreboard to sample and check
    #50ns;

    // Direct check of scoreboard metrics
    if (env.scoreboard.matches != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Test check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Single read verified successfully by transaction scoreboard (PRDATA=0xFEED_FACE).", UVM_LOW)
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 3: SINGLE AXI READ PASSED                                ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending axi2apb_single_read_test");
  endtask : run_phase

endclass : axi2apb_single_read_test

`endif // AXI2APB_SINGLE_READ_TEST_SV
