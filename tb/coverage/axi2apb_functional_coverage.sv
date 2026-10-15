// ==============================================================================
// File: axi2apb_functional_coverage.sv
// Description: Functional coverage collector for AXI4-to-APB bridge verification.
//              Contains covergroups measuring AXI transaction attributes, APB
//              transfer properties, wait states, response values, and crosses.
//              Subscribes to analysis ports from AXI master and APB slave agents.
// ==============================================================================

`ifndef AXI2APB_FUNCTIONAL_COVERAGE_SV
`define AXI2APB_FUNCTIONAL_COVERAGE_SV

`uvm_analysis_imp_decl(_axi_cov)
`uvm_analysis_imp_decl(_apb_cov)

class axi2apb_functional_coverage extends uvm_component;
  `uvm_component_utils(axi2apb_functional_coverage)

  // ---------------------------------------------------------------------------
  // TLM Analysis Exports
  // ---------------------------------------------------------------------------
  uvm_analysis_imp_axi_cov #(axi_master_item, axi2apb_functional_coverage) axi_cov_export;
  uvm_analysis_imp_apb_cov #(apb_slave_item,  axi2apb_functional_coverage) apb_cov_export;

  // Transaction holders for sampling
  axi_master_item axi_item;
  apb_slave_item  apb_item;

  // Sampling counters
  int unsigned axi_sample_count;
  int unsigned apb_sample_count;

  // ---------------------------------------------------------------------------
  // Covergroup 1: AXI Transaction Coverage
  // Measures write/read direction, address ranges, response status, ID and USER.
  // ---------------------------------------------------------------------------
  covergroup axi_cg;
    option.per_instance = 1;
    option.name         = "axi_transaction_coverage";

    // Transfer direction
    cp_direction: coverpoint axi_item.write {
      bins write_trans = {1'b1};
      bins read_trans  = {1'b0};
    }

    // Address partitioning (word-aligned 32-bit addresses)
    cp_addr: coverpoint axi_item.addr {
      bins low_addr   = {[32'h0000_0000 : 32'h0000_0FFF]};
      bins mid_addr_1 = {[32'h0000_1000 : 32'h0000_1FFF]};
      bins mid_addr_2 = {[32'h0000_2000 : 32'h0000_3FFF]};
      bins high_addr  = {[32'h0000_4000 : 32'hFFFF_FFFC]};
    }

    // Response status: DUT RTL (axi2apb.sv) exclusively returns OKAY (2'b00).
    // Other values are unreachable in this RTL and ignored to prevent deflated coverage metrics.
    cp_resp: coverpoint axi_item.resp {
      bins okay          = {2'b00};
      ignore_bins others = {2'b01, 2'b10, 2'b11};
    }

    // Transaction ID (16-bit field in transaction, sampled across ID bins)
    cp_id: coverpoint axi_item.id[7:0] {
      bins id_zero = {8'h00};
      bins id_low  = {[8'h01 : 8'h0F]};
      bins id_mid  = {[8'h10 : 8'h7F]};
      bins id_high = {[8'h80 : 8'hFF]};
    }

    // AXI USER signal (10-bit field in transaction/RTL)
    cp_user: coverpoint axi_item.user[7:0] {
      bins user_zero = {8'h00};
      bins user_low  = {[8'h01 : 8'h7F]};
      bins user_high = {[8'h80 : 8'hFF]};
    }

    // Cross: Direction vs Address space
    cx_dir_addr: cross cp_direction, cp_addr;

    // Cross: Direction vs Response
    cx_dir_resp: cross cp_direction, cp_resp;
  endgroup : axi_cg

  // ---------------------------------------------------------------------------
  // Covergroup 2: APB Transfer Coverage
  // Measures APB transfer direction, address ranges, wait states, and PSLVERR.
  // ---------------------------------------------------------------------------
  covergroup apb_cg;
    option.per_instance = 1;
    option.name         = "apb_transfer_coverage";

    // APB Direction
    cp_apb_write: coverpoint apb_item.write {
      bins apb_write = {1'b1};
      bins apb_read  = {1'b0};
    }

    // APB Address
    cp_apb_addr: coverpoint apb_item.addr {
      bins low_addr   = {[32'h0000_0000 : 32'h0000_0FFF]};
      bins mid_addr_1 = {[32'h0000_1000 : 32'h0000_1FFF]};
      bins mid_addr_2 = {[32'h0000_2000 : 32'h0000_3FFF]};
      bins high_addr  = {[32'h0000_4000 : 32'hFFFF_FFFC]};
    }

    // Wait states (0 wait cycles, short wait, extended wait)
    cp_wait_cycles: coverpoint apb_item.wait_cycles {
      bins zero_wait  = {0};
      bins wait_1_2   = {[1:2]};
      bins wait_3_4   = {[3:4]};
      bins wait_5_max = {[5:10]};
    }

    // Slave error indicator
    cp_pslverr: coverpoint apb_item.pslverr {
      bins no_error = {1'b0};
      bins error    = {1'b1};
    }

    // Cross: Direction vs Wait cycles (measures 0-wait and wait states for both R/W)
    cx_dir_wait: cross cp_apb_write, cp_wait_cycles;

    // Cross: Direction vs PSLVERR
    cx_dir_err: cross cp_apb_write, cp_pslverr;
  endgroup : apb_cg

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi2apb_functional_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi_cg = new();
    apb_cg = new();
    axi_cov_export = new("axi_cov_export", this);
    apb_cov_export = new("apb_cov_export", this);
    axi_sample_count = 0;
    apb_sample_count = 0;
  endfunction : new

  // ---------------------------------------------------------------------------
  // AXI Write Analysis Callback
  // ---------------------------------------------------------------------------
  virtual function void write_axi_cov(axi_master_item tr);
    this.axi_item = tr;
    axi_cg.sample();
    axi_sample_count++;
  endfunction : write_axi_cov

  // ---------------------------------------------------------------------------
  // APB Write Analysis Callback
  // ---------------------------------------------------------------------------
  virtual function void write_apb_cov(apb_slave_item tr);
    this.apb_item = tr;
    apb_cg.sample();
    apb_sample_count++;
  endfunction : write_apb_cov

  // ---------------------------------------------------------------------------
  // Report Phase: Coverage metrics saved to simv.vdb and viewed via urgReport
  // ---------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
  endfunction : report_phase

endclass : axi2apb_functional_coverage

`endif // AXI2APB_FUNCTIONAL_COVERAGE_SV
