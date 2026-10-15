// ==============================================================================
// File: axi2apb_b2b_writes_test.sv
// Description: Directed Test — Back-to-Back AXI Writes.
//
//   Verifies consecutive back-to-back write transactions through the AXI2APB
//   bridge. Validates AW and W buffer pipelining, consecutive APB write cycles,
//   and write response generation across multiple transfers without idle gaps.
//
//   Strategy:
//     1. APB reactive slave configured to respond to 4 consecutive write transfers.
//     2. AXI Master issues 4 consecutive writes to distinct addresses:
//          - Write 1: addr = 0x0000_2000, data = 0xCAFE_0001, ID = 0x0021
//          - Write 2: addr = 0x0000_2004, data = 0xCAFE_0002, ID = 0x0022
//          - Write 3: addr = 0x0000_2008, data = 0xCAFE_0003, ID = 0x0023
//          - Write 4: addr = 0x0000_200C, data = 0xCAFE_0004, ID = 0x0024
//     3. Scoreboard verifies all 4 writes matched with 0 errors.
// ==============================================================================

`ifndef AXI2APB_B2B_WRITES_TEST_SV
`define AXI2APB_B2B_WRITES_TEST_SV

class axi2apb_b2b_writes_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_b2b_writes_test)

  localparam int NUM_B2B_WRITES = 4;

  function new(string name = "axi2apb_b2b_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;

    bit [31:0] test_addrs [NUM_B2B_WRITES] = '{32'h0000_2000, 32'h0000_2004, 32'h0000_2008, 32'h0000_200C};
    bit [31:0] test_data  [NUM_B2B_WRITES] = '{32'hCAFE_0001, 32'hCAFE_0002, 32'hCAFE_0003, 32'hCAFE_0004};
    bit [15:0] test_ids   [NUM_B2B_WRITES] = '{16'h0021,      16'h0022,      16'h0023,      16'h0024};
    bit [9:0]  test_users [NUM_B2B_WRITES] = '{10'h021,       10'h022,       10'h023,       10'h024};

    phase.raise_objection(this, "Starting axi2apb_b2b_writes_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           TEST: BACK-TO-BACK AXI WRITES PIPELINE TEST           ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Reactive APB slave thread handling all 4 consecutive writes
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_b2b_wr_rsp_seq");
        apb_rsp_seq.num_trans    = NUM_B2B_WRITES;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master thread issuing 4 consecutive back-to-back writes
      begin
        for (int i = 0; i < NUM_B2B_WRITES; i++) begin
          axi_wr_seq = axi_single_write_seq::type_id::create($sformatf("b2b_wr_seq_%0d", i));
          axi_wr_seq.target_addr  = test_addrs[i];
          axi_wr_seq.write_data   = test_data[i];
          axi_wr_seq.trans_id     = test_ids[i];
          axi_wr_seq.user_val     = test_users[i];
          axi_wr_seq.bready_delay = 0;
          axi_wr_seq.start(axi_agent.sequencer);
        end
      end
    join

    #60ns;

    // Verify scoreboard metrics
    if (env.scoreboard.matches != NUM_B2B_WRITES || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, NUM_B2B_WRITES, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d back-to-back writes verified successfully by scoreboard.", NUM_B2B_WRITES), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "           TEST: BACK-TO-BACK AXI WRITES PASSED                  ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_b2b_writes_test");
  endtask : run_phase

endclass : axi2apb_b2b_writes_test

`endif // AXI2APB_B2B_WRITES_TEST_SV
