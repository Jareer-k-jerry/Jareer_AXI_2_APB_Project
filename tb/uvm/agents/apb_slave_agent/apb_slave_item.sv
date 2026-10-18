// ==============================================================================
// File: apb_slave_item.sv
// Description: APB slave sequence item.
//              Contains response controls (wait states, error injection, default read data)
//              and captures observed APB transfer signals.
// ==============================================================================

`ifndef APB_SLAVE_ITEM_SV
`define APB_SLAVE_ITEM_SV

class apb_slave_item extends uvm_sequence_item;

  // ---------------------------------------------------------------------------
  // Response Control Configuration (Driven by sequence to control slave behavior)
  // ---------------------------------------------------------------------------
  rand int unsigned wait_cycles;       // Number of wait cycles (PREADY=0) before completion
  rand bit          inject_error;      // 1 = Assert PSLVERR
  rand bit [31:0]   default_read_data; // Data to return if address not in slave memory

  // ---------------------------------------------------------------------------
  // Monitored / Observed APB Transfer Fields (Captured from APB bus)
  // ---------------------------------------------------------------------------
  bit [31:0] addr;
  bit        write;
  bit [31:0] write_data;
  bit [31:0] read_data;
  bit        pslverr;

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------
  constraint wait_c {
    wait_cycles inside {[0:10]};
  }

  // ---------------------------------------------------------------------------
  // UVM Automation Macros
  // ---------------------------------------------------------------------------
  `uvm_object_utils_begin(apb_slave_item)
    `uvm_field_int(wait_cycles,       UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(inject_error,      UVM_DEFAULT)
    `uvm_field_int(default_read_data, UVM_HEX)
    `uvm_field_int(addr,              UVM_HEX)
    `uvm_field_int(write,             UVM_DEFAULT)
    `uvm_field_int(write_data,        UVM_HEX)
    `uvm_field_int(read_data,         UVM_HEX)
    `uvm_field_int(pslverr,           UVM_DEFAULT)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "apb_slave_item");
    super.new(name);
    wait_cycles       = 0;
    inject_error      = 1'b0;
    default_read_data = 32'h0000_0000;
  endfunction : new

  // ---------------------------------------------------------------------------
  // convert2string
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    if (write) begin
      return $sformatf("APB_WRITE: addr=0x%08h wdata=0x%08h wait=%0d pslverr=%0b",
                       addr, write_data, wait_cycles, pslverr);
    end else begin
      return $sformatf("APB_READ : addr=0x%08h rdata=0x%08h wait=%0d pslverr=%0b",
                       addr, read_data, wait_cycles, pslverr);
    end
  endfunction : convert2string

endclass : apb_slave_item

`endif // APB_SLAVE_ITEM_SV
