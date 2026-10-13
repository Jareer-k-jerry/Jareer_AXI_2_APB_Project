// ==============================================================================
// File: axi_master_monitor.sv
// Description: Passive AXI4 monitor. Observes pin-level transactions on clock edges,
//              reconstructs high-level AXI write and read sequence items, and broadcasts
//              them via uvm_analysis_port.
// ==============================================================================

`ifndef AXI_MASTER_MONITOR_SV
`define AXI_MASTER_MONITOR_SV

class axi_master_monitor extends uvm_monitor;
  `uvm_component_utils(axi_master_monitor)

  virtual axi4_if vif;
  uvm_analysis_port #(axi_master_item) analysis_port;

  function new(string name = "axi_master_monitor", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      if (!uvm_config_db#(virtual axi4_if)::get(this, "", "axi_vif", vif)) begin
        `uvm_fatal(get_type_name(), "virtual axi4_if not found in uvm_config_db under 'vif' or 'axi_vif'")
      end
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "run_phase: AXI master monitor active", UVM_LOW)

    // Wait until reset is de-asserted
    wait (vif.ARESETn === 1'b1);
    @(vif.monitor_cb);

    fork
      monitor_write_channel();
      monitor_read_channel();
    join
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // Write Channel Monitor (AW, W, B channels)
  // ---------------------------------------------------------------------------
  virtual task monitor_write_channel();
    bit [31:0] address;
    bit [31:0] write_data;
    bit [15:0] request_id;
    bit [9:0]  request_user;
    bit        got_aw;
    bit        got_w;

    forever begin
      got_aw = 1'b0;
      got_w  = 1'b0;

      // Capture AW and W independently (can occur in same cycle or separate cycles)
      while (!(got_aw && got_w)) begin
        @(vif.monitor_cb);

        if (!got_aw && vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
          address      = vif.monitor_cb.awaddr;
          request_id   = vif.monitor_cb.awid;
          request_user = vif.monitor_cb.awuser;
          got_aw       = 1'b1;
          `uvm_info(get_type_name(), $sformatf("Observed AW Handshake: addr=0x%08h id=0x%04h", address, request_id), UVM_HIGH)
        end

        if (!got_w && vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
          write_data = vif.monitor_cb.wdata;
          got_w      = 1'b1;
          `uvm_info(get_type_name(), $sformatf("Observed W Handshake: data=0x%08h", write_data), UVM_HIGH)
        end
      end

      // Wait for B response handshake
      while (1) begin
        @(vif.monitor_cb);
        if (vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
          axi_master_item tr;
          tr = axi_master_item::type_id::create("monitored_axi_write");

          tr.write         = 1'b1;
          tr.addr          = address;
          tr.data          = write_data;
          tr.id            = request_id;
          tr.user          = request_user;
          tr.resp          = vif.monitor_cb.bresp;
          tr.response_id   = vif.monitor_cb.bid;
          tr.response_user = vif.monitor_cb.buser;

          `uvm_info(get_type_name(), $sformatf("Observed Complete AXI WRITE: %s", tr.convert2string()), UVM_MEDIUM)
          analysis_port.write(tr);
          break;
        end
      end
    end
  endtask : monitor_write_channel

  // ---------------------------------------------------------------------------
  // Read Channel Monitor (AR, R channels)
  // ---------------------------------------------------------------------------
  virtual task monitor_read_channel();
    bit [31:0] address;
    bit [15:0] request_id;
    bit [9:0]  request_user;

    forever begin
      // Wait for AR handshake
      while (1) begin
        @(vif.monitor_cb);
        if (vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
          address      = vif.monitor_cb.araddr;
          request_id   = vif.monitor_cb.arid;
          request_user = vif.monitor_cb.aruser;
          `uvm_info(get_type_name(), $sformatf("Observed AR Handshake: addr=0x%08h id=0x%04h", address, request_id), UVM_HIGH)
          break;
        end
      end

      // Wait for R handshake
      while (1) begin
        @(vif.monitor_cb);
        if (vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
          axi_master_item tr;
          tr = axi_master_item::type_id::create("monitored_axi_read");

          tr.write         = 1'b0;
          tr.addr          = address;
          tr.id            = request_id;
          tr.user          = request_user;
          tr.read_data     = vif.monitor_cb.rdata;
          tr.resp          = vif.monitor_cb.rresp;
          tr.response_id   = vif.monitor_cb.rid;
          tr.response_user = vif.monitor_cb.ruser;
          tr.response_last = vif.monitor_cb.rlast;

          `uvm_info(get_type_name(), $sformatf("Observed Complete AXI READ: %s", tr.convert2string()), UVM_MEDIUM)
          analysis_port.write(tr);
          break;
        end
      end
    end
  endtask : monitor_read_channel

endclass : axi_master_monitor

`endif // AXI_MASTER_MONITOR_SV
