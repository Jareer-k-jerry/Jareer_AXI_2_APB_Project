// ==============================================================================
// File: axi_master_driver.sv
// Description: AXI4 master driver handling pin-level handshakes with DUT.
//              Implements independent AW and W channel drives, B response capture,
//              AR channel drive, and R data reception with programmable backpressure.
// ==============================================================================

`ifndef AXI_MASTER_DRIVER_SV
`define AXI_MASTER_DRIVER_SV

class axi_master_driver extends uvm_driver #(axi_master_item);
  `uvm_component_utils(axi_master_driver)

  virtual axi4_if vif;

  function new(string name = "axi_master_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), "build_phase: fetching virtual interface", UVM_HIGH)

    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      if (!uvm_config_db#(virtual axi4_if)::get(this, "", "axi_vif", vif)) begin
        `uvm_fatal(get_type_name(), "virtual axi4_if not found in uvm_config_db under 'vif' or 'axi_vif'")
      end
    end
  endfunction : build_phase

  virtual task drive_idle();
    vif.master_cb.awvalid <= 1'b0;
    vif.master_cb.wvalid  <= 1'b0;
    vif.master_cb.bready  <= 1'b0;
    vif.master_cb.arvalid <= 1'b0;
    vif.master_cb.rready  <= 1'b0;
  endtask : drive_idle

  virtual task run_phase(uvm_phase phase);
    axi_master_item tr;

    `uvm_info(get_type_name(), "run_phase: AXI master driver active", UVM_HIGH)
    drive_idle();

    // Wait until reset is de-asserted
    wait (vif.ARESETn === 1'b1);
    @(vif.master_cb);

    forever begin
      seq_item_port.get_next_item(tr);

      if (tr.write) begin
        drive_write(tr);
      end else begin
        drive_read(tr);
      end

      seq_item_port.item_done();
    end
  endtask : run_phase

  // ---------------------------------------------------------------------------
  // AXI Write Operation
  // ---------------------------------------------------------------------------
  virtual task drive_write(axi_master_item tr);
    `uvm_info(get_type_name(), $sformatf("Driving WRITE: addr=0x%08h data=0x%08h id=0x%04h",
                                        tr.addr, tr.data, tr.id), UVM_MEDIUM)

    vif.master_cb.bready <= 1'b0;

    // Drive AW and W channels concurrently
    fork
      // Write Address Channel
      begin : drive_aw
        @(vif.master_cb);
        vif.master_cb.awid     <= tr.id;
        vif.master_cb.awaddr   <= tr.addr;
        vif.master_cb.awlen    <= tr.len;
        vif.master_cb.awsize   <= tr.size;
        vif.master_cb.awburst  <= tr.burst;
        vif.master_cb.awlock   <= tr.lock;
        vif.master_cb.awcache  <= tr.cache;
        vif.master_cb.awprot   <= tr.prot;
        vif.master_cb.awregion <= tr.region;
        vif.master_cb.awuser   <= tr.user;
        vif.master_cb.awqos    <= tr.qos;
        vif.master_cb.awvalid  <= 1'b1;

        do begin
          @(vif.master_cb);
        end while (vif.master_cb.awready !== 1'b1);

        vif.master_cb.awvalid <= 1'b0;
      end : drive_aw

      // Write Data Channel
      begin : drive_w
        @(vif.master_cb);
        vif.master_cb.wdata  <= tr.data;
        vif.master_cb.wstrb  <= tr.strb;
        vif.master_cb.wlast  <= tr.last;
        vif.master_cb.wuser  <= tr.user;
        vif.master_cb.wvalid <= 1'b1;

        do begin
          @(vif.master_cb);
        end while (vif.master_cb.wready !== 1'b1);

        vif.master_cb.wvalid <= 1'b0;
      end : drive_w
    join

    // Write Response Channel (B Channel)
    do begin
      @(vif.master_cb);
    end while (vif.master_cb.bvalid !== 1'b1);

    // Apply programmable BREADY delay
    if (tr.bready_delay > 0) begin
      `uvm_info(get_type_name(), $sformatf("BVALID asserted: delaying BREADY by %0d cycles", tr.bready_delay), UVM_HIGH)
      repeat (tr.bready_delay) begin
        vif.master_cb.bready <= 1'b0;
        @(vif.master_cb);
      end
    end

    // Assert BREADY and complete handshake
    vif.master_cb.bready <= 1'b1;

    do begin
      @(vif.master_cb);
    end while (vif.master_cb.bvalid !== 1'b1);

    // Sample response signals
    tr.resp          = vif.master_cb.bresp;
    tr.response_id   = vif.master_cb.bid;
    tr.response_user = vif.master_cb.buser;

    `uvm_info(get_type_name(), $sformatf("WRITE HANDSHAKE COMPLETE: BID=0x%04h BRESP=%0b", tr.response_id, tr.resp), UVM_MEDIUM)

    // Deassert BREADY after transaction completes
    vif.master_cb.bready <= 1'b0;
  endtask : drive_write

  // ---------------------------------------------------------------------------
  // AXI Read Operation
  // ---------------------------------------------------------------------------
  virtual task drive_read(axi_master_item tr);
    `uvm_info(get_type_name(), $sformatf("Driving READ: addr=0x%08h id=0x%04h", tr.addr, tr.id), UVM_MEDIUM)

    vif.master_cb.rready <= 1'b0;

    // Read Address Channel
    @(vif.master_cb);
    vif.master_cb.arid     <= tr.id;
    vif.master_cb.araddr   <= tr.addr;
    vif.master_cb.arlen    <= tr.len;
    vif.master_cb.arsize   <= tr.size;
    vif.master_cb.arburst  <= tr.burst;
    vif.master_cb.arlock   <= tr.lock;
    vif.master_cb.arcache  <= tr.cache;
    vif.master_cb.arprot   <= tr.prot;
    vif.master_cb.arregion <= tr.region;
    vif.master_cb.aruser   <= tr.user;
    vif.master_cb.arqos    <= tr.qos;
    vif.master_cb.arvalid  <= 1'b1;

    do begin
      @(vif.master_cb);
    end while (vif.master_cb.arready !== 1'b1);

    vif.master_cb.arvalid <= 1'b0;

    // Read Data Channel (R Channel)
    do begin
      @(vif.master_cb);
    end while (vif.master_cb.rvalid !== 1'b1);

    // Apply programmable RREADY delay
    if (tr.rready_delay > 0) begin
      `uvm_info(get_type_name(), $sformatf("RVALID asserted: delaying RREADY by %0d cycles", tr.rready_delay), UVM_HIGH)
      repeat (tr.rready_delay) begin
        vif.master_cb.rready <= 1'b0;
        @(vif.master_cb);
      end
    end

    // Assert RREADY and complete handshake
    vif.master_cb.rready <= 1'b1;

    do begin
      @(vif.master_cb);
    end while (vif.master_cb.rvalid !== 1'b1);

    // Sample response signals
    tr.read_data     = vif.master_cb.rdata;
    tr.resp          = vif.master_cb.rresp;
    tr.response_id   = vif.master_cb.rid;
    tr.response_user = vif.master_cb.ruser;
    tr.response_last = vif.master_cb.rlast;

    `uvm_info(get_type_name(), $sformatf("READ HANDSHAKE COMPLETE: RID=0x%04h RDATA=0x%08h RRESP=%0b RLAST=%0b",
                                        tr.response_id, tr.read_data, tr.resp, tr.response_last), UVM_MEDIUM)

    // Deassert RREADY after transaction completes
    vif.master_cb.rready <= 1'b0;
  endtask : drive_read

endclass : axi_master_driver

`endif // AXI_MASTER_DRIVER_SV
