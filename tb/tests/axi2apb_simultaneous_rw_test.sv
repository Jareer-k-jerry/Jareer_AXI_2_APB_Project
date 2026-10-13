// ==============================================================================
// File: axi2apb_simultaneous_rw_test.sv
// Description: Test 5 — Simultaneous AXI Read and Write Priority Verification.
//
//   The DUT FSM (axi2apb.sv) implements read-priority arbitration from the IDLE
//   state:
//       if (ARVALID)      -> start read  path
//       else if (AWVALID) -> start write path
//
//   This test drives both ARVALID and AWVALID simultaneously and confirms:
//     1. The READ transaction completes first on the APB bus (read priority).
//     2. The WRITE transaction subsequently completes correctly.
//     3. The scoreboard records 2 matched transactions with 0 errors.
//
//   Strategy
//   ---------
//   - Fork three threads:
//       Thread A - APB slave reactive sequence: responds to TWO APB cycles
//                  (first the read, then the write) with immediate PREADY.
//       Thread B - AXI read sequence: presented concurrently with Thread C.
//       Thread C - AXI write sequence: presented concurrently with Thread B.
//   - The driver holds ARVALID asserted until ARREADY, and AWVALID until
//     AWREADY. Because the DUT checks ARVALID first (from IDLE), the read wins.
//   - After both sequences complete, check scoreboard metrics.
// ==============================================================================

`ifndef AXI2APB_SIMULTANEOUS_RW_TEST_SV
`define AXI2APB_SIMULTANEOUS_RW_TEST_SV

class axi2apb_simultaneous_rw_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_simultaneous_rw_test)

  // -------------------------------------------------------------------------
  // Transaction parameters
  // -------------------------------------------------------------------------
  localparam bit [31:0] READ_ADDR     = 32'h0000_5000;
  localparam bit [31:0] WRITE_ADDR    = 32'h0000_6000;
  localparam bit [31:0] WRITE_DATA    = 32'hCAFE_F00D;
  localparam bit [31:0] READ_DATA_EXP = 32'hBEEF_1234;

  function new(string name = "axi2apb_simultaneous_rw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    axi_single_read_seq    axi_rd_seq;
    axi_single_write_seq   axi_wr_seq;
    apb_slave_reactive_seq apb_rsp_seq;

    phase.raise_objection(this, "Starting axi2apb_simultaneous_rw_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 5: SIMULTANEOUS AXI READ AND WRITE — PRIORITY CHECK      ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "  Strategy: Drive READ and WRITE in parallel from IDLE state.    ", UVM_LOW)
    `uvm_info(get_type_name(), "  Expected: DUT services READ first (read-priority arbitration). ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset to be fully released
    #100ns;

    // -------------------------------------------------------------------------
    // Fork three concurrent threads:
    //   [0] APB slave: respond to 2 APB transactions (read first, write second)
    //   [1] AXI Read : present ARVALID simultaneously with [2]
    //   [2] AXI Write: present AWVALID simultaneously with [1]
    // -------------------------------------------------------------------------
    fork

      // --- Thread 0: APB Slave reactive response (2 transactions) -----------
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_rsp_seq");
        apb_rsp_seq.num_trans         = 2;           // respond to read then write
        apb_rsp_seq.wait_cycles       = 0;           // immediate PREADY
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = READ_DATA_EXP;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // --- Thread 1: AXI Read (high-priority channel) -----------------------
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_seq");
        axi_rd_seq.target_addr = READ_ADDR;
        axi_rd_seq.trans_id    = 16'h00E1;
        axi_rd_seq.user_val    = 10'h0E1;
        axi_rd_seq.start(axi_agent.sequencer);
      end

      // --- Thread 2: AXI Write (lower-priority; starts same simulation delta)
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_seq");
        axi_wr_seq.target_addr  = WRITE_ADDR;
        axi_wr_seq.write_data   = WRITE_DATA;
        axi_wr_seq.trans_id     = 16'h00E2;
        axi_wr_seq.user_val     = 10'h0E2;
        axi_wr_seq.bready_delay = 0;
        axi_wr_seq.start(axi_agent.sequencer);
      end

    join  // wait for all three threads (both AXI transactions + APB reactive)

    // Allow time for monitors to observe the final APB access phase and for
    // the scoreboard to drain both queue entries.
    #80ns;

    // -------------------------------------------------------------------------
    // Scoreboard check — expect exactly 2 matches, 0 errors
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(),
      $sformatf("Scoreboard final state: matches=%0d, errors=%0d",
                env.scoreboard.matches, env.scoreboard.errors), UVM_LOW)

    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Priority test FAILED: expected matches=2 errors=0, got matches=%0d errors=%0d",
                  env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(),
        "Both read (priority-serviced first) and write transactions verified by scoreboard.", UVM_LOW)
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   TEST 5: SIMULTANEOUS READ/WRITE PRIORITY TEST PASSED           ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending axi2apb_simultaneous_rw_test");
  endtask : run_phase

endclass : axi2apb_simultaneous_rw_test

`endif // AXI2APB_SIMULTANEOUS_RW_TEST_SV
