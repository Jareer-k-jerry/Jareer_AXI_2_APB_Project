// ==============================================================================
// File: axi2apb_scoreboard.sv
// Description: Transaction-level scoreboard and reference model for AXI4-to-APB bridge.
//              Compares monitored AXI master transactions against observed APB slave
//              transfers, validating address, data, direction, response status,
//              ID/USER propagation, and RLAST behavior according to the supplied RTL.
// ==============================================================================

`ifndef AXI2APB_SCOREBOARD_SV
`define AXI2APB_SCOREBOARD_SV

`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class axi2apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi2apb_scoreboard)

  // ---------------------------------------------------------------------------
  // TLM Analysis Exports
  // ---------------------------------------------------------------------------
  uvm_analysis_imp_axi #(axi_master_item, axi2apb_scoreboard) axi_export;
  uvm_analysis_imp_apb #(apb_slave_item,  axi2apb_scoreboard) apb_export;

  // ---------------------------------------------------------------------------
  // Transaction Queues
  // ---------------------------------------------------------------------------
  axi_master_item axi_queue[$];
  apb_slave_item  apb_queue[$];

  // ---------------------------------------------------------------------------
  // Verification Metrics & Statistics
  // ---------------------------------------------------------------------------
  int unsigned match_count;
  int unsigned errors;

  int unsigned axi_write_count;
  int unsigned axi_read_count;
  int unsigned apb_write_count;
  int unsigned apb_read_count;
  int unsigned pslverr_count;

  // Configuration knob: set to 0 for smoke/reset/idle tests where 0 transactions is expected.
  // For standard transaction tests, defaults to 1.
  bit check_expected_transactions = 1'b1;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi2apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    axi_export = new("axi_export", this);
    apb_export = new("apb_export", this);
  endfunction : new

  // ---------------------------------------------------------------------------
  // Build Phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(bit)::get(this, "", "check_expected_transactions", check_expected_transactions));
    match_count = 0;
    errors          = 0;
    axi_write_count = 0;
    axi_read_count  = 0;
    apb_write_count = 0;
    apb_read_count  = 0;
    pslverr_count   = 0;
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // AXI Monitor Callback
  // ---------------------------------------------------------------------------
  virtual function void write_axi(axi_master_item tr);
    axi_master_item copy;
    $cast(copy, tr.clone());

    if (copy.write) begin
      axi_write_count++;
      `uvm_info(get_type_name(), $sformatf("Received AXI WRITE item #%0d: addr=0x%08h data=0x%08h id=0x%04h",
                                          axi_write_count, copy.addr, copy.data, copy.id), UVM_HIGH)
    end else begin
      axi_read_count++;
      `uvm_info(get_type_name(), $sformatf("Received AXI READ item #%0d: addr=0x%08h rdata=0x%08h id=0x%04h",
                                          axi_read_count, copy.addr, copy.read_data, copy.id), UVM_HIGH)
    end

    axi_queue.push_back(copy);
    compare_available_transactions();
  endfunction : write_axi

  // ---------------------------------------------------------------------------
  // APB Monitor Callback
  // ---------------------------------------------------------------------------
  virtual function void write_apb(apb_slave_item tr);
    apb_slave_item copy;
    $cast(copy, tr.clone());

    if (copy.write) begin
      apb_write_count++;
      `uvm_info(get_type_name(), $sformatf("Received APB WRITE transfer #%0d: addr=0x%08h pwdata=0x%08h",
                                          apb_write_count, copy.addr, copy.write_data), UVM_HIGH)
    end else begin
      apb_read_count++;
      `uvm_info(get_type_name(), $sformatf("Received APB READ transfer #%0d: addr=0x%08h prdata=0x%08h",
                                          apb_read_count, copy.addr, copy.read_data), UVM_HIGH)
    end

    if (copy.pslverr === 1'b1) begin
      pslverr_count++;
      `uvm_info(get_type_name(), $sformatf("Captured APB PSLVERR assertion at addr=0x%08h (Transfer #%0d)",
                                          copy.addr, copy.write ? apb_write_count : apb_read_count), UVM_LOW)
    end

    apb_queue.push_back(copy);
    compare_available_transactions();
  endfunction : write_apb

  // ---------------------------------------------------------------------------
  // Transaction-Level Comparison & Checking
  // ---------------------------------------------------------------------------
  virtual function void compare_available_transactions();
    axi_master_item axi_tr;
    apb_slave_item  apb_tr;
    int unsigned trans_errors;

    while (axi_queue.size() > 0 && apb_queue.size() > 0) begin
      axi_tr = axi_queue.pop_front();
      apb_tr = apb_queue.pop_front();
      trans_errors = 0;

      // -----------------------------------------------------------------------
      // 1. Direction Check (AXI write vs APB pwrite)
      // -----------------------------------------------------------------------
      if (axi_tr.write !== apb_tr.write) begin
        trans_errors++;
        `uvm_error("SCB_DIR_MISMATCH",
          $sformatf("Direction mismatch: AXI write=%0b vs APB write=%0b (AXI addr=0x%08h, ID=0x%04h)",
                    axi_tr.write, apb_tr.write, axi_tr.addr, axi_tr.id))
      end

      // -----------------------------------------------------------------------
      // 2. Address Check (AXI addr vs APB paddr)
      // -----------------------------------------------------------------------
      if (axi_tr.addr !== apb_tr.addr) begin
        trans_errors++;
        `uvm_error("SCB_ADDR_MISMATCH",
          $sformatf("Address mismatch: AXI addr=0x%08h vs APB addr=0x%08h (Direction=%s, ID=0x%04h)",
                    axi_tr.addr, apb_tr.addr, axi_tr.write ? "WRITE" : "READ", axi_tr.id))
      end

      // -----------------------------------------------------------------------
      // 3. Data Integrity Check
      // -----------------------------------------------------------------------
      if (axi_tr.write) begin
        // For Write: AXI WDATA must match APB PWDATA
        if (axi_tr.data !== apb_tr.write_data) begin
          trans_errors++;
          `uvm_error("SCB_WDATA_MISMATCH",
            $sformatf("Write data mismatch at addr=0x%08h: Expected AXI WDATA=0x%08h, Actual APB PWDATA=0x%08h (ID=0x%04h)",
                      axi_tr.addr, axi_tr.data, apb_tr.write_data, axi_tr.id))
        end
      end else begin
        // For Read: APB PRDATA must be accurately returned as AXI RDATA
        if (axi_tr.read_data !== apb_tr.read_data) begin
          trans_errors++;
          `uvm_error("SCB_RDATA_MISMATCH",
            $sformatf("Read data mismatch at addr=0x%08h: Expected APB PRDATA=0x%08h, Actual AXI RDATA=0x%08h (ID=0x%04h)",
                      axi_tr.addr, apb_tr.read_data, axi_tr.read_data, axi_tr.id))
        end

        // Single-beat read must return RLAST = 1
        if (axi_tr.response_last !== 1'b1) begin
          trans_errors++;
          `uvm_error("SCB_RLAST_MISMATCH",
            $sformatf("RLAST not asserted on completed single-beat read at addr=0x%08h (ID=0x%04h)",
                      axi_tr.addr, axi_tr.id))
        end
      end

      // -----------------------------------------------------------------------
      // 4. Response Status Code Check
      // In the supplied RTL (axi2apb.sv), BRESP and RRESP always return OKAY (2'b00),
      // even when PSLVERR is asserted on the APB interface.
      // -----------------------------------------------------------------------
      if (axi_tr.resp !== 2'b00) begin
        trans_errors++;
        `uvm_error("SCB_RESP_MISMATCH",
          $sformatf("%s response status mismatch at addr=0x%08h: Expected OKAY (2'b00), Actual AXI RESP=2'b%02b",
                    axi_tr.write ? "WRITE" : "READ", axi_tr.addr, axi_tr.resp))
      end else if (apb_tr.pslverr === 1'b1) begin
        `uvm_info("SCB_PSLVERR_OBSERVED",
          $sformatf("APB PSLVERR=1 verified at addr=0x%08h: RTL correctly maintains AXI RESP=OKAY as implemented",
                    axi_tr.addr), UVM_MEDIUM)
      end

      // -----------------------------------------------------------------------
      // 5. ID & USER Signal Propagation Check
      // According to RTL: BID = AWID, BUSER = AWUSER; RID = ARID, RUSER = ARUSER
      // -----------------------------------------------------------------------
      if (axi_tr.response_id !== axi_tr.id) begin
        trans_errors++;
        `uvm_error("SCB_ID_MISMATCH",
          $sformatf("%s ID propagation mismatch: Expected ID=0x%04h, Response ID=0x%04h at addr=0x%08h",
                    axi_tr.write ? "BID" : "RID", axi_tr.id, axi_tr.response_id, axi_tr.addr))
      end

      if (axi_tr.response_user !== axi_tr.user) begin
        trans_errors++;
        `uvm_error("SCB_USER_MISMATCH",
          $sformatf("%s USER propagation mismatch: Expected USER=0x%03h, Response USER=0x%03h at addr=0x%08h",
                    axi_tr.write ? "BUSER" : "RUSER", axi_tr.user, axi_tr.response_user, axi_tr.addr))
      end

      // -----------------------------------------------------------------------
      // 6. Match Disposition
      // -----------------------------------------------------------------------
      if (trans_errors == 0) begin
        match_count++;
        `uvm_info("SCB_MATCH",
          $sformatf("MATCHED %s at addr=0x%08h: Data=0x%08h ID=0x%04h USER=0x%03h RESP=%02b",
                    axi_tr.write ? "WRITE" : "READ",
                    axi_tr.addr,
                    axi_tr.write ? axi_tr.data : axi_tr.read_data,
                    axi_tr.id,
                    axi_tr.user,
                    axi_tr.resp), UVM_LOW)
      end else begin
        errors += trans_errors;
        `uvm_error("SCB_TRANS_FAIL",
          $sformatf("Transaction FAILED at addr=0x%08h with %0d checking error(s)",
                    axi_tr.addr, trans_errors))
      end
    end
  endfunction : compare_available_transactions

  // ---------------------------------------------------------------------------
  // Check Phase: Detect remaining unmatched transactions
  // ---------------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    `uvm_info(get_type_name(), "check_phase: checking queue drain status", UVM_LOW)

    if (axi_queue.size() != 0 || apb_queue.size() != 0) begin
      errors++;
      `uvm_error("SCB_QUEUE_NOT_EMPTY",
        $sformatf("Unmatched transactions remain at end of test: AXI Queue=%0d, APB Queue=%0d",
                  axi_queue.size(), apb_queue.size()))
    end
  endfunction : check_phase

  // ---------------------------------------------------------------------------
  // Report Phase: Display final scoreboard statistics
  // ---------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "               AXI2APB SCOREBOARD SUMMARY REPORT                 ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total AXI Requests Monitored : %0d (Writes: %0d, Reads: %0d)",
                                        axi_write_count + axi_read_count, axi_write_count, axi_read_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total APB Transfers Monitored: %0d (Writes: %0d, Reads: %0d)",
                                        apb_write_count + apb_read_count, apb_write_count, apb_read_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total APB PSLVERR Events     : %0d", pslverr_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Successfully Matched Transfers: %0d", match_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total Scoreboard Discrepancies: %0d", errors), UVM_LOW)
    `uvm_info(get_type_name(), "-----------------------------------------------------------------", UVM_LOW)

    if (errors == 0 && match_count > 0) begin
      `uvm_info(get_type_name(), "  >>> SCOREBOARD RESULT: ALL TRANSACTIONS MATCHED (PASSED) <<<   ", UVM_LOW)
    end else if (errors == 0 && match_count == 0) begin
      if (!check_expected_transactions) begin
        `uvm_info(get_type_name(), "  >>> SCOREBOARD RESULT: ZERO TRANSACTIONS EXPECTED (IDLE/SMOKE TEST PASSED) <<<", UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), "  >>> SCOREBOARD RESULT: ZERO TRANSACTIONS PROCESSED (EXPECTED TRANSACTIONS) <<<")
      end
    end else begin
      `uvm_error(get_type_name(), $sformatf("  >>> SCOREBOARD RESULT: FAILED WITH %0d ERRORS <<<       ", errors))
    end
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
  endfunction : report_phase

endclass : axi2apb_scoreboard

`endif // AXI2APB_SCOREBOARD_SV
