// ==============================================================================
// File: axi2apb_mixed_traffic_test.sv
// Description: Directed Test — Mixed Read/Write Traffic (Alternating W/R sequences).
//
//   Verifies alternating read and write operations through the AXI2APB bridge.
//   Validates seamless FSM switching between IDLE -> WRITE (WAIT_W_PREADY,
//   SEND_B_RESP) -> IDLE -> READ (WAIT_R_PREADY, DONE_SINGLE_RD) -> IDLE.
//
//   Strategy:
//     1. APB reactive slave handles 6 transfers reactively.
//     2. Sequence of 3 write-read pairs:
//          - Write to 0x0000_5000 (0xAAAA_1111) -> Read from 0x0000_5000
//          - Write to 0x0000_5004 (0xBBBB_2222) -> Read from 0x0000_5004
//          - Write to 0x0000_5008 (0xCCCC_3333) -> Read from 0x0000_5008
//     3. APB slave driver updates internal memory on writes and serves memory data
//        on reads, ensuring read-after-write data integrity across the bridge.
//     4. Scoreboard verifies all 6 transactions matched with 0 errors.
// ==============================================================================

`ifndef AXI2APB_MIXED_TRAFFIC_TEST_SV
`define AXI2APB_MIXED_TRAFFIC_TEST_SV

class axi2apb_mixed_traffic_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_mixed_traffic_test)

  localparam int NUM_PAIRS = 3;
  localparam int TOTAL_TRANS = NUM_PAIRS * 2;

  function new(string name = "axi2apb_mixed_traffic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;
    axi_single_read_seq    axi_rd_seq;

    bit [31:0] addrs [NUM_PAIRS] = '{32'h0000_5000, 32'h0000_5004, 32'h0000_5008};
    bit [31:0] data  [NUM_PAIRS] = '{32'hAAAA_1111, 32'hBBBB_2222, 32'hCCCC_3333};
    bit [15:0] wr_ids[NUM_PAIRS] = '{16'h0031,      16'h0032,      16'h0033};
    bit [15:0] rd_ids[NUM_PAIRS] = '{16'h0041,      16'h0042,      16'h0043};

    phase.raise_objection(this, "Starting axi2apb_mixed_traffic_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           TEST: MIXED READ/WRITE ALTERNATING TRAFFIC            ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Reactive APB slave thread handling all 6 transfers
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_mixed_rsp_seq");
        apb_rsp_seq.num_trans    = TOTAL_TRANS;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // AXI Master thread issuing alternating Write-then-Read operations
      begin
        for (int i = 0; i < NUM_PAIRS; i++) begin
          // Write operation
          axi_wr_seq = axi_single_write_seq::type_id::create($sformatf("mixed_wr_seq_%0d", i));
          axi_wr_seq.target_addr  = addrs[i];
          axi_wr_seq.write_data   = data[i];
          axi_wr_seq.trans_id     = wr_ids[i];
          axi_wr_seq.user_val     = 10'h030 + i;
          axi_wr_seq.bready_delay = 0;
          axi_wr_seq.start(axi_agent.sequencer);

          // Small inter-transfer pacing
          #10ns;

          // Read operation from the address just written
          axi_rd_seq = axi_single_read_seq::type_id::create($sformatf("mixed_rd_seq_%0d", i));
          axi_rd_seq.target_addr  = addrs[i];
          axi_rd_seq.trans_id     = rd_ids[i];
          axi_rd_seq.user_val     = 10'h040 + i;
          axi_rd_seq.rready_delay = 0;
          axi_rd_seq.start(axi_agent.sequencer);

          #10ns;
        end
      end
    join

    #60ns;

    // Verify scoreboard metrics
    if (env.scoreboard.matches != TOTAL_TRANS || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, TOTAL_TRANS, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d mixed read/write transfers verified successfully by scoreboard.", TOTAL_TRANS), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "           TEST: MIXED READ/WRITE TRAFFIC PASSED                 ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_mixed_traffic_test");
  endtask : run_phase

endclass : axi2apb_mixed_traffic_test

`endif // AXI2APB_MIXED_TRAFFIC_TEST_SV
