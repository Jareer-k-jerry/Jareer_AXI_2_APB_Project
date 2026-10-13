// ==============================================================================
// File: axi2apb_pkg.sv
// Description: UVM package definition for AXI4-to-APB bridge verification.
//              Includes AXI master agent, APB slave agent, scoreboard, environment,
//              and validation tests.
// ==============================================================================

package axi2apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Phase 2: AXI Master Agent
  `include "axi_master_agent/axi_master_item.sv"
  `include "axi_master_agent/axi_master_sequencer.sv"
  `include "axi_master_agent/axi_master_driver.sv"
  `include "axi_master_agent/axi_master_monitor.sv"
  `include "axi_master_agent/axi_master_agent.sv"
  `include "axi_master_agent/axi_master_seq.sv"

  // Phase 3: APB Slave Agent
  `include "apb_slave_agent/apb_slave_item.sv"
  `include "apb_slave_agent/apb_slave_config.sv"
  `include "apb_slave_agent/apb_slave_sequencer.sv"
  `include "apb_slave_agent/apb_slave_driver.sv"
  `include "apb_slave_agent/apb_slave_monitor.sv"
  `include "apb_slave_agent/apb_slave_agent.sv"
  `include "apb_slave_agent/apb_slave_seq.sv"

  // Phase 4: Scoreboard & Environment
  `include "environment/axi2apb_scoreboard.sv"
  `include "environment/axi2apb_env.sv"

  // Tests — shared base
  `include "tests/axi2apb_base_test.sv"

  // Tests — Phase 5 directed tests
  `include "tests/axi2apb_smoke_test.sv"
  `include "tests/axi2apb_single_write_test.sv"
  `include "tests/axi2apb_single_read_test.sv"
  `include "tests/axi2apb_wait_state_test.sv"
  `include "tests/axi2apb_simultaneous_rw_test.sv"

  // Tests — agent-level validation (legacy)
  `include "tests/axi_master_agent_test.sv"
  `include "tests/apb_agent_validation_test.sv"

endpackage : axi2apb_pkg
