interface axi4_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int ID_WIDTH   = 16,
  parameter int USER_WIDTH = 10
)(
  input logic ACLK,
  input logic ARESETn
);

  // AXI4 write address channel
  logic [ID_WIDTH-1:0]   awid;
  logic [ADDR_WIDTH-1:0] awaddr;
  logic [7:0]            awlen;
  logic [2:0]            awsize;
  logic [1:0]            awburst;
  logic                  awlock;
  logic [3:0]            awcache;
  logic [2:0]            awprot;
  logic [3:0]            awregion;
  logic [USER_WIDTH-1:0] awuser;
  logic [3:0]            awqos;
  logic                  awvalid;
  logic                  awready;

  // AXI4 write data channel
  logic [DATA_WIDTH-1:0]     wdata;
  logic [(DATA_WIDTH/8)-1:0] wstrb;
  logic                      wlast;
  logic [USER_WIDTH-1:0]     wuser;
  logic                      wvalid;
  logic                      wready;

  // AXI4 write response channel
  logic [ID_WIDTH-1:0]   bid;
  logic [1:0]            bresp;
  logic                  bvalid;
  logic [USER_WIDTH-1:0] buser;
  logic                  bready;

  // AXI4 read address channel
  logic [ID_WIDTH-1:0]   arid;
  logic [ADDR_WIDTH-1:0] araddr;
  logic [7:0]            arlen;
  logic [2:0]            arsize;
  logic [1:0]            arburst;
  logic                  arlock;
  logic [3:0]            arcache;
  logic [2:0]            arprot;
  logic [3:0]            arregion;
  logic [USER_WIDTH-1:0] aruser;
  logic [3:0]            arqos;
  logic                  arvalid;
  logic                  arready;

  // AXI4 read data channel
  logic [ID_WIDTH-1:0]   rid;
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0]            rresp;
  logic                  rlast;
  logic [USER_WIDTH-1:0] ruser;
  logic                  rvalid;
  logic                  rready;

  clocking master_cb @(posedge ACLK);
    default input #1step output #1step;

    output awid, awaddr, awlen, awsize, awburst, awlock,
           awcache, awprot, awregion, awuser, awqos, awvalid;
    input  awready;

    output wdata, wstrb, wlast, wuser, wvalid;
    input  wready;

    input  bid, bresp, bvalid, buser;
    output bready;

    output arid, araddr, arlen, arsize, arburst, arlock,
           arcache, arprot, arregion, aruser, arqos, arvalid;
    input  arready;

    input  rid, rdata, rresp, rlast, ruser, rvalid;
    output rready;
  endclocking

  clocking monitor_cb @(posedge ACLK);
    default input #1step;

    input awid, awaddr, awlen, awsize, awburst, awlock,
          awcache, awprot, awregion, awuser, awqos, awvalid, awready;
    input wdata, wstrb, wlast, wuser, wvalid, wready;
    input bid, bresp, bvalid, buser, bready;
    input arid, araddr, arlen, arsize, arburst, arlock,
          arcache, arprot, arregion, aruser, arqos, arvalid, arready;
    input rid, rdata, rresp, rlast, ruser, rvalid, rready;
  endclocking

endinterface
