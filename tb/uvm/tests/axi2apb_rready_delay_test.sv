// ==============================================================================
// File: axi2apb_rready_delay_test.sv
// Description: Directed Test — Read with delayed RREADY (AXI read data backpressure).
//
//   Verifies that when the DUT bridge completes an APB read and asserts RVALID_o,
//   the testbench can apply backpressure by keeping RREADY_i low for multiple
//   clock cycles (e.g., 5 cycles).
//
//   Expected behavior:
//     1. DUT presents RVALID_o and valid RDATA_o upon APB read completion.
//     2. DUT holds RVALID_o and RDATA_o stable and unmodified while RREADY_i = 0.
//     3. Once RREADY_i is asserted, the handshake completes cleanly.
//     4. The scoreboard verifies 1 matched read with 0 errors.
// ==============================================================================

`ifndef AXI2APB_RREADY_DELAY_TEST_SV
`define AXI2APB_RREADY_DELAY_TEST_SV

class axi2apb_rready_delay_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_rready_delay_test)

  localparam bit [31:0] TARGET_ADDR   = 32'h0000_3004;
  localparam bit [15:0] TRANS_ID      = 16'h00C1;
  localparam bit [9:0]  USER_VAL      = 10'h0C1;
  localparam bit [31:0] EXP_READ_DATA = 32'hA5A5_5A5A;
  localparam int        RREADY_CYCLES = 5;

  function new(string name = "axi2apb_rready_delay_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi_single_read_seq    axi_rd_seq;
    apb_slave_reactive_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_rready_delay_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       TEST: AXI READ WITH DELAYED RREADY (BACKPRESSURE)         ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Target Addr: 0x%08h, RREADY Delay: %0d cycles", TARGET_ADDR, RREADY_CYCLES), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Reactive APB slave: respond immediately with expected data
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_rsp_seq");
        apb_rsp_seq.num_trans         = 1;
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = EXP_READ_DATA;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master driving single read with programmable RREADY backpressure delay
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_seq");
        axi_rd_seq.target_addr  = TARGET_ADDR;
        axi_rd_seq.trans_id     = TRANS_ID;
        axi_rd_seq.user_val     = USER_VAL;
        axi_rd_seq.rready_delay = RREADY_CYCLES;
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

    #50ns;

    // Verify scoreboard metrics
    if (env.scoreboard.match_count != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.match_count, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Read with delayed RREADY verified successfully by scoreboard.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       TEST: AXI READ WITH DELAYED RREADY PASSED                 ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_rready_delay_test");
  endtask : run_phase

endclass : axi2apb_rready_delay_test

`endif // AXI2APB_RREADY_DELAY_TEST_SV
