// ==============================================================================
// File: axi_master_item.sv
// Description: AXI4 transaction sequence item for AXI master agent.
//              Models single-beat 32-bit AXI4 read and write requests,
//              backpressure delays, and captured DUT responses.
// ==============================================================================

`ifndef AXI_MASTER_ITEM_SV
`define AXI_MASTER_ITEM_SV

class axi_master_item extends uvm_sequence_item;

  // ---------------------------------------------------------------------------
  // Request Fields (Driven to DUT)
  // ---------------------------------------------------------------------------
  rand bit          write; // 1 = Write, 0 = Read
  rand bit [31:0]   addr;
  rand bit [31:0]   data;
  rand bit [15:0]   id;
  rand bit [9:0]    user;

  rand bit [7:0]    len;
  rand bit [2:0]    size;
  rand bit [1:0]    burst;
  rand bit          lock;
  rand bit [3:0]    cache;
  rand bit [2:0]    prot;
  rand bit [3:0]    region;
  rand bit [3:0]    qos;
  rand bit [3:0]    strb;
  rand bit          last;

  // ---------------------------------------------------------------------------
  // Backpressure Control Fields (Testbench timing control)
  // ---------------------------------------------------------------------------
  rand int unsigned bready_delay;
  rand int unsigned rready_delay;

  // ---------------------------------------------------------------------------
  // Response Fields (Captured from DUT)
  // ---------------------------------------------------------------------------
  bit [1:0]         resp;
  bit [31:0]        read_data;
  bit [15:0]        response_id;
  bit [9:0]         response_user;
  bit               response_last;

  // ---------------------------------------------------------------------------
  // Constraints
  // ---------------------------------------------------------------------------
  // Default single-beat 32-bit transfer (as supported by axi2apb bridge)
  constraint single_beat_c {
    len    == 8'd0;
    size   == 3'd2;      // 4 bytes = 32 bits
    burst  == 2'b01;     // INCR
    lock   == 1'b0;
    cache  == 4'b0000;
    prot   == 3'b000;
    region == 4'b0000;
    qos    == 4'b0000;
    strb   == 4'hF;
    last   == 1'b1;
  }

  // 32-bit aligned address
  constraint aligned_addr_c {
    addr[1:0] == 2'b00;
  }

  // Backpressure delay bounds
  constraint backpressure_delay_c {
    bready_delay inside {[0:10]};
    rready_delay inside {[0:10]};
  }

  // ---------------------------------------------------------------------------
  // UVM Automation Macros
  // ---------------------------------------------------------------------------
  `uvm_object_utils_begin(axi_master_item)
    `uvm_field_int(write,          UVM_DEFAULT)
    `uvm_field_int(addr,           UVM_HEX)
    `uvm_field_int(data,           UVM_HEX)
    `uvm_field_int(id,             UVM_HEX)
    `uvm_field_int(user,           UVM_HEX)
    `uvm_field_int(len,            UVM_DEFAULT)
    `uvm_field_int(size,           UVM_DEFAULT)
    `uvm_field_int(burst,          UVM_DEFAULT)
    `uvm_field_int(lock,           UVM_DEFAULT)
    `uvm_field_int(cache,          UVM_DEFAULT)
    `uvm_field_int(prot,           UVM_DEFAULT)
    `uvm_field_int(region,         UVM_DEFAULT)
    `uvm_field_int(qos,            UVM_DEFAULT)
    `uvm_field_int(strb,           UVM_DEFAULT)
    `uvm_field_int(last,           UVM_DEFAULT)
    `uvm_field_int(bready_delay,   UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(rready_delay,   UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(resp,           UVM_DEFAULT)
    `uvm_field_int(read_data,      UVM_HEX)
    `uvm_field_int(response_id,    UVM_HEX)
    `uvm_field_int(response_user,  UVM_HEX)
    `uvm_field_int(response_last,  UVM_DEFAULT)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_master_item");
    super.new(name);
    bready_delay = 0;
    rready_delay = 0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // convert2string
  // ---------------------------------------------------------------------------
  virtual function string convert2string();
    if (write) begin
      return $sformatf("AXI_WRITE: addr=0x%08h data=0x%08h id=0x%04h user=0x%03h resp=%0b (bid=0x%04h buser=0x%03h)",
                       addr, data, id, user, resp, response_id, response_user);
    end else begin
      return $sformatf("AXI_READ : addr=0x%08h rdata=0x%08h id=0x%04h user=0x%03h resp=%0b (rid=0x%04h ruser=0x%03h rlast=%0b)",
                       addr, read_data, id, user, resp, response_id, response_user, response_last);
    end
  endfunction : convert2string

endclass : axi_master_item

`endif // AXI_MASTER_ITEM_SV
