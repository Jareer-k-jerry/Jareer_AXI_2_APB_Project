interface apb_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
)(
  input logic PCLK,
  input logic PRESETn
);

  // Driven by AXI2APB DUT (APB master)
  logic                  psel;
  logic                  penable;
  logic                  pwrite;
  logic [ADDR_WIDTH-1:0] paddr;
  logic [DATA_WIDTH-1:0] pwdata;

  // Driven by APB UVM slave agent
  logic [DATA_WIDTH-1:0] prdata;
  logic                  pready;
  logic                  pslverr;

  clocking slave_cb @(posedge PCLK);
    default input #1step output #1step;
    input  psel, penable, pwrite, paddr, pwdata;
    output prdata, pready, pslverr;
  endclocking

  clocking monitor_cb @(posedge PCLK);
    default input #1step;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
  endclocking

endinterface
