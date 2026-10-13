// ==============================================================================
// File: apb_slave_monitor.sv
// Description: Passive APB monitor observing completed APB transfers
//              (PSEL && PENABLE && PREADY == 1) and publishing to uvm_analysis_port.
// ==============================================================================

`ifndef APB_SLAVE_MONITOR_SV
`define APB_SLAVE_MONITOR_SV

class apb_slave_monitor extends uvm_monitor;
  `uvm_component_utils(apb_slave_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_slave_item) analysis_port;

  function new(string name = "apb_slave_monitor", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif)) begin
        `uvm_fatal(get_type_name(), "virtual apb_if not found in uvm_config_db under 'vif' or 'apb_vif'")
      end
    end
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "run_phase: APB slave monitor active", UVM_LOW)

    // Wait until reset is de-asserted
    wait (vif.PRESETn === 1'b1);
    @(vif.monitor_cb);

    forever begin
      // Sample at the completion edge when PSEL, PENABLE, and PREADY are all high
      do begin
        @(vif.monitor_cb);
      end while (!(vif.monitor_cb.psel && vif.monitor_cb.penable && vif.monitor_cb.pready));

      begin
        apb_slave_item tr;
        tr = apb_slave_item::type_id::create("monitored_apb_transfer");

        tr.addr       = vif.monitor_cb.paddr;
        tr.write      = vif.monitor_cb.pwrite;
        tr.write_data = vif.monitor_cb.pwdata;
        tr.read_data  = vif.monitor_cb.prdata;
        tr.pslverr    = vif.monitor_cb.pslverr;

        `uvm_info(get_type_name(), $sformatf("Observed Complete APB Transfer: %s", tr.convert2string()), UVM_MEDIUM)
        analysis_port.write(tr);
      end

      // Wait until PENABLE de-asserts to prevent double-sampling
      do begin
        @(vif.monitor_cb);
      end while (vif.monitor_cb.penable);
    end
  endtask : run_phase

endclass : apb_slave_monitor

`endif // APB_SLAVE_MONITOR_SV
