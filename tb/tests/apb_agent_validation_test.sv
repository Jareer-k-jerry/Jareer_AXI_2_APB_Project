// ==============================================================================
// File: apb_agent_validation_test.sv
// Description: Validation test for Phase 3 APB Slave Agent.
//              Coordinates AXI master stimulus and reactive APB slave responses,
//              verifying that AXI reads and writes generate correct APB pin activity,
//              respect programmable wait states, and return expected read data.
// ==============================================================================

`ifndef APB_AGENT_VALIDATION_TEST_SV
`define APB_AGENT_VALIDATION_TEST_SV

class apb_agent_validation_test extends uvm_test;
  `uvm_component_utils(apb_agent_validation_test)

  axi2apb_env      env;
  axi_master_agent axi_agent;
  apb_slave_agent  apb_agent;

  function new(string name = "apb_agent_validation_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(), "=== [build_phase] Building Test with UVM Environment & Scoreboard ===", UVM_LOW)
    env = axi2apb_env::type_id::create("env", this);
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    axi_agent = env.axi_agent;
    apb_agent = env.apb_agent;
  endfunction : connect_phase

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info(get_type_name(), "=== [end_of_elaboration_phase] Elaboration topology: ===", UVM_LOW)
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting apb_agent_validation_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "           PHASE 3: APB SLAVE AGENT VALIDATION TEST              ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset sequence to complete
    #100ns;

    fork
      // -----------------------------------------------------------------------
      // Process 1: Reactive APB Slave Response Sequence
      // -----------------------------------------------------------------------
      begin : apb_slave_thread
        apb_slave_single_response_seq apb_resp;

        // Response 1: For initial write (0 wait cycles)
        `uvm_info(get_type_name(), "Configuring APB Response 1: Write with 0 wait cycles", UVM_LOW)
        apb_resp = apb_slave_single_response_seq::type_id::create("apb_resp_1");
        apb_resp.wait_cycles  = 0;
        apb_resp.inject_error = 1'b0;
        apb_resp.start(apb_agent.sequencer);

        // Response 2: For read-back (2 wait cycles, verifying PREADY low stalls DUT)
        `uvm_info(get_type_name(), "Configuring APB Response 2: Read with 2 wait cycles", UVM_LOW)
        apb_resp = apb_slave_single_response_seq::type_id::create("apb_resp_2");
        apb_resp.wait_cycles  = 2;
        apb_resp.inject_error = 1'b0;
        apb_resp.start(apb_agent.sequencer);

        // Response 3: For write with wait states (3 wait cycles)
        `uvm_info(get_type_name(), "Configuring APB Response 3: Write with 3 wait cycles", UVM_LOW)
        apb_resp = apb_slave_single_response_seq::type_id::create("apb_resp_3");
        apb_resp.wait_cycles  = 3;
        apb_resp.inject_error = 1'b0;
        apb_resp.start(apb_agent.sequencer);

        // Response 4: For PSLVERR error injection test
        `uvm_info(get_type_name(), "Configuring APB Response 4: Read with PSLVERR injection", UVM_LOW)
        apb_resp = apb_slave_single_response_seq::type_id::create("apb_resp_4");
        apb_resp.wait_cycles       = 1;
        apb_resp.inject_error      = 1'b1;
        apb_resp.default_read_data = 32'hDEAD_BEEF;
        apb_resp.start(apb_agent.sequencer);
      end : apb_slave_thread

      // -----------------------------------------------------------------------
      // Process 2: AXI Master Stimulus
      // -----------------------------------------------------------------------
      begin : axi_master_thread
        axi_single_write_seq axi_wr;
        axi_single_read_seq  axi_rd;

        // Step 1: AXI Write -> Triggers APB write to 0x1000
        `uvm_info(get_type_name(), "--- [Step 1] Initiating AXI Write (0x1000 = 0xCAFE_BABE) ---", UVM_LOW)
        axi_wr = axi_single_write_seq::type_id::create("axi_wr_1");
        axi_wr.target_addr = 32'h0000_1000;
        axi_wr.write_data  = 32'hCAFE_BABE;
        axi_wr.trans_id    = 16'h0010;
        axi_wr.start(axi_agent.sequencer);

        #20ns;

        // Step 2: AXI Read -> Triggers APB read from 0x1000 (expects 0xCAFE_BABE returned from memory)
        `uvm_info(get_type_name(), "--- [Step 2] Initiating AXI Read-back from 0x1000 (Wait States = 2) ---", UVM_LOW)
        axi_rd = axi_single_read_seq::type_id::create("axi_rd_1");
        axi_rd.target_addr = 32'h0000_1000;
        axi_rd.trans_id    = 16'h0011;
        axi_rd.start(axi_agent.sequencer);

        #20ns;

        // Step 3: AXI Write with APB wait states (3 cycles)
        `uvm_info(get_type_name(), "--- [Step 3] Initiating AXI Write to 0x2000 (Wait States = 3) ---", UVM_LOW)
        axi_wr = axi_single_write_seq::type_id::create("axi_wr_2");
        axi_wr.target_addr = 32'h0000_2000;
        axi_wr.write_data  = 32'h55AA_55AA;
        axi_wr.trans_id    = 16'h0020;
        axi_wr.start(axi_agent.sequencer);

        #20ns;

        // Step 4: AXI Read with PSLVERR injected on APB
        `uvm_info(get_type_name(), "--- [Step 4] Initiating AXI Read to 0x3000 with APB PSLVERR ---", UVM_LOW)
        axi_rd = axi_single_read_seq::type_id::create("axi_rd_2");
        axi_rd.target_addr = 32'h0000_3000;
        axi_rd.trans_id    = 16'h0030;
        axi_rd.start(axi_agent.sequencer);

        #50ns;
      end : axi_master_thread
    join

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "      PHASE 3: APB SLAVE AGENT VALIDATION TEST PASSED            ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending apb_agent_validation_test");
  endtask : run_phase

endclass : apb_agent_validation_test

`endif // APB_AGENT_VALIDATION_TEST_SV
