// ==============================================================================
// File: apb_slave_seq.sv
// Description: APB slave response sequences.
//              Provides reactive response sequences with configurable wait cycles,
//              PRDATA, and PSLVERR injection.
// ==============================================================================

`ifndef APB_SLAVE_SEQ_SV
`define APB_SLAVE_SEQ_SV

// -----------------------------------------------------------------------------
// Sequence 1: Single APB Slave Response
// -----------------------------------------------------------------------------
class apb_slave_single_response_seq extends uvm_sequence #(apb_slave_item);
  `uvm_object_utils(apb_slave_single_response_seq)

  int unsigned wait_cycles       = 0;
  bit          inject_error      = 1'b0;
  bit [31:0]   default_read_data = 32'h0000_0000;

  function new(string name = "apb_slave_single_response_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    apb_slave_item item;
    item = apb_slave_item::type_id::create("apb_resp_item");

    start_item(item);
    if (!item.randomize() with {
      wait_cycles       == local::wait_cycles;
      inject_error      == local::inject_error;
      default_read_data == local::default_read_data;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed in apb_slave_single_response_seq")
    end
    finish_item(item);
  endtask : body
endclass : apb_slave_single_response_seq

// -----------------------------------------------------------------------------
// Sequence 2: Multi-Transfer Reactive Sequence
// -----------------------------------------------------------------------------
class apb_slave_reactive_seq extends uvm_sequence #(apb_slave_item);
  `uvm_object_utils(apb_slave_reactive_seq)

  int unsigned num_trans         = 10;
  int unsigned wait_cycles       = 0;
  bit          inject_error      = 1'b0;
  bit [31:0]   default_read_data = 32'h0000_0000;

  function new(string name = "apb_slave_reactive_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    repeat (num_trans) begin
      apb_slave_item item;
      item = apb_slave_item::type_id::create("apb_resp_item");

      start_item(item);
      if (!item.randomize() with {
        wait_cycles       == local::wait_cycles;
        inject_error      == local::inject_error;
        default_read_data == local::default_read_data;
      }) begin
        `uvm_fatal(get_type_name(), "Randomization failed in apb_slave_reactive_seq")
      end
      finish_item(item);
    end
  endtask : body
endclass : apb_slave_reactive_seq

`endif // APB_SLAVE_SEQ_SV
