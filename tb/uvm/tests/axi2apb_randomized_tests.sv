// ==============================================================================
// File: axi2apb_randomized_tests.sv
// Description: Randomized UVM test suite for AXI4-to-APB bridge verification.
//              Contains 5 distinct randomized test classes extending axi2apb_base_test:
//                1. axi2apb_random_smoke_test
//                2. axi2apb_random_single_write_test
//                3. axi2apb_random_single_read_test
//                4. axi2apb_random_wait_state_test
//                5. axi2apb_random_simultaneous_rw_test
// ==============================================================================

`ifndef AXI2APB_RANDOMIZED_TESTS_SV
`define AXI2APB_RANDOMIZED_TESTS_SV

// ==============================================================================
// 1. axi2apb_random_smoke_test
// Purpose: Validates reset recovery, checks idle stability across a randomized
//          clock duration, and checks that bridge remains cleanly in IDLE.
// ==============================================================================
class axi2apb_random_smoke_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_smoke_test)

  rand int unsigned idle_cycles;

  constraint idle_cycles_c {
    idle_cycles inside {[20:50]};
  }

  function new(string name = "axi2apb_random_smoke_test", uvm_component parent = null);
    super.new(name, parent);
    idle_cycles = 25;
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Tell scoreboard 0 transactions are expected during idle/smoke testing
    uvm_config_db#(bit)::set(this, "env.scoreboard", "check_expected_transactions", 1'b0);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    int unsigned pre_reset_cycles = 0;
    int unsigned smoke_errors = 0;
    phase.raise_objection(this, "Starting axi2apb_random_smoke_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_smoke_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       RANDOM TEST 1: RANDOMIZED RESET AND IDLE STABILITY        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Check reset assertion
    while (axi_vif != null && axi_vif.ARESETn === 1'b0 && pre_reset_cycles < 20) begin
      @(posedge axi_vif.ACLK);
      pre_reset_cycles++;
    end

    // Wait until reset is de-asserted
    if (axi_vif != null) begin
      wait (axi_vif.ARESETn === 1'b1);
      `uvm_info(get_type_name(), $sformatf("Reset de-asserted after %0d pre-reset cycles.", pre_reset_cycles), UVM_LOW)
    end else begin
      #100ns;
    end

    `uvm_info(get_type_name(), $sformatf("Observing stable IDLE behavior for %0d randomized clock cycles...", idle_cycles), UVM_LOW)
    repeat (idle_cycles) begin
      if (axi_vif != null) @(posedge axi_vif.ACLK);
      else #10ns;

      // DUT must not assert spurious APB or AXI handshake signals in IDLE
      if (apb_vif != null && apb_vif.penable === 1'b1) begin
        `uvm_error("RAND_SMOKE_ERR", "Spurious APB PENABLE assertion observed in IDLE!")
        smoke_errors++;
      end
      if (axi_vif != null && (axi_vif.bvalid === 1'b1 || axi_vif.rvalid === 1'b1)) begin
        `uvm_error("RAND_SMOKE_ERR", "Spurious AXI BVALID or RVALID asserted in IDLE!")
        smoke_errors++;
      end
    end

    if (smoke_errors == 0) begin
      `uvm_info(get_type_name(), $sformatf("Successfully verified %0d idle cycles with zero spurious requests.", idle_cycles), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       RANDOM TEST 1: RANDOMIZED RESET SMOKE TEST PASSED         ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("Random smoke test FAILED: %0d spurious assertions observed during IDLE.", smoke_errors))
    end

    phase.drop_objection(this, "Ending axi2apb_random_smoke_test");
  endtask : run_phase
endclass : axi2apb_random_smoke_test


// ==============================================================================
// 2. axi2apb_random_single_write_test
// Purpose: Single write with randomized legal address, write data, ID, and USER.
// ==============================================================================
class axi2apb_random_single_write_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_single_write_test)

  int unsigned num_iterations = 100;

  function new(string name = "axi2apb_random_single_write_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("NUM_TRANS=%d", num_iterations));
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting axi2apb_random_single_write_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       RANDOM TEST 2: RANDOMIZED AXI WRITE TEST                  ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured to run %0d randomized write transfers (override with +NUM_TRANS=<n>).", num_iterations), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    for (int i = 0; i < num_iterations; i++) begin
      apb_slave_single_response_seq apb_rsp_seq;
      axi_single_write_seq          axi_wr_seq;

      fork
        // Reactive APB slave (immediate completion)
        begin
          apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rsp_seq");
          apb_rsp_seq.wait_cycles  = 0;
          apb_rsp_seq.inject_error = 1'b0;
          apb_rsp_seq.start(apb_agent.sequencer);
        end

        // AXI Master driving randomized legal write
        begin
          axi_wr_seq = axi_single_write_seq::type_id::create("rand_wr_seq");
          if (!axi_wr_seq.randomize() with {
            target_addr[1:0]   == 2'b00;
            target_addr[31:16] == 16'h0000;
            bready_delay       == 0;
          }) begin
            `uvm_fatal(get_type_name(), $sformatf("Randomization failed for rand_wr_seq on iteration #%0d", i))
          end

          `uvm_info(get_type_name(), $sformatf("Iteration #%0d/%0d: WRITE addr=0x%08h data=0x%08h id=0x%04h user=0x%03h",
                                              i+1, num_iterations, axi_wr_seq.target_addr, axi_wr_seq.write_data, axi_wr_seq.trans_id, axi_wr_seq.user_val), UVM_MEDIUM)

          axi_wr_seq.start(axi_agent.sequencer);
        end
      join
    end

    #50ns;

    if (env.scoreboard.matches != num_iterations || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_iterations, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("Successfully verified %0d randomized write transfers with 0 errors.", num_iterations), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       RANDOM TEST 2: RANDOMIZED WRITE TEST PASSED               ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_single_write_test");
  endtask : run_phase
endclass : axi2apb_random_single_write_test


// ==============================================================================
// 3. axi2apb_random_single_read_test
// Purpose: Single read with randomized legal address, transaction ID, and USER.
// ==============================================================================
class axi2apb_random_single_read_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_single_read_test)

  int unsigned num_iterations = 100;

  function new(string name = "axi2apb_random_single_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("NUM_TRANS=%d", num_iterations));
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting axi2apb_random_single_read_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       RANDOM TEST 3: RANDOMIZED AXI READ TEST                   ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured to run %0d randomized read transfers (override with +NUM_TRANS=<n>).", num_iterations), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    for (int i = 0; i < num_iterations; i++) begin
      apb_slave_single_response_seq apb_rsp_seq;
      axi_single_read_seq           axi_rd_seq;
      bit [31:0]                    rand_rdata;

      // Pre-randomize expected read data from memory
      if (!std::randomize(rand_rdata)) begin
        `uvm_fatal(get_type_name(), $sformatf("Randomization failed for rand_rdata on iteration #%0d", i))
      end

      fork
        // Reactive APB slave returns the randomized read data
        begin
          apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rsp_seq");
          apb_rsp_seq.wait_cycles       = 0;
          apb_rsp_seq.inject_error      = 1'b0;
          apb_rsp_seq.default_read_data = rand_rdata;
          apb_rsp_seq.start(apb_agent.sequencer);
        end

        // AXI Master driving randomized legal read via sequence on sequencer
        begin
          axi_rd_seq = axi_single_read_seq::type_id::create("rand_rd_seq");
          if (!axi_rd_seq.randomize() with {
            target_addr[1:0]   == 2'b00;
            target_addr[31:16] == 16'h0000;
            rready_delay       == 0;
          }) begin
            `uvm_fatal(get_type_name(), $sformatf("Randomization failed for rand_rd_seq on iteration #%0d", i))
          end

          `uvm_info(get_type_name(), $sformatf("Iteration #%0d/%0d: READ addr=0x%08h id=0x%04h user=0x%03h (Expecting rdata=0x%08h)",
                                              i+1, num_iterations, axi_rd_seq.target_addr, axi_rd_seq.trans_id, axi_rd_seq.user_val, rand_rdata), UVM_MEDIUM)

          axi_rd_seq.start(axi_agent.sequencer);
        end
      join
    end

    #50ns;

    if (env.scoreboard.matches != num_iterations || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_iterations, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("Successfully verified %0d randomized read transfers with 0 errors.", num_iterations), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       RANDOM TEST 3: RANDOMIZED READ TEST PASSED                ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_single_read_test");
  endtask : run_phase
endclass : axi2apb_random_single_read_test


// ==============================================================================
// 4. axi2apb_random_wait_state_test
// Purpose: Explicitly exercises NONZERO randomized APB wait states for both
//          write and read operations (stalling PREADY between 1 and 4 cycles).
// ==============================================================================
class axi2apb_random_wait_state_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_wait_state_test)

  rand int unsigned write_wait_states;
  rand int unsigned read_wait_states;

  // Enforce strictly NONZERO wait states
  constraint wait_states_c {
    write_wait_states inside {[1:4]};
    read_wait_states  inside {[1:4]};
  }

  function new(string name = "axi2apb_random_wait_state_test", uvm_component parent = null);
    super.new(name, parent);
    write_wait_states = 2;
    read_wait_states  = 3;
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_single_response_seq apb_rsp_seq;
    bit [31:0]                    rand_rdata;

    phase.raise_objection(this, "Starting axi2apb_random_wait_state_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_wait_state_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "       RANDOM TEST 4: RANDOM NONZERO APB WAIT STATES TEST        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Selected wait states: Write wait=%0d cycles, Read wait=%0d cycles",
                                         write_wait_states, read_wait_states), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // --- Phase 1: Write with randomized nonzero wait states ---
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_wr_wait");
        apb_rsp_seq.wait_cycles  = write_wait_states;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_single_write_seq axi_wr_seq;
        axi_wr_seq = axi_single_write_seq::type_id::create("rand_wr_wait_seq");
        if (!axi_wr_seq.randomize() with {
          target_addr[1:0]   == 2'b00;
          target_addr[31:16] == 16'h0000;
          bready_delay       == 0;
        }) begin
          `uvm_fatal(get_type_name(), "Randomization failed for rand_wr_wait_seq")
        end
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    #30ns;

    // --- Phase 2: Read with randomized nonzero wait states ---
    if (!std::randomize(rand_rdata)) begin
      `uvm_fatal(get_type_name(), "Randomization failed for rand_rdata")
    end
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rd_wait");
        apb_rsp_seq.wait_cycles       = read_wait_states;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = rand_rdata;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_single_read_seq axi_rd_seq;
        axi_rd_seq = axi_single_read_seq::type_id::create("rand_rd_wait_seq");
        if (!axi_rd_seq.randomize() with {
          target_addr[1:0]   == 2'b00;
          target_addr[31:16] == 16'h0000;
          rready_delay       == 0;
        }) begin
          `uvm_fatal(get_type_name(), "Randomization failed for rand_rd_wait_seq")
        end
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

    #50ns;

    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected 2), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Both randomized wait-state write and read verified successfully.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "       RANDOM TEST 4: RANDOM WAIT STATES TEST PASSED             ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_wait_state_test");
  endtask : run_phase
endclass : axi2apb_random_wait_state_test


// ==============================================================================
// 5. axi2apb_random_simultaneous_rw_test
// Purpose: Asserts randomized Read and Write requests concurrently at pin-level from IDLE.
//          Verifies DUT's actual read-priority arbitration (ARVALID > AWVALID).
// ==============================================================================
class axi2apb_random_simultaneous_rw_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_simultaneous_rw_test)

  function new(string name = "axi2apb_random_simultaneous_rw_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    bit [31:0]             rand_rd_addr;
    bit [31:0]             rand_wr_addr;
    bit [31:0]             rand_wr_data;
    bit [31:0]             rand_rd_exp;
    bit [15:0]             rand_rd_id, rand_wr_id;
    bit [9:0]              rand_rd_user, rand_wr_user;

    phase.raise_objection(this, "Starting axi2apb_random_simultaneous_rw_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "   RANDOM TEST 5: RANDOMIZED SIMULTANEOUS READ/WRITE PRIORITY    ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Generate random legal addresses, data, ID, and USER
    if (!std::randomize(rand_rd_addr, rand_wr_addr, rand_wr_data, rand_rd_exp, rand_rd_id, rand_wr_id, rand_rd_user, rand_wr_user) with {
      rand_rd_addr[1:0]   == 2'b00;
      rand_rd_addr[31:16] == 16'h0000;
      rand_wr_addr[1:0]   == 2'b00;
      rand_wr_addr[31:16] == 16'h0000;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for simultaneous RW parameters")
    end

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Thread 0: APB slave reactive thread (handles 2 sequential requests: read priority first, then write)
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_simult_rsp");
        apb_rsp_seq.num_trans         = 2;
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = rand_rd_exp;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      // Thread 1: Pin-level simultaneous assertion of both AR and AW channels
      begin
        @(axi_vif.master_cb);
        // Assert Read Address Channel
        axi_vif.master_cb.arid    <= rand_rd_id;
        axi_vif.master_cb.araddr  <= rand_rd_addr;
        axi_vif.master_cb.arlen   <= 8'd0;
        axi_vif.master_cb.arsize  <= 3'd2;
        axi_vif.master_cb.arburst <= 2'b01;
        axi_vif.master_cb.aruser  <= rand_rd_user;
        axi_vif.master_cb.arvalid <= 1'b1;

        // Assert Write Address & Data Channels at the EXACT same clock edge
        axi_vif.master_cb.awid    <= rand_wr_id;
        axi_vif.master_cb.awaddr  <= rand_wr_addr;
        axi_vif.master_cb.awlen   <= 8'd0;
        axi_vif.master_cb.awsize  <= 3'd2;
        axi_vif.master_cb.awburst <= 2'b01;
        axi_vif.master_cb.awuser  <= rand_wr_user;
        axi_vif.master_cb.awvalid <= 1'b1;

        axi_vif.master_cb.wdata   <= rand_wr_data;
        axi_vif.master_cb.wstrb   <= 4'hF;
        axi_vif.master_cb.wlast   <= 1'b1;
        axi_vif.master_cb.wuser   <= rand_wr_user;
        axi_vif.master_cb.wvalid  <= 1'b1;

        axi_vif.master_cb.rready  <= 1'b1;
        axi_vif.master_cb.bready  <= 1'b1;

        // Complete handshakes across all 5 channels concurrently
        fork
          // AR handshake: deassert arvalid immediately when arready is sampled
          begin
            do begin
              @(axi_vif.master_cb);
            end while (axi_vif.master_cb.arready !== 1'b1);
            axi_vif.master_cb.arvalid <= 1'b0;
          end

          // AW handshake: deassert awvalid immediately when awready is sampled
          begin
            do begin
              @(axi_vif.master_cb);
            end while (axi_vif.master_cb.awready !== 1'b1);
            axi_vif.master_cb.awvalid <= 1'b0;
          end

          // W handshake: deassert wvalid immediately when wready is sampled
          begin
            do begin
              @(axi_vif.master_cb);
            end while (axi_vif.master_cb.wready !== 1'b1);
            axi_vif.master_cb.wvalid <= 1'b0;
          end

          // R handshake: deassert rready when read data response completes
          begin
            do begin
              @(axi_vif.master_cb);
            end while (axi_vif.master_cb.rvalid !== 1'b1);
            axi_vif.master_cb.rready <= 1'b0;
          end

          // B handshake: deassert bready when write response completes
          begin
            do begin
              @(axi_vif.master_cb);
            end while (axi_vif.master_cb.bvalid !== 1'b1);
            axi_vif.master_cb.bready <= 1'b0;
          end
        join
      end
    join

    #80ns;

    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Priority test failed: expected matches=2 errors=0, got matches=%0d errors=%0d",
                  env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Simultaneous read/write arbitration successfully verified with 0 errors.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "   RANDOM TEST 5: SIMULTANEOUS READ/WRITE PRIORITY TEST PASSED   ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_simultaneous_rw_test");
  endtask : run_phase
endclass : axi2apb_random_simultaneous_rw_test


// ==============================================================================
// 7. axi2apb_random_rready_delay_test
// Purpose: Randomized Read with randomized RREADY backpressure delay [1:10],
//          randomized address, ID, USER, and returned read data.
// ==============================================================================
class axi2apb_random_rready_delay_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_rready_delay_test)

  rand bit [31:0]    rand_addr;
  rand bit [15:0]    rand_id;
  rand bit [9:0]     rand_user;
  rand bit [31:0]    rand_read_data;
  rand int unsigned  rand_rready_delay;

  int unsigned       num_iterations = 100;

  constraint rready_test_c {
    rand_addr[1:0]   == 2'b00;
    rand_addr[31:16] == 16'h0000;
    rand_rready_delay inside {[1:10]};
  }

  function new(string name = "axi2apb_random_rready_delay_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("NUM_TRANS=%d", num_iterations));
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting axi2apb_random_rready_delay_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 7: RANDOMIZED AXI READ WITH RREADY DELAY        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured to run %0d randomized iterations (override with +NUM_TRANS=<n>).", num_iterations), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    for (int i = 0; i < num_iterations; i++) begin
      axi_single_read_seq    axi_rd_seq;
      apb_slave_reactive_seq apb_rsp_seq;

      if (!this.randomize()) begin
        `uvm_fatal(get_type_name(), $sformatf("Randomization failed for iteration #%0d", i))
      end

      `uvm_info(get_type_name(), $sformatf("Iteration #%0d/%0d: Addr=0x%08h, ID=0x%04h, USER=0x%03h, RREADY Delay=%0d cycles",
                                          i+1, num_iterations, rand_addr, rand_id, rand_user, rand_rready_delay), UVM_MEDIUM)

      fork
        begin
          apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_rsp_seq");
          apb_rsp_seq.num_trans         = 1;
          apb_rsp_seq.wait_cycles       = 0;
          apb_rsp_seq.inject_error      = 1'b0;
          apb_rsp_seq.default_read_data = rand_read_data;
          apb_rsp_seq.start(apb_agent.sequencer);
        end

        begin
          axi_rd_seq = axi_single_read_seq::type_id::create("rand_rd_seq");
          axi_rd_seq.target_addr  = rand_addr;
          axi_rd_seq.trans_id     = rand_id;
          axi_rd_seq.user_val     = rand_user;
          axi_rd_seq.rready_delay = rand_rready_delay;
          axi_rd_seq.start(axi_agent.sequencer);
        end
      join
    end

    #50ns;

    if (env.scoreboard.matches != num_iterations || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_iterations, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("Successfully verified %0d randomized iterations of delayed RREADY with 0 errors.", num_iterations), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 7: RANDOMIZED READ RREADY DELAY PASSED          ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_rready_delay_test");
  endtask : run_phase
endclass : axi2apb_random_rready_delay_test


// ==============================================================================
// 8. axi2apb_random_bready_delay_test
// Purpose: Randomized Write with randomized BREADY backpressure delay [1:10],
//          randomized address, data, ID, and USER.
// ==============================================================================
class axi2apb_random_bready_delay_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_bready_delay_test)

  rand bit [31:0]    rand_addr;
  rand bit [31:0]    rand_data;
  rand bit [15:0]    rand_id;
  rand bit [9:0]     rand_user;
  rand int unsigned  rand_bready_delay;

  int unsigned       num_iterations = 100;

  constraint bready_test_c {
    rand_addr[1:0]   == 2'b00;
    rand_addr[31:16] == 16'h0000;
    rand_bready_delay inside {[1:10]};
  }

  function new(string name = "axi2apb_random_bready_delay_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'($value$plusargs("NUM_TRANS=%d", num_iterations));
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting axi2apb_random_bready_delay_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 8: RANDOMIZED AXI WRITE WITH BREADY DELAY       ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured to run %0d randomized iterations (override with +NUM_TRANS=<n>).", num_iterations), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    for (int i = 0; i < num_iterations; i++) begin
      axi_single_write_seq   axi_wr_seq;
      apb_slave_reactive_seq apb_rsp_seq;

      if (!this.randomize()) begin
        `uvm_fatal(get_type_name(), $sformatf("Randomization failed for iteration #%0d", i))
      end

      `uvm_info(get_type_name(), $sformatf("Iteration #%0d/%0d: Addr=0x%08h, Data=0x%08h, ID=0x%04h, USER=0x%03h, BREADY Delay=%0d cycles",
                                          i+1, num_iterations, rand_addr, rand_data, rand_id, rand_user, rand_bready_delay), UVM_MEDIUM)

      fork
        begin
          apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_rsp_seq");
          apb_rsp_seq.num_trans    = 1;
          apb_rsp_seq.wait_cycles  = 0;
          apb_rsp_seq.inject_error = 1'b0;
          apb_rsp_seq.start(apb_agent.sequencer);
        end

        begin
          axi_wr_seq = axi_single_write_seq::type_id::create("rand_wr_seq");
          axi_wr_seq.target_addr  = rand_addr;
          axi_wr_seq.write_data   = rand_data;
          axi_wr_seq.trans_id     = rand_id;
          axi_wr_seq.user_val     = rand_user;
          axi_wr_seq.bready_delay = rand_bready_delay;
          axi_wr_seq.start(axi_agent.sequencer);
        end
      join
    end

    #50ns;

    if (env.scoreboard.matches != num_iterations || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_iterations, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("Successfully verified %0d randomized iterations of delayed BREADY with 0 errors.", num_iterations), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 8: RANDOMIZED WRITE BREADY DELAY PASSED         ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_bready_delay_test");
  endtask : run_phase
endclass : axi2apb_random_bready_delay_test


// ==============================================================================
// 9. axi2apb_random_b2b_reads_test
// Purpose: Randomized back-to-back reads with randomized count [3:6],
//          randomized addresses, and randomized read responses.
// ==============================================================================
class axi2apb_random_b2b_reads_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_b2b_reads_test)

  rand int unsigned num_reads;
  rand bit [31:0]   read_addrs[];
  rand bit [15:0]   read_ids[];
  rand bit [9:0]    read_users[];
  rand bit [31:0]   exp_data[];

  constraint b2b_reads_c {
    num_reads inside {[3:6]};
    read_addrs.size() == num_reads;
    read_ids.size()   == num_reads;
    read_users.size() == num_reads;
    exp_data.size()   == num_reads;
    foreach (read_addrs[i]) {
      read_addrs[i][1:0]   == 2'b00;
      read_addrs[i][31:16] == 16'h0000;
    }
  }

  function new(string name = "axi2apb_random_b2b_reads_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_read_seq    axi_rd_seq;

    phase.raise_objection(this, "Starting axi2apb_random_b2b_reads_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_b2b_reads_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 9: RANDOMIZED BACK-TO-BACK READS TEST           ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured for %0d randomized back-to-back reads.", num_reads), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Pre-populate APB slave driver memory for distinct address responses
    for (int i = 0; i < num_reads; i++) begin
      env.apb_agent.driver.memory[read_addrs[i]] = exp_data[i];
    end

    fork
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_b2b_rd_rsp");
        apb_rsp_seq.num_trans    = num_reads;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      begin
        for (int i = 0; i < num_reads; i++) begin
          axi_rd_seq = axi_single_read_seq::type_id::create($sformatf("rand_b2b_rd_%0d", i));
          axi_rd_seq.target_addr  = read_addrs[i];
          axi_rd_seq.trans_id     = read_ids[i];
          axi_rd_seq.user_val     = read_users[i];
          axi_rd_seq.rready_delay = 0;
          axi_rd_seq.start(axi_agent.sequencer);
        end
      end
    join

    #60ns;

    if (env.scoreboard.matches != num_reads || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_reads, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d randomized back-to-back reads verified successfully.", num_reads), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 9: RANDOMIZED BACK-TO-BACK READS PASSED         ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_b2b_reads_test");
  endtask : run_phase
endclass : axi2apb_random_b2b_reads_test


// ==============================================================================
// 10. axi2apb_random_b2b_writes_test
// Purpose: Randomized back-to-back writes with randomized count [3:6],
//          randomized addresses, and randomized data.
// ==============================================================================
class axi2apb_random_b2b_writes_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_b2b_writes_test)

  rand int unsigned num_writes;
  rand bit [31:0]   write_addrs[];
  rand bit [31:0]   write_data[];
  rand bit [15:0]   write_ids[];
  rand bit [9:0]    write_users[];

  constraint b2b_writes_c {
    num_writes inside {[3:6]};
    write_addrs.size() == num_writes;
    write_data.size()  == num_writes;
    write_ids.size()   == num_writes;
    write_users.size() == num_writes;
    foreach (write_addrs[i]) {
      write_addrs[i][1:0]   == 2'b00;
      write_addrs[i][31:16] == 16'h0000;
    }
  }

  function new(string name = "axi2apb_random_b2b_writes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;

    phase.raise_objection(this, "Starting axi2apb_random_b2b_writes_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_b2b_writes_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 10: RANDOMIZED BACK-TO-BACK WRITES TEST         ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured for %0d randomized back-to-back writes.", num_writes), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_b2b_wr_rsp");
        apb_rsp_seq.num_trans    = num_writes;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      begin
        for (int i = 0; i < num_writes; i++) begin
          axi_wr_seq = axi_single_write_seq::type_id::create($sformatf("rand_b2b_wr_%0d", i));
          axi_wr_seq.target_addr  = write_addrs[i];
          axi_wr_seq.write_data   = write_data[i];
          axi_wr_seq.trans_id     = write_ids[i];
          axi_wr_seq.user_val     = write_users[i];
          axi_wr_seq.bready_delay = 0;
          axi_wr_seq.start(axi_agent.sequencer);
        end
      end
    join

    #60ns;

    if (env.scoreboard.matches != num_writes || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_writes, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d randomized back-to-back writes verified successfully.", num_writes), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 10: RANDOMIZED BACK-TO-BACK WRITES PASSED       ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_b2b_writes_test");
  endtask : run_phase
endclass : axi2apb_random_b2b_writes_test


// ==============================================================================
// 11. axi2apb_random_mixed_traffic_test
// Purpose: Randomized alternating Write/Read traffic with randomized addresses
//          and data values.
// ==============================================================================
class axi2apb_random_mixed_traffic_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_mixed_traffic_test)

  rand int unsigned num_pairs;
  rand bit [31:0]   pair_addrs[];
  rand bit [31:0]   pair_data[];
  rand bit [15:0]   wr_ids[];
  rand bit [15:0]   rd_ids[];

  constraint mixed_pairs_c {
    num_pairs inside {[2:4]};
    pair_addrs.size() == num_pairs;
    pair_data.size()  == num_pairs;
    wr_ids.size()     == num_pairs;
    rd_ids.size()     == num_pairs;
    foreach (pair_addrs[i]) {
      pair_addrs[i][1:0]   == 2'b00;
      pair_addrs[i][31:16] == 16'h0000;
    }
  }

  function new(string name = "axi2apb_random_mixed_traffic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;
    axi_single_read_seq    axi_rd_seq;
    int unsigned total_trans;

    phase.raise_objection(this, "Starting axi2apb_random_mixed_traffic_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_mixed_traffic_test")
    end

    total_trans = num_pairs * 2;

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 11: RANDOMIZED MIXED READ/WRITE TRAFFIC         ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured for %0d pairs (%0d total transfers).", num_pairs, total_trans), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_mixed_rsp");
        apb_rsp_seq.num_trans    = total_trans;
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b0;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      begin
        for (int i = 0; i < num_pairs; i++) begin
          axi_wr_seq = axi_single_write_seq::type_id::create($sformatf("rand_mixed_wr_%0d", i));
          axi_wr_seq.target_addr  = pair_addrs[i];
          axi_wr_seq.write_data   = pair_data[i];
          axi_wr_seq.trans_id     = wr_ids[i];
          axi_wr_seq.user_val     = 10'h030 + i;
          axi_wr_seq.bready_delay = 0;
          axi_wr_seq.start(axi_agent.sequencer);

          #10ns;

          axi_rd_seq = axi_single_read_seq::type_id::create($sformatf("rand_mixed_rd_%0d", i));
          axi_rd_seq.target_addr  = pair_addrs[i];
          axi_rd_seq.trans_id     = rd_ids[i];
          axi_rd_seq.user_val     = 10'h040 + i;
          axi_rd_seq.rready_delay = 0;
          axi_rd_seq.start(axi_agent.sequencer);

          #10ns;
        end
      end
    join

    #60ns;

    if (env.scoreboard.matches != total_trans || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, total_trans, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d randomized mixed transfers verified successfully.", total_trans), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 11: RANDOMIZED MIXED TRAFFIC PASSED             ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_mixed_traffic_test");
  endtask : run_phase
endclass : axi2apb_random_mixed_traffic_test


// ==============================================================================
// 12. axi2apb_random_diff_ids_users_test
// Purpose: Randomized transfers across fully randomized ID (16-bit) and USER (10-bit)
//          sideband patterns.
// ==============================================================================
class axi2apb_random_diff_ids_users_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_diff_ids_users_test)

  rand int unsigned num_trans;
  rand bit [31:0]   trans_addrs[];
  rand bit [31:0]   trans_data[];
  rand bit [15:0]   trans_ids[];
  rand bit [9:0]    trans_users[];
  rand bit          trans_is_write[];

  constraint diff_ids_c {
    num_trans inside {[4:6]};
    trans_addrs.size()    == num_trans;
    trans_data.size()     == num_trans;
    trans_ids.size()      == num_trans;
    trans_users.size()    == num_trans;
    trans_is_write.size() == num_trans;
    foreach (trans_addrs[i]) {
      trans_addrs[i][1:0]   == 2'b00;
      trans_addrs[i][31:16] == 16'h0000;
    }
  }

  function new(string name = "axi2apb_random_diff_ids_users_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_reactive_seq apb_rsp_seq;
    axi_single_write_seq   axi_wr_seq;
    axi_single_read_seq    axi_rd_seq;

    phase.raise_objection(this, "Starting axi2apb_random_diff_ids_users_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_diff_ids_users_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 12: RANDOMIZED DIVERSE IDs AND USER SIDEBANDS   ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured for %0d randomized ID/USER transfers.", num_trans), UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Pre-populate APB memory for reads
    for (int i = 0; i < num_trans; i++) begin
      env.apb_agent.driver.memory[trans_addrs[i]] = trans_data[i];
    end

    fork
      begin
        apb_rsp_seq = apb_slave_reactive_seq::type_id::create("apb_id_user_rsp");
        apb_rsp_seq.num_trans         = num_trans;
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b0;
        apb_rsp_seq.default_read_data = 32'hFEED_0001;
        apb_rsp_seq.start(apb_agent.sequencer);
      end

      begin
        for (int i = 0; i < num_trans; i++) begin
          if (trans_is_write[i]) begin
            axi_wr_seq = axi_single_write_seq::type_id::create($sformatf("rand_id_wr_%0d", i));
            axi_wr_seq.target_addr  = trans_addrs[i];
            axi_wr_seq.write_data   = trans_data[i];
            axi_wr_seq.trans_id     = trans_ids[i];
            axi_wr_seq.user_val     = trans_users[i];
            axi_wr_seq.bready_delay = 0;
            axi_wr_seq.start(axi_agent.sequencer);
          end else begin
            axi_rd_seq = axi_single_read_seq::type_id::create($sformatf("rand_id_rd_%0d", i));
            axi_rd_seq.target_addr  = trans_addrs[i];
            axi_rd_seq.trans_id     = trans_ids[i];
            axi_rd_seq.user_val     = trans_users[i];
            axi_rd_seq.rready_delay = 0;
            axi_rd_seq.start(axi_agent.sequencer);
          end
          #15ns;
        end
      end
    join

    #60ns;

    if (env.scoreboard.matches != num_trans || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected %0d), errors=%0d",
                                            env.scoreboard.matches, num_trans, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), $sformatf("All %0d randomized ID/USER transfers verified successfully.", num_trans), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 12: RANDOMIZED DIVERSE IDs AND USER PASSED      ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_diff_ids_users_test");
  endtask : run_phase
endclass : axi2apb_random_diff_ids_users_test


// ==============================================================================
// 13. axi2apb_random_pslverr_test
// Purpose: Randomized PSLVERR injection on randomized Write and Read transfers.
// ==============================================================================
class axi2apb_random_pslverr_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_pslverr_test)

  rand bit [31:0] wr_addr;
  rand bit [31:0] wr_data;
  rand bit [15:0] wr_id;
  rand bit [31:0] rd_addr;
  rand bit [15:0] rd_id;
  rand bit [31:0] rd_exp_data;

  constraint pslverr_rand_c {
    wr_addr[1:0]   == 2'b00;
    wr_addr[31:16] == 16'h0000;
    rd_addr[1:0]   == 2'b00;
    rd_addr[31:16] == 16'h0000;
    wr_addr        != rd_addr;
  }

  function new(string name = "axi2apb_random_pslverr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    apb_slave_single_response_seq apb_rsp_seq;
    axi_single_write_seq          axi_wr_seq;
    axi_single_read_seq           axi_rd_seq;

    phase.raise_objection(this, "Starting axi2apb_random_pslverr_test");

    if (!this.randomize()) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi2apb_random_pslverr_test")
    end

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     RANDOM TEST 13: RANDOMIZED APB PSLVERR STIMULUS TEST        ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Wait for reset release explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    // Phase 1: Write with APB PSLVERR injection
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_wr_err");
        apb_rsp_seq.wait_cycles  = 0;
        apb_rsp_seq.inject_error = 1'b1;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_wr_seq = axi_single_write_seq::type_id::create("rand_wr_err");
        axi_wr_seq.target_addr  = wr_addr;
        axi_wr_seq.write_data   = wr_data;
        axi_wr_seq.trans_id     = wr_id;
        axi_wr_seq.user_val     = 10'h0E1;
        axi_wr_seq.bready_delay = 0;
        axi_wr_seq.start(axi_agent.sequencer);
      end
    join

    #40ns;

    // Phase 2: Read with APB PSLVERR injection
    fork
      begin
        apb_rsp_seq = apb_slave_single_response_seq::type_id::create("apb_rd_err");
        apb_rsp_seq.wait_cycles       = 0;
        apb_rsp_seq.inject_error      = 1'b1;
        apb_rsp_seq.default_read_data = rd_exp_data;
        apb_rsp_seq.start(apb_agent.sequencer);
      end
      begin
        axi_rd_seq = axi_single_read_seq::type_id::create("rand_rd_err");
        axi_rd_seq.target_addr  = rd_addr;
        axi_rd_seq.trans_id     = rd_id;
        axi_rd_seq.user_val     = 10'h0E2;
        axi_rd_seq.rready_delay = 0;
        axi_rd_seq.start(axi_agent.sequencer);
      end
    join

    #60ns;

    if (env.scoreboard.matches != 2 || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(), $sformatf("Scoreboard check failed: matches=%0d (expected 2), errors=%0d",
                                            env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(), "Randomized PSLVERR transfers verified successfully without deadlock.", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     RANDOM TEST 13: RANDOMIZED APB PSLVERR TEST PASSED          ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_random_pslverr_test");
  endtask : run_phase
endclass : axi2apb_random_pslverr_test


// ==============================================================================
// 14. axi2apb_constrained_random_test
// Purpose: Continuous multi-transaction stress & coverage booster test.
//          Runs a configurable stream of randomized AXI read/write transfers
//          with dynamic APB wait-states. Transaction count can be set via
//          CLI plusarg (+NUM_TRANS=<n>) or defaults to 20.
// ==============================================================================
class axi2apb_constrained_random_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_constrained_random_test)

  int unsigned num_transactions = 100;

  function new(string name = "axi2apb_constrained_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Allow overriding via config_db or plusarg: +NUM_TRANS=<number>
    void'(uvm_config_db#(int unsigned)::get(this, "", "num_transactions", num_transactions));
    void'($value$plusargs("NUM_TRANS=%d", num_transactions));
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_constrained_random_seq    axi_rnd_seq;
    apb_slave_random_response_seq apb_rnd_seq;

    phase.raise_objection(this, "Starting axi2apb_constrained_random_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "     AXI4-TO-APB CONSTRAINED-RANDOM MULTI-TRANSFER TEST          ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Configured to execute %0d randomized transactions.", num_transactions), UVM_LOW)

    // Wait for reset de-assertion explicitly
    wait (axi_vif != null && axi_vif.ARESETn === 1'b1);
    #20ns;

    fork
      // Process 1: APB Slave reactive sequence with randomized wait states
      begin : apb_thread
        apb_rnd_seq = apb_slave_random_response_seq::type_id::create("apb_rnd_seq");
        apb_rnd_seq.num_trans = num_transactions;
        apb_rnd_seq.start(apb_agent.sequencer);
      end : apb_thread

      // Process 2: AXI Master constrained-random sequence
      begin : axi_thread
        axi_rnd_seq = axi_constrained_random_seq::type_id::create("axi_rnd_seq");
        axi_rnd_seq.num_trans = num_transactions;
        axi_rnd_seq.start(axi_agent.sequencer);
      end : axi_thread
    join

    // Drain pipelines
    #100ns;

    // Verify scoreboard matches
    `uvm_info(get_type_name(), $sformatf("Scoreboard status: matches=%0d, errors=%0d (Expected matches=%0d)",
                                         env.scoreboard.matches, env.scoreboard.errors, num_transactions), UVM_LOW)

    if (env.scoreboard.matches != num_transactions || env.scoreboard.errors != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Constrained-random test FAILED: expected matches=%0d errors=0, got matches=%0d errors=%0d",
                  num_transactions, env.scoreboard.matches, env.scoreboard.errors))
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("Successfully verified %0d constrained-random transactions with 0 errors.", num_transactions), UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
      `uvm_info(get_type_name(), "     AXI4-TO-APB CONSTRAINED-RANDOM TEST PASSED                  ", UVM_LOW)
      `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    end

    phase.drop_objection(this, "Ending axi2apb_constrained_random_test");
  endtask : run_phase
endclass : axi2apb_constrained_random_test


// ==============================================================================
// 15. axi2apb_random_100_trans_test
// Purpose: Dedicated 100-transfer fully randomized stress and coverage test.
//          Randomizes R/W directions, 32-bit addresses, data, IDs, USER tags,
//          APB wait states (0-4), and BREADY/RREADY backpressure delays.
//          Scoreboard automatically checks all 100 transactions in real time.
// ==============================================================================
class axi2apb_random_100_trans_test extends axi2apb_constrained_random_test;
  `uvm_component_utils(axi2apb_random_100_trans_test)

  function new(string name = "axi2apb_random_100_trans_test", uvm_component parent = null);
    super.new(name, parent);
    num_transactions = 100;
  endfunction : new
endclass : axi2apb_random_100_trans_test

`endif // AXI2APB_RANDOMIZED_TESTS_SV
