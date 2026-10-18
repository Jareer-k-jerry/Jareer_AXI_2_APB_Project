// ==============================================================================
// File: axi2apb_virtual_sequences.sv
// Description: UVM Virtual Sequences for AXI4-to-APB Bridge Verification.
//              Orchestrates parallel stimulus across AXI Master Sequencer and
//              APB Reactive Slave Sequencer via p_sequencer handles.
//              Eliminates direct fork..join inside test classes.
// ==============================================================================

`ifndef AXI2APB_VIRTUAL_SEQUENCES_SV
`define AXI2APB_VIRTUAL_SEQUENCES_SV

// -----------------------------------------------------------------------------
// Base Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_base_vseq extends uvm_sequence;
  `uvm_object_utils(axi2apb_base_vseq)
  `uvm_declare_p_sequencer(axi2apb_virtual_sequencer)

  function new(string name = "axi2apb_base_vseq");
    super.new(name);
  endfunction : new

endclass : axi2apb_base_vseq


// -----------------------------------------------------------------------------
// VSeq 1: Smoke / Reset Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_smoke_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_smoke_vseq)

  function new(string name = "axi2apb_smoke_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_smoke_seq axi_seq;
    `uvm_info(get_type_name(), "Executing axi2apb_smoke_vseq via Virtual Sequencer", UVM_LOW)
    axi_seq = axi_smoke_seq::type_id::create("axi_seq");
    axi_seq.start(p_sequencer.axi_seqr);
  endtask : body
endclass : axi2apb_smoke_vseq


// -----------------------------------------------------------------------------
// VSeq 2: Single Write Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_single_write_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_single_write_vseq)

  bit [31:0] target_addr  = 32'h0000_1004;
  bit [31:0] write_data   = 32'h1234_5678;
  bit [15:0] trans_id     = 16'h00A1;
  bit [9:0]  user_val     = 10'h05A;
  int unsigned wait_cycles = 0;

  function new(string name = "axi2apb_single_write_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_single_write_seq          axi_seq;
    apb_slave_single_response_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_single_response_seq::type_id::create("apb_seq");
        apb_seq.wait_cycles  = wait_cycles;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_single_write_seq::type_id::create("axi_seq");
        axi_seq.target_addr  = target_addr;
        axi_seq.write_data   = write_data;
        axi_seq.trans_id     = trans_id;
        axi_seq.user_val     = user_val;
        axi_seq.bready_delay = 0;
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_single_write_vseq


// -----------------------------------------------------------------------------
// VSeq 3: Single Read Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_single_read_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_single_read_vseq)

  bit [31:0] target_addr       = 32'h0000_2008;
  bit [15:0] trans_id          = 16'h00B2;
  bit [9:0]  user_val          = 10'h07B;
  bit [31:0] default_read_data = 32'hFEED_FACE;
  int unsigned wait_cycles     = 0;

  function new(string name = "axi2apb_single_read_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_single_read_seq           axi_seq;
    apb_slave_single_response_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_single_response_seq::type_id::create("apb_seq");
        apb_seq.wait_cycles       = wait_cycles;
        apb_seq.inject_error      = 1'b0;
        apb_seq.default_read_data = default_read_data;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_single_read_seq::type_id::create("axi_seq");
        axi_seq.target_addr  = target_addr;
        axi_seq.trans_id     = trans_id;
        axi_seq.user_val     = user_val;
        axi_seq.rready_delay = 0;
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_single_read_vseq


// -----------------------------------------------------------------------------
// VSeq 4: Wait States Virtual Sequence (Write & Read with Wait Cycles)
// -----------------------------------------------------------------------------
class axi2apb_wait_state_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_wait_state_vseq)

  function new(string name = "axi2apb_wait_state_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_single_write_seq          axi_wr_seq;
    axi_single_read_seq           axi_rd_seq;
    apb_slave_single_response_seq apb_rsp_seq;

    // Phase 1: Write transaction with 3 APB wait cycles
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_wr_wait_rsp");
        apb_rsp_seq.wait_cycles  = 3;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(p_sequencer.apb_seqr);
      end
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("axi_wr_seq");
        axi_wr_seq.target_addr   = 32'h0000_3000;
        axi_wr_seq.write_data    = 32'hAAAA_5555;
        axi_wr_seq.trans_id      = 16'h00C1;
        axi_wr_seq.user_val      = 10'h0CC;
        axi_wr_seq.start(p_sequencer.axi_seqr);
      end
    join

    #30ns;

    // Phase 2: Read transaction with 4 APB wait cycles
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rd_wait_rsp");
        apb_rsp_seq.wait_cycles       = 4;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = 32'hAAAA_5555;
        apb_rsp_seq.start(p_sequencer.apb_seqr);
      end
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("axi_rd_seq");
        axi_rd_seq.target_addr   = 32'h0000_3000;
        axi_rd_seq.trans_id      = 16'h00C2;
        axi_rd_seq.user_val      = 10'h0DD;
        axi_rd_seq.start(p_sequencer.axi_seqr);
      end
    join
  endtask : body
endclass : axi2apb_wait_state_vseq


// -----------------------------------------------------------------------------
// VSeq 5: BREADY Delay Backpressure Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_bready_delay_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_bready_delay_vseq)

  function new(string name = "axi2apb_bready_delay_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_bready_delay_seq          axi_seq;
    apb_slave_single_response_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_single_response_seq::type_id::create("apb_seq");
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_bready_delay_seq::type_id::create("axi_seq");
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_bready_delay_vseq


// -----------------------------------------------------------------------------
// VSeq 6: RREADY Delay Backpressure Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_rready_delay_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_rready_delay_vseq)

  function new(string name = "axi2apb_rready_delay_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_rready_delay_seq          axi_seq;
    apb_slave_single_response_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_single_response_seq::type_id::create("apb_seq");
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_rready_delay_seq::type_id::create("axi_seq");
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_rready_delay_vseq


// -----------------------------------------------------------------------------
// VSeq 7: Back-to-Back Writes Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_b2b_writes_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_b2b_writes_vseq)

  int unsigned num_writes = 4;

  function new(string name = "axi2apb_b2b_writes_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_b2b_writes_seq     axi_seq;
    apb_slave_reactive_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_reactive_seq::type_id::create("apb_seq");
        apb_seq.num_trans    = num_writes;
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_b2b_writes_seq::type_id::create("axi_seq");
        axi_seq.num_writes = num_writes;
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_b2b_writes_vseq


// -----------------------------------------------------------------------------
// VSeq 8: Back-to-Back Reads Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_b2b_reads_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_b2b_reads_vseq)

  int unsigned num_reads = 4;

  function new(string name = "axi2apb_b2b_reads_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_b2b_reads_seq      axi_seq;
    apb_slave_reactive_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_reactive_seq::type_id::create("apb_seq");
        apb_seq.num_trans    = num_reads;
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_b2b_reads_seq::type_id::create("axi_seq");
        axi_seq.num_reads = num_reads;
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_b2b_reads_vseq


// -----------------------------------------------------------------------------
// VSeq 9: Mixed Traffic (Read & Write Interleaved) Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_mixed_traffic_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_mixed_traffic_vseq)

  function new(string name = "axi2apb_mixed_traffic_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_mixed_traffic_seq  axi_seq;
    apb_slave_reactive_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_reactive_seq::type_id::create("apb_seq");
        apb_seq.num_trans    = 6; // 3 writes + 3 reads
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_mixed_traffic_seq::type_id::create("axi_seq");
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_mixed_traffic_vseq


// -----------------------------------------------------------------------------
// VSeq 10: Diverse IDs & USER Sidebands Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_diff_ids_users_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_diff_ids_users_vseq)

  function new(string name = "axi2apb_diff_ids_users_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_diff_ids_users_seq axi_seq;
    apb_slave_reactive_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_reactive_seq::type_id::create("apb_seq");
        apb_seq.num_trans    = 4;
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b0;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_diff_ids_users_seq::type_id::create("axi_seq");
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_diff_ids_users_vseq


// -----------------------------------------------------------------------------
// VSeq 11: APB PSLVERR Verification Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_pslverr_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_pslverr_vseq)

  function new(string name = "axi2apb_pslverr_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_pslverr_seq        axi_seq;
    apb_slave_reactive_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_reactive_seq::type_id::create("apb_seq");
        apb_seq.num_trans    = 2;
        apb_seq.wait_cycles  = 0;
        apb_seq.inject_error = 1'b1; // Inject PSLVERR
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_pslverr_seq::type_id::create("axi_seq");
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_pslverr_vseq


// -----------------------------------------------------------------------------
// VSeq 12: Constrained-Random Multi-Transfer Virtual Sequence
// -----------------------------------------------------------------------------
class axi2apb_constrained_random_vseq extends axi2apb_base_vseq;
  `uvm_object_utils(axi2apb_constrained_random_vseq)

  int unsigned num_transactions = 20;

  function new(string name = "axi2apb_constrained_random_vseq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_constrained_random_seq    axi_seq;
    apb_slave_random_response_seq apb_seq;

    fork
      begin : apb_thread
        apb_seq = apb_slave_random_response_seq::type_id::create("apb_seq");
        apb_seq.num_trans = num_transactions;
        apb_seq.start(p_sequencer.apb_seqr);
      end : apb_thread

      begin : axi_thread
        axi_seq = axi_constrained_random_seq::type_id::create("axi_seq");
        axi_seq.num_trans = num_transactions;
        axi_seq.start(p_sequencer.axi_seqr);
      end : axi_thread
    join
  endtask : body
endclass : axi2apb_constrained_random_vseq

`endif // AXI2APB_VIRTUAL_SEQUENCES_SV
