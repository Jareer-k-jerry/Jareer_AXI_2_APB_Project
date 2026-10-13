// ==============================================================================
// File: axi_master_seq.sv
// Description: Directed sequences for AXI master validation.
//              Provides single write, single read, and write-then-read sequences.
// ==============================================================================

`ifndef AXI_MASTER_SEQ_SV
`define AXI_MASTER_SEQ_SV

// -----------------------------------------------------------------------------
// Sequence 1: Directed Single Write
// -----------------------------------------------------------------------------
class axi_single_write_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_single_write_seq)

  bit [31:0] target_addr = 32'h0000_1000;
  bit [31:0] write_data  = 32'hDEAD_BEEF;
  bit [15:0] trans_id    = 16'h0001;
  bit [9:0]  user_val    = 10'h00A;
  int unsigned bready_delay = 0;

  function new(string name = "axi_single_write_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item;
    item = axi_master_item::type_id::create("axi_write_item");

    start_item(item);
    if (!item.randomize() with {
      write        == 1'b1;
      addr         == local::target_addr;
      data         == local::write_data;
      id           == local::trans_id;
      user         == local::user_val;
      bready_delay == local::bready_delay;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_single_write_seq")
    end
    finish_item(item);

    `uvm_info(get_type_name(), $sformatf("Completed directed WRITE: addr=0x%08h data=0x%08h resp=%0b",
                                        item.addr, item.data, item.resp), UVM_LOW)
  endtask : body
endclass : axi_single_write_seq

// -----------------------------------------------------------------------------
// Sequence 2: Directed Single Read
// -----------------------------------------------------------------------------
class axi_single_read_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_single_read_seq)

  bit [31:0] target_addr = 32'h0000_1000;
  bit [15:0] trans_id    = 16'h0002;
  bit [9:0]  user_val    = 10'h00B;
  int unsigned rready_delay = 0;

  function new(string name = "axi_single_read_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item;
    item = axi_master_item::type_id::create("axi_read_item");

    start_item(item);
    if (!item.randomize() with {
      write        == 1'b0;
      addr         == local::target_addr;
      id           == local::trans_id;
      user         == local::user_val;
      rready_delay == local::rready_delay;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_single_read_seq")
    end
    finish_item(item);

    `uvm_info(get_type_name(), $sformatf("Completed directed READ : addr=0x%08h rdata=0x%08h resp=%0b",
                                        item.addr, item.read_data, item.resp), UVM_LOW)
  endtask : body
endclass : axi_single_read_seq

// -----------------------------------------------------------------------------
// Sequence 3: Directed Write Followed by Read
// -----------------------------------------------------------------------------
class axi_write_then_read_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_write_then_read_seq)

  function new(string name = "axi_write_then_read_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_single_write_seq wr_seq;
    axi_single_read_seq  rd_seq;

    wr_seq = axi_single_write_seq::type_id::create("wr_seq");
    rd_seq = axi_single_read_seq::type_id::create("rd_seq");

    wr_seq.target_addr = 32'h0000_2000;
    wr_seq.write_data  = 32'h1234_5678;
    wr_seq.trans_id    = 16'h0010;
    wr_seq.start(m_sequencer);

    rd_seq.target_addr = 32'h0000_2000;
    rd_seq.trans_id    = 16'h0020;
    rd_seq.start(m_sequencer);
  endtask : body
endclass : axi_write_then_read_seq

`endif // AXI_MASTER_SEQ_SV
