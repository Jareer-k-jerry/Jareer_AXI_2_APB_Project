// ==============================================================================
// File: axi2apb_b2b_reads_test.sv
// Description: Directed Test — Back-to-Back AXI Reads.
//
//   Verifies consecutive back-to-back read transactions through the AXI2APB
//   bridge. Validates internal buffer pipelining, consecutive APB access cycles,
//   and scoreboard data integrity across multiple transfers without idle gaps.
//
//   Strategy:
//     1. APB reactive slave configured to respond to 4 consecutive read transfers.
//     2. AXI Master issues 4 consecutive reads to distinct addresses:
//          - Read 1: addr = 0x0000_1000, ID = 0x0011, expected data = 0xA1A1_0001
//          - Read 2: addr = 0x0000_1004, ID = 0x0012, expected data = 0xB2B2_0002
//          - Read 3: addr = 0x0000_1008, ID = 0x0013, expected data = 0xC3C3_0003
//          - Read 4: addr = 0x0000_100C, ID = 0x0014, expected data = 0xD4D4_0004
//     3. Scoreboard verifies all 4 reads matched with 0 errors.
// ==============================================================================

`ifndef AXI2APB_B2B_READS_TEST_SV
`define AXI2APB_B2B_READS_TEST_SV

class axi2apb_b2b_reads_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_b2b_reads_test)

  localparam int NUM_B2B_READS = 4;

  function new(string name = "axi2apb_b2b_reads_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_read_seq    axi_rd_seq;

    bit [31:0] test_addrs [NUM_B2B_READS] = '{32'h0000_1000, 32'h0000_1004, 32'h0000_1008, 32'h0000_100C};
    bit [15:0] test_ids   [NUM_B2B_READS] = '{16'h0011,      16'h0012,      16'h0013,      16'h0014};
    bit [9:0]  test_users [NUM_B2B_READS] = '{10'h011,       10'h012,       10'h013,       10'h014};
    bit [31:0] test_data  [NUM_B2B_READS] = '{32'hA1A1_0001, 32'hB2B2_0002, 32'hC3C3_0003, 32'hD4D4_0004};

    phase.raise_objection(this, "Starting axi2apb_b2b_reads_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "            TEST: BACK-TO-BACK AXI READS PIPELINE TEST           ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Pre-populate APB slave driver internal memory so each address returns distinct expected data
    for (int i = 0; i < NUM_B2B_READS; i++) begin
      env.apb_agent.driver.memory[test_addrs[i]] = test_data[i];
    end

    fork
      // Reactive APB slave thread handling all 4 consecutive reads
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_b2b_rsp_seq");
        apb_rsp_seq.num_trans    = NUM_B2B_READS;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master thread issuing 4 consecutive back-to-back reads
      begin
        for (int i = 0; i < NUM_B2B_READS; i++) begin
          axi_rd_seq = axi_single_read_seq::type_id::create($sformatf("b2b_rd_seq_%0d", i));
          axi_rd_seq.target_addr  = test_addrs[i];
          axi_rd_seq.trans_id     = test_ids[i];
          axi_rd_seq.user_val     = test_users[i];
          axi_rd_seq.rready_delay = 0;
          axi_rd_seq.start(axi_agent.sequencer);
        end
      end
    join

    #60ns;

    // Verify scoreboard metrics
    if (env.scoreboard.matches != NUM_B2B_READS || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, NUM_B2B_READS, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d back-to-back reads verified successfully by scoreboard.", NUM_B2B_READS), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "            TEST: BACK-TO-BACK AXI READS PASSED                  ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_b2b_reads_test");
  endtask : run_phase

endclass : axi2apb_b2b_reads_test

`endif // AXI2APB_B2B_READS_TEST_SV
