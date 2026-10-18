// ==============================================================================
// File: axi2apb_diff_ids_users_test.sv
// Description: Directed Test — Different AXI IDs and USER Sideband Signal Verification.
//
//   Verifies the bridge's correct handling and propagation of diverse AXI ID
//   widths (16-bit) and USER sideband widths (10-bit), including boundary (min/max)
//   and walking-bit / alternating patterns.
//
//   Strategy:
//     1. Test 1 (Write): ID = 0x0000 (all zeros), USER = 10'h000 (min boundary)
//     2. Test 2 (Read) : ID = 0xFFFF (all ones) , USER = 10'h3FF (max boundary)
//     3. Test 3 (Write): ID = 0xA55A (pattern 1) , USER = 10'h2AA (pattern 1)
//     4. Test 4 (Read) : ID = 0x5AA5 (pattern 2) , USER = 10'h155 (pattern 2)
//
//   Checks:
//     - AWID correctly returns in BID response.
//     - AWUSER correctly returns in BUSER response.
//     - ARID correctly returns in RID response.
//     - ARUSER correctly returns in RUSER response.
//     - Scoreboard verifies 4 matches with 0 errors.
// ==============================================================================

`ifndef AXI2APB_DIFF_IDS_USERS_TEST_SV
`define AXI2APB_DIFF_IDS_USERS_TEST_SV

class axi2apb_diff_ids_users_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_diff_ids_users_test)

  localparam int NUM_ID_TESTS = 4;

  function new(string name = "axi2apb_diff_ids_users_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;
    axi_single_read_seq    axi_rd_seq;

    phase.raise_objection(this, "Starting axi2apb_diff_ids_users_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       TEST: DIVERSE AXI IDs AND USER SIDEBAND VERIFICATION      ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Reactive APB slave thread handling all 4 transfers
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_id_rsp_seq");
        apb_rsp_seq.num_trans         = NUM_ID_TESTS;
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = 32'h7788_9900;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master driving 4 distinct transfers with corner-case IDs and USER values
      begin
        // Transfer 1: Write with Min ID (0x0000) and Min USER (0x000)
        `uvm_info(get_type_name(), "Executing Write #1: Min boundary ID=0x0000, USER=0x000", UVM_LOW)
        axi_wr_seq = axi_single_write_seq::type_id::create("id_wr_seq_1");
        axi_wr_seq.target_addr  = 32'h0000_6000;
        axi_wr_seq.write_data   = 32'hCAFE_0001;
        axi_wr_seq.trans_id     = 16'h0000;
        axi_wr_seq.user_val     = 10'h000;
        axi_wr_seq.bready_delay = 0;
        axi_wr_seq.start(axi_agent.sequencer);

        #15ns;

        // Transfer 2: Read with Max ID (0xFFFF) and Max USER (0x3FF)
        `uvm_info(get_type_name(), "Executing Read #2: Max boundary ID=0xFFFF, USER=0x3FF", UVM_LOW)
        axi_rd_seq = axi_single_read_seq::type_id::create("id_rd_seq_2");
        axi_rd_seq.target_addr  = 32'h0000_6004;
        axi_rd_seq.trans_id     = 16'hFFFF;
        axi_rd_seq.user_val     = 10'h3FF;
        axi_rd_seq.rready_delay = 0;
        axi_rd_seq.start(axi_agent.sequencer);

        #15ns;

        // Transfer 3: Write with Alternating Pattern 1 (ID=0xA55A, USER=0x2AA)
        `uvm_info(get_type_name(), "Executing Write #3: Pattern 1 ID=0xA55A, USER=0x2AA", UVM_LOW)
        axi_wr_seq = axi_single_write_seq::type_id::create("id_wr_seq_3");
        axi_wr_seq.target_addr  = 32'h0000_6008;
        axi_wr_seq.write_data   = 32'hCAFE_0003;
        axi_wr_seq.trans_id     = 16'hA55A;
        axi_wr_seq.user_val     = 10'h2AA;
        axi_wr_seq.bready_delay = 0;
        axi_wr_seq.start(axi_agent.sequencer);

        #15ns;

        // Transfer 4: Read with Alternating Pattern 2 (ID=0x5AA5, USER=0x155)
        `uvm_info(get_type_name(), "Executing Read #4: Pattern 2 ID=0x5AA5, USER=0x155", UVM_LOW)
        axi_rd_seq = axi_single_read_seq::type_id::create("id_rd_seq_4");
        axi_rd_seq.target_addr  = 32'h0000_600C;
        axi_rd_seq.trans_id     = 16'h5AA5;
        axi_rd_seq.user_val     = 10'h155;
        axi_rd_seq.rready_delay = 0;
        axi_rd_seq.start(axi_agent.sequencer);

        #15ns;
      end
    join

    #60ns;

    // Verify scoreboard metrics
    if (env.scoreboard.matches != NUM_ID_TESTS || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, NUM_ID_TESTS, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "All distinct ID and USER boundary transfers verified successfully by scoreboard.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       TEST: DIVERSE AXI IDs AND USER SIDEBAND PASSED            ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_diff_ids_users_test");
  endtask : run_phase

endclass : axi2apb_diff_ids_users_test

`endif // AXI2APB_DIFF_IDS_USERS_TEST_SV
