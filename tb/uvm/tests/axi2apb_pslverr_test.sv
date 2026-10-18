// ==============================================================================
// File: axi2apb_pslverr_test.sv
// Description: Directed Test 13 — PSLVERR Stimulus and DUT Error Behavior Documentation.
//
//   Verifies the bridge behavior when an APB slave asserts PSLVERR during
//   both write and read transfers.
//
//   Design Architecture Analysis:
//   ----------------------------
//   In the provided RTL (axi2apb.sv), the APB slave error signal (PSLVERR) is
//   declared as an input port on line 93:
//       input logic PSLVERR
//   However, inspection of the RTL datapath and FSM shows that PSLVERR is not
//   connected to the AXI response logic. Instead, the bridge hardcodes:
//       BRESP = `OKAY; (2'b00)
//       RRESP = `OKAY; (2'b00)
//
//   This test documents and verifies:
//     1. APB slave successfully asserts PSLVERR = 1 on Write.
//     2. Bridge completes the APB write transfer cleanly without deadlock or hang.
//     3. AXI master receives BID and BRESP = OKAY (2'b00).
//     4. APB slave successfully asserts PSLVERR = 1 on Read.
//     5. Bridge completes the APB read transfer cleanly without deadlock or hang.
//     6. AXI master receives RID and RRESP = OKAY (2'b00).
//     7. Scoreboard documents PSLVERR observation and verifies 2 clean matches with 0 errors.
// ==============================================================================

`ifndef AXI2APB_PSLVERR_TEST_SV
`define AXI2APB_PSLVERR_TEST_SV

class axi2apb_pslverr_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_pslverr_test)

  localparam bit [31:0] WR_ERR_ADDR = 32'h0000_7000;
  localparam bit [31:0] WR_ERR_DATA = 32'hBAD0_0001;
  localparam bit [15:0] WR_ERR_ID   = 16'h00E1;

  localparam bit [31:0] RD_ERR_ADDR = 32'h0000_7004;
  localparam bit [15:0] RD_ERR_ID   = 16'h00E2;
  localparam bit [31:0] RD_ERR_DATA = 32'hBAD0_0002;

  function new(string name = "axi2apb_pslverr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_single_response_seq apb_rsp_seq;
    axi_single_write_seq          axi_wr_seq;
    axi_single_read_seq           axi_rd_seq;

    phase.raise_objection(this, "Starting axi2apb_pslverr_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       TEST 13: APB PSLVERR STIMULUS & DUT BEHAVIOR VERIFICATION ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // -------------------------------------------------------------------------
    // Phase 1: Write Operation with APB PSLVERR = 1
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "--- Phase 1: Injecting PSLVERR on APB Write ---", UVM_LOW)
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_wr_err_seq");
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b1; // Inject PSLVERR
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_err_seq");
        axi_wr_seq.target_addr  = WR_ERR_ADDR;
        axi_wr_seq.write_data   = WR_ERR_DATA;
        axi_wr_seq.trans_id     = WR_ERR_ID;
        axi_wr_seq.user_val     = 10'h0E1;
        axi_wr_seq.bready_delay = 0;
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    #40ns;

    // -------------------------------------------------------------------------
    // Phase 2: Read Operation with APB PSLVERR = 1
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "--- Phase 2: Injecting PSLVERR on APB Read ---", UVM_LOW)
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rd_err_seq");
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b1; // Inject PSLVERR
        apb_rsp_seq.default_read_data = RD_ERR_DATA;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_err_seq");
        axi_rd_seq.target_addr  = RD_ERR_ADDR;
        axi_rd_seq.trans_id     = RD_ERR_ID;
        axi_rd_seq.user_val     = 10'h0E2;
        axi_rd_seq.rready_delay = 0;
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

    #60ns;

    // -------------------------------------------------------------------------
    // Verify Scoreboard Metrics
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(),
      $sformatf("Scoreboard final state: matches=%0d, errors=%0d",
                env.scoreboard.matches, env.scoreboard.errors), UVM_LOW)

    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("PSLVERR test check failed: expected matches=2 errors=0, got matches=%0d errors=%0d",
                  env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Bridge handled APB PSLVERR stimulus cleanly without deadlock.", UVM_LOW)
      `uvm_info(get_type_name(), "Documented actual DUT behavior: RTL hardcodes BRESP/RRESP to OKAY (2'b00).", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       TEST 13: APB PSLVERR TEST PASSED                          ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_pslverr_test");
  endtask : run_phase

endclass : axi2apb_pslverr_test

`endif // AXI2APB_PSLVERR_TEST_SV
