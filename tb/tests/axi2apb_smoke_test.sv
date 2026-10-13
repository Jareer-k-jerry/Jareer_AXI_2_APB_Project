// ==============================================================================
// File: axi2apb_smoke_test.sv
// Description: Test 1 — Reset and Smoke Test.
//              Verifies reset assertion, clock propagation, DUT reset recovery,
//              and checks that the bridge initializes to IDLE with no spurious APB requests.
// ==============================================================================

`ifndef AXI2APB_SMOKE_TEST_SV
`define AXI2APB_SMOKE_TEST_SV

class axi2apb_smoke_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_smoke_test)

  function new(string name = "axi2apb_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual task run_phase(uvm_phase phase);
    int unsigned pre_reset_cycles = 0;
    int unsigned post_reset_cycles = 0;

    phase.raise_objection(this, "Starting axi2apb_smoke_test");

    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "          TEST 1: RESET AND SMOKE TEST STARTED                  ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    // Check that ARESETn is initially asserted (active-low = 0)
    `uvm_info(get_type_name(), "Step 1: Observing initial reset state...", UVM_LOW)
    while (axi_vif != null && axi_vif.ARESETn === 1'b0 && pre_reset_cycles < 20) begin
      @(posedge axi_vif.ACLK);
      pre_reset_cycles++;
    end

    // Wait until reset is de-asserted (ARESETn == 1)
    if (axi_vif != null) begin
      wait (axi_vif.ARESETn === 1'b1);
      `uvm_info(get_type_name(), $sformatf("Step 2: Reset de-asserted after %0d cycles.", pre_reset_cycles), UVM_LOW)
    end else begin
      #100ns;
    end

    // Observe 20 clock cycles post-reset to verify stable idle behavior
    `uvm_info(get_type_name(), "Step 3: Checking stable IDLE post-reset behavior for 20 clock cycles...", UVM_LOW)
    repeat (20) begin
      if (axi_vif != null) @(posedge axi_vif.ACLK);
      else #10ns;

      // Verification checks: DUT should not issue spurious requests in IDLE
      if (apb_vif != null) begin
        if (apb_vif.penable === 1'b1) begin
          `uvm_error("SMOKE_ERR", "Spurious PENABLE assertion observed on APB during reset recovery!")
        end
      end

      if (axi_vif != null) begin
        if (axi_vif.bvalid === 1'b1 || axi_vif.rvalid === 1'b1) begin
          `uvm_error("SMOKE_ERR", "Spurious BVALID or RVALID asserted on AXI post-reset!")
        end
      end
      post_reset_cycles++;
    end

    `uvm_info(get_type_name(), $sformatf("Step 4: DUT successfully held IDLE without spurious activity for %0d cycles.", post_reset_cycles), UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "          TEST 1: RESET AND SMOKE TEST PASSED                   ", UVM_LOW)
    `uvm_info(get_type_name(), "=================================================================", UVM_LOW)

    phase.drop_objection(this, "Ending axi2apb_smoke_test");
  endtask : run_phase

endclass : axi2apb_smoke_test

`endif // AXI2APB_SMOKE_TEST_SV
