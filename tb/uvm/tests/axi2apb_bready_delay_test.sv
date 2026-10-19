// ==============================================================================
// File: axi2apb_bready_delay_test.sv
// Description: Directed Test — Write with delayed BREADY (AXI write response backpressure).
//
//   Verifies that when the DUT bridge completes an APB write and asserts BVALID_o,
//   the testbench can apply backpressure by holding BREADY_i low for multiple
//   clock cycles (e.g., 5 cycles).
//
//   Expected behavior:
//     1. DUT presents BVALID_o, BRESP_o (OKAY=0), BID_o upon APB write completion.
//     2. DUT holds BVALID_o and response fields stable while BREADY_i = 0.
//     3. Once BREADY_i is asserted, the write response handshake completes cleanly.
//     4. The scoreboard verifies 1 matched write with 0 errors.
// ==============================================================================

`ifndef AXI2APB_BREADY_DELAY_TEST_SV
`define AXI2APB_BREADY_DELAY_TEST_SV

class axi2apb_bready_delay_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_bready_delay_test)

  localparam bit [31:0] TARGET_ADDR   = 32'h0000_4008;
  localparam bit [31:0] WRITE_DATA    = 32'h1122_3344;
  localparam bit [15:0] TRANS_ID      = 16'h00D1;
  localparam bit [9:0]  USER_VAL      = 10'h0D1;
  localparam int        BREADY_CYCLES = 5;

  function new(string name = "axi2apb_bready_delay_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi_single_write_seq   axi_wr_seq;
    apb_slave_reactive_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_bready_delay_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       TEST: AXI WRITE WITH DELAYED BREADY (BACKPRESSURE)        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Target Addr: 0x%08h, BREADY Delay: %0d cycles", TARGET_ADDR, BREADY_CYCLES), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Reactive APB slave: respond immediately
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_rsp_seq");
        apb_rsp_seq.num_trans    = 1;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master driving single write with programmable BREADY backpressure delay
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_seq");
        axi_wr_seq.target_addr  = TARGET_ADDR;
        axi_wr_seq.write_data   = WRITE_DATA;
        axi_wr_seq.trans_id     = TRANS_ID;
        axi_wr_seq.user_val     = USER_VAL;
        axi_wr_seq.bready_delay = BREADY_CYCLES;
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    #50ns;

    // Verify scoreboard metrics
    if (env.scoreboard.match_count != 1 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected 1), errors=%0d",
                                            env.scoreboard.match_count, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Write with delayed BREADY verified successfully by scoreboard.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       TEST: AXI WRITE WITH DELAYED BREADY PASSED                ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_bready_delay_test");
  endtask : run_phase

endclass : axi2apb_bready_delay_test

`endif // AXI2APB_BREADY_DELAY_TEST_SV
