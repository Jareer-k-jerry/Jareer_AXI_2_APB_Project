// ==============================================================================
// File: axi2apb_pkg.sv
// Description: UVM package definition for AXI4-to-APB bridge verification.
//              Organized cleanly under tb/uvm/ hierarchy:
//                - agents/ (AXI Master & APB Slave VIPs)
//                - env/ (Scoreboard, Virtual Sequencer & Environment)
//                - coverage/ (Functional Coverage Subscriber)
//                - sequences/ (Virtual & Scenario Sequences)
//                - tests/ (Directed & Randomized Test Suites)
// ==============================================================================

package axi2apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------------------------------------------------------------------
  // 1. AXI Master Agent (VIP)
  // ---------------------------------------------------------------------------
  `include "uvm/agents/axi_master_agent/axi_master_item.sv"
  `include "uvm/agents/axi_master_agent/axi_master_sequencer.sv"
  `include "uvm/agents/axi_master_agent/axi_master_driver.sv"
  `include "uvm/agents/axi_master_agent/axi_master_monitor.sv"
  `include "uvm/agents/axi_master_agent/axi_master_agent.sv"
  `include "uvm/agents/axi_master_agent/axi_master_seq.sv"

  // ---------------------------------------------------------------------------
  // 2. APB Slave Agent (VIP)
  // ---------------------------------------------------------------------------
  `include "uvm/agents/apb_slave_agent/apb_slave_item.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_config.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_sequencer.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_driver.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_monitor.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_agent.sv"
  `include "uvm/agents/apb_slave_agent/apb_slave_seq.sv"

  // ---------------------------------------------------------------------------
  // 3. Sequences & Virtual Sequencer
  // ---------------------------------------------------------------------------
  `include "uvm/sequences/apb_slave_random_response_seq.sv"
  `include "uvm/sequences/axi2apb_test_sequences.sv"
  `include "uvm/env/axi2apb_virtual_sequencer.sv"
  `include "uvm/sequences/axi2apb_virtual_sequences.sv"

  // ---------------------------------------------------------------------------
  // 4. Scoreboard, Coverage & Environment
  // ---------------------------------------------------------------------------
  `include "uvm/env/axi2apb_scoreboard.sv"
  `include "uvm/coverage/axi2apb_functional_coverage.sv"
  `include "uvm/env/axi2apb_env.sv"

  // ---------------------------------------------------------------------------
  // 5. Test Suite (Base + Directed + Randomized)
  // ---------------------------------------------------------------------------
  `include "uvm/tests/axi2apb_base_test.sv"

  // Phase 5 directed tests
  `include "uvm/tests/axi2apb_smoke_test.sv"
  `include "uvm/tests/axi2apb_single_write_test.sv"
  `include "uvm/tests/axi2apb_single_read_test.sv"
  `include "uvm/tests/axi2apb_wait_state_test.sv"
  `include "uvm/tests/axi2apb_simultaneous_rw_test.sv"
  `include "uvm/tests/axi2apb_rready_delay_test.sv"
  `include "uvm/tests/axi2apb_bready_delay_test.sv"
  `include "uvm/tests/axi2apb_b2b_reads_test.sv"
  `include "uvm/tests/axi2apb_b2b_writes_test.sv"
  `include "uvm/tests/axi2apb_mixed_traffic_test.sv"
  `include "uvm/tests/axi2apb_diff_ids_users_test.sv"
  `include "uvm/tests/axi2apb_pslverr_test.sv"

  // Randomized tests suite
  `include "uvm/tests/axi2apb_randomized_tests.sv"

  // Agent-level validation
  `include "uvm/tests/axi_master_agent_test.sv"
  `include "uvm/tests/apb_agent_validation_test.sv"

endpackage : axi2apb_pkg
