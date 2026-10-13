`timescale 1ns/1ps

// ==============================================================================
// File: axi2apb_tb_top.sv
// Description: Top-level testbench module for AXI4-to-APB bridge verification.
//              Provides clock and reset generation, interface instantiations,
//              DUT port connections, uvm_config_db registration, and UVM startup.
// ==============================================================================

module axi2apb_tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi2apb_pkg::*;

  // ---------------------------------------------------------------------------
  // Interface & DUT Parameters (matching RTL defaults in axi2apb.sv)
  // ---------------------------------------------------------------------------
  localparam int AXI_ADDR_WIDTH  = 32;
  localparam int AXI_DATA_WIDTH  = 32;
  localparam int AXI_ID_WIDTH    = 16;
  localparam int AXI_USER_WIDTH  = 10;
  localparam int BUFF_DEPTH      = 4;
  localparam int APB_ADDR_WIDTH  = 32;

  // ---------------------------------------------------------------------------
  // Clock and Reset Signals
  // ---------------------------------------------------------------------------
  logic clk;
  logic reset_n;

  // Clock generation: 100MHz (period = 10ns)
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Asynchronous Active-Low Reset assertion and synchronous release
  initial begin
    reset_n = 1'b0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    reset_n = 1'b1;
  end

  // ---------------------------------------------------------------------------
  // Interfaces
  // ---------------------------------------------------------------------------
  axi4_if #(
    .ADDR_WIDTH (AXI_ADDR_WIDTH),
    .DATA_WIDTH (AXI_DATA_WIDTH),
    .ID_WIDTH   (AXI_ID_WIDTH),
    .USER_WIDTH (AXI_USER_WIDTH)
  ) axi_vif (
    .ACLK    (clk),
    .ARESETn (reset_n)
  );

  apb_if #(
    .ADDR_WIDTH (APB_ADDR_WIDTH),
    .DATA_WIDTH (AXI_DATA_WIDTH)
  ) apb_vif (
    .PCLK    (clk),
    .PRESETn (reset_n)
  );

  // ---------------------------------------------------------------------------
  // Default Bus Signal Initialization (Prevents X/floating states in smoke test)
  // ---------------------------------------------------------------------------
  initial begin
    // AXI Write Address Channel
    axi_vif.awid     = '0;
    axi_vif.awaddr   = '0;
    axi_vif.awlen    = '0;
    axi_vif.awsize   = 3'b010; // 4 bytes (32-bit transfer)
    axi_vif.awburst  = 2'b01;  // INCR
    axi_vif.awlock   = 1'b0;
    axi_vif.awcache  = 4'b0000;
    axi_vif.awprot   = 3'b000;
    axi_vif.awregion = 4'b0000;
    axi_vif.awuser   = '0;
    axi_vif.awqos    = 4'b0000;
    axi_vif.awvalid  = 1'b0;

    // AXI Write Data Channel
    axi_vif.wdata    = '0;
    axi_vif.wstrb    = 4'b1111;
    axi_vif.wlast    = 1'b0;
    axi_vif.wuser    = '0;
    axi_vif.wvalid   = 1'b0;

    // AXI Write Response Channel
    axi_vif.bready   = 1'b1;

    // AXI Read Address Channel
    axi_vif.arid     = '0;
    axi_vif.araddr   = '0;
    axi_vif.arlen    = '0;
    axi_vif.arsize   = 3'b010;
    axi_vif.arburst  = 2'b01;
    axi_vif.arlock   = 1'b0;
    axi_vif.arcache  = 4'b0000;
    axi_vif.arprot   = 3'b000;
    axi_vif.arregion = 4'b0000;
    axi_vif.aruser   = '0;
    axi_vif.arqos    = 4'b0000;
    axi_vif.arvalid  = 1'b0;

    // AXI Read Data Channel
    axi_vif.rready   = 1'b1;

    // APB Slave Side Initial State
    apb_vif.prdata   = '0;
    apb_vif.pready   = 1'b0;
    apb_vif.pslverr  = 1'b0;
  end

  // ---------------------------------------------------------------------------
  // DUT Instantiation (Exact port names matching rtl/axi2apb.sv)
  // ---------------------------------------------------------------------------
  axi2apb #(
    .AXI4_ADDRESS_WIDTH (AXI_ADDR_WIDTH),
    .AXI4_RDATA_WIDTH   (AXI_DATA_WIDTH),
    .AXI4_WDATA_WIDTH   (AXI_DATA_WIDTH),
    .AXI4_ID_WIDTH      (AXI_ID_WIDTH),
    .AXI4_USER_WIDTH    (AXI_USER_WIDTH),
    .BUFF_DEPTH_SLAVE   (BUFF_DEPTH),
    .APB_ADDR_WIDTH     (APB_ADDR_WIDTH)
  ) dut (
    .ACLK       (clk),
    .ARESETn    (reset_n),
    .test_en_i  (1'b0),

    // Write Address Channel
    .AWID_i     (axi_vif.awid),
    .AWADDR_i   (axi_vif.awaddr),
    .AWLEN_i    (axi_vif.awlen),
    .AWSIZE_i   (axi_vif.awsize),
    .AWBURST_i  (axi_vif.awburst),
    .AWLOCK_i   (axi_vif.awlock),
    .AWCACHE_i  (axi_vif.awcache),
    .AWPROT_i   (axi_vif.awprot),
    .AWREGION_i (axi_vif.awregion),
    .AWUSER_i   (axi_vif.awuser),
    .AWQOS_i    (axi_vif.awqos),
    .AWVALID_i  (axi_vif.awvalid),
    .AWREADY_o  (axi_vif.awready),

    // Write Data Channel
    .WDATA_i    (axi_vif.wdata),
    .WSTRB_i    (axi_vif.wstrb),
    .WLAST_i    (axi_vif.wlast),
    .WUSER_i    (axi_vif.wuser),
    .WVALID_i   (axi_vif.wvalid),
    .WREADY_o   (axi_vif.wready),

    // Write Response Channel
    .BID_o      (axi_vif.bid),
    .BRESP_o    (axi_vif.bresp),
    .BVALID_o   (axi_vif.bvalid),
    .BUSER_o    (axi_vif.buser),
    .BREADY_i   (axi_vif.bready),

    // Read Address Channel
    .ARID_i     (axi_vif.arid),
    .ARADDR_i   (axi_vif.araddr),
    .ARLEN_i    (axi_vif.arlen),
    .ARSIZE_i   (axi_vif.arsize),
    .ARBURST_i  (axi_vif.arburst),
    .ARLOCK_i   (axi_vif.arlock),
    .ARCACHE_i  (axi_vif.arcache),
    .ARPROT_i   (axi_vif.arprot),
    .ARREGION_i (axi_vif.arregion),
    .ARUSER_i   (axi_vif.aruser),
    .ARQOS_i    (axi_vif.arqos),
    .ARVALID_i  (axi_vif.arvalid),
    .ARREADY_o  (axi_vif.arready),

    // Read Data Channel
    .RID_o      (axi_vif.rid),
    .RDATA_o    (axi_vif.rdata),
    .RRESP_o    (axi_vif.rresp),
    .RLAST_o    (axi_vif.rlast),
    .RUSER_o    (axi_vif.ruser),
    .RVALID_o   (axi_vif.rvalid),
    .RREADY_i   (axi_vif.rready),

    // APB Master Outputs from DUT
    .PENABLE    (apb_vif.penable),
    .PWRITE     (apb_vif.pwrite),
    .PADDR      (apb_vif.paddr),
    .PSEL       (apb_vif.psel),
    .PWDATA     (apb_vif.pwdata),

    // APB Slave Inputs to DUT
    .PRDATA     (apb_vif.prdata),
    .PREADY     (apb_vif.pready),
    .PSLVERR    (apb_vif.pslverr)
  );

  // ---------------------------------------------------------------------------
  // UVM Configuration Database Registration and Test Execution
  // ---------------------------------------------------------------------------
  initial begin
    // Register interfaces globally and in test hierarchy
    uvm_config_db#(virtual axi4_if)::set(null, "*", "axi_vif", axi_vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "apb_vif", apb_vif);

    uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_vif);
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", apb_vif);

    uvm_config_db#(virtual axi4_if)::set(null, "uvm_test_top.axi_agent*", "vif", axi_vif);
    uvm_config_db#(virtual apb_if)::set(null,  "uvm_test_top.apb_agent*", "vif", apb_vif);
    uvm_config_db#(virtual axi4_if)::set(null, "uvm_test_top.env.axi_agent*", "vif", axi_vif);
    uvm_config_db#(virtual apb_if)::set(null,  "uvm_test_top.env.apb_agent*", "vif", apb_vif);

    // Call run_test() without arguments to enable CLI selection via +UVM_TESTNAME
    run_test();
  end

  // ---------------------------------------------------------------------------
  // Waveform Dumps
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, axi2apb_tb_top);
  end

endmodule
