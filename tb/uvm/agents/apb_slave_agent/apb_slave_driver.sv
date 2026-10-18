// ==============================================================================
// File: apb_slave_driver.sv
// Description: Reactive APB slave driver.
//              Detects DUT-generated APB requests (PSEL && PENABLE),
//              applies programmable wait states (PREADY low), provides configurable
//              PRDATA via internal associative memory or sequence values,
//              and supports configurable PSLVERR error responses.
// ==============================================================================

`ifndef APB_SLAVE_DRIVER_SV
`define APB_SLAVE_DRIVER_SV

class apb_slave_driver extends uvm_driver #(apb_slave_item);
  `uvm_component_utils(apb_slave_driver)

  virtual apb_if vif;

  // Internal associative memory model: mirrors written data for subsequent reads
  bit [31:0] memory [bit [31:0]];

  function new(string name = "apb_slave_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif)) begin
        `uvm_fatal(get_type_name(), "virtual apb_if not found in uvm_config_db under 'vif' or 'apb_vif'")
      end
    end
  endfunction : build_phase

  virtual task drive_idle();
    vif.slave_cb.pready  <= 1'b0;
    vif.slave_cb.prdata  <= '0;
    vif.slave_cb.pslverr <= 1'b0;
  endtask : drive_idle

  virtual task run_phase(uvm_phase phase);
    apb_slave_item rsp;
    bit [31:0] current_addr;
    bit        current_write;
    bit [31:0] current_wdata;
    bit [31:0] response_data;

    `uvm_info(get_type_name(), "run_phase: APB slave driver active", UVM_HIGH)
    drive_idle();

    // Wait until reset is de-asserted
    wait (vif.PRESETn === 1'b1);
    @(vif.slave_cb);

    forever begin
      // Pull reactive response parameters from sequencer
      seq_item_port.get_next_item(rsp);

      // For 0 wait states, assert PREADY and default PRDATA ahead of time
      // so PREADY is sampled HIGH on the very first ACCESS cycle (0-wait APB completion)
      if (rsp.wait_cycles == 0) begin
        vif.slave_cb.pready  <= 1'b1;
        vif.slave_cb.prdata  <= rsp.default_read_data;
        vif.slave_cb.pslverr <= rsp.inject_error;
      end else begin
        vif.slave_cb.pready  <= 1'b0;
      end

      // Detect APB request from DUT bridge: PSEL && PENABLE active
      do begin
        @(vif.slave_cb);
      end while (!(vif.slave_cb.psel && vif.slave_cb.penable));

      // Sample incoming APB request signals
      current_addr  = vif.slave_cb.paddr;
      current_write = vif.slave_cb.pwrite;
      current_wdata = vif.slave_cb.pwdata;

      `uvm_info(get_type_name(), $sformatf("Detected APB Request: write=%0b addr=0x%08h wdata=0x%08h | wait_cycles=%0d inject_error=%0b",
                                          current_write, current_addr, current_wdata, rsp.wait_cycles, rsp.inject_error), UVM_MEDIUM)

      // Apply programmable wait cycles (holding PREADY low) if wait_cycles > 0
      if (rsp.wait_cycles > 0) begin
        vif.slave_cb.pready <= 1'b0;
        if (rsp.wait_cycles > 1) begin
          repeat (rsp.wait_cycles - 1) begin
            @(vif.slave_cb);
          end
        end

        // Determine response read data
        if (current_write) begin
          response_data = '0;
        end else if (memory.exists(current_addr)) begin
          response_data = memory[current_addr];
        end else begin
          response_data = rsp.default_read_data;
        end

        vif.slave_cb.prdata  <= response_data;
        vif.slave_cb.pslverr <= rsp.inject_error;
        vif.slave_cb.pready  <= 1'b1;

        // Complete wait-state transfer on next rising clock edge
        @(vif.slave_cb);
      end else begin
        // 0-wait state: update response_data for reporting/memory
        if (current_write) begin
          response_data = '0;
        end else if (memory.exists(current_addr)) begin
          response_data = memory[current_addr];
        end else begin
          response_data = rsp.default_read_data;
        end
      end

      // On successful write, update internal memory
      if (current_write && !rsp.inject_error) begin
        memory[current_addr] = current_wdata;
        `uvm_info(get_type_name(), $sformatf("Stored in APB Memory: addr=0x%08h data=0x%08h", current_addr, current_wdata), UVM_HIGH)
      end

      // Record captured values into response item
      rsp.addr       = current_addr;
      rsp.write      = current_write;
      rsp.write_data = current_wdata;
      rsp.read_data  = response_data;
      rsp.pslverr    = rsp.inject_error;

      `uvm_info(get_type_name(), $sformatf("Completed APB Transfer: %s", rsp.convert2string()), UVM_MEDIUM)

      // Return slave interface back to idle state
      vif.slave_cb.pready  <= 1'b0;
      vif.slave_cb.pslverr <= 1'b0;
      vif.slave_cb.prdata  <= '0;

      seq_item_port.item_done();

      // Ensure PENABLE de-assertion before detecting next request
      do begin
        @(vif.slave_cb);
      end while (vif.slave_cb.penable);
    end
  endtask : run_phase

endclass : apb_slave_driver

`endif // APB_SLAVE_DRIVER_SV
