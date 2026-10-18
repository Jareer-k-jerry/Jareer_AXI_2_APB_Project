// ==============================================================================
// File: axi2apb_test_sequences.sv
// Description: Test-Specific Scenario Sequences for AXI4-to-APB Verification Suite.
//              Each sequence corresponds 1-to-1 with a dedicated test case:
//                1. axi_smoke_seq          -> axi2apb_smoke_test
//                2. axi_wait_state_seq     -> axi2apb_wait_state_test
//                3. axi_bready_delay_seq   -> axi2apb_bready_delay_test
//                4. axi_rready_delay_seq   -> axi2apb_rready_delay_test
//                5. axi_b2b_writes_seq     -> axi2apb_b2b_writes_test
//                6. axi_b2b_reads_seq      -> axi2apb_b2b_reads_test
//                7. axi_mixed_traffic_seq  -> axi2apb_mixed_traffic_test
//                8. axi_diff_ids_users_seq -> axi2apb_diff_ids_users_test
//                9. axi_pslverr_seq        -> axi2apb_pslverr_test
// ==============================================================================

`ifndef AXI2APB_TEST_SEQUENCES_SV
`define AXI2APB_TEST_SEQUENCES_SV

// -----------------------------------------------------------------------------
// Sequence 1: Smoke / Reset & Idle Stability Sequence
// -----------------------------------------------------------------------------
class axi_smoke_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_smoke_seq)

  function new(string name = "axi_smoke_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    `uvm_info(get_type_name(), "Executing axi_smoke_seq: Clean reset recovery & bus stability check", UVM_LOW)
  endtask : body
endclass : axi_smoke_seq


// -----------------------------------------------------------------------------
// Sequence 2: Directed Wait States Verification Sequence
// -----------------------------------------------------------------------------
class axi_wait_state_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_wait_state_seq)

  bit [31:0] target_addr = 32'h0000_3000;
  bit [31:0] write_data  = 32'hAAAA_5555;
  bit [15:0] wr_id       = 16'h00C1;
  bit [15:0] rd_id       = 16'h00C2;
  bit [9:0]  wr_user     = 10'h0CC;
  bit [9:0]  rd_user     = 10'h0DD;

  function new(string name = "axi_wait_state_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item wr_item, rd_item;

    // Step 1: Write transfer to be held during APB wait states
    wr_item = axi_master_item::type_id::create("wait_wr_item");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      write        == 1'b1;
      addr         == local::target_addr;
      data         == local::write_data;
      id           == local::wr_id;
      user         == local::wr_user;
      bready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_wait_state_seq WRITE")
    end
    finish_item(wr_item);

    #30ns;

    // Step 2: Read transfer to be held during APB wait states
    rd_item = axi_master_item::type_id::create("wait_rd_item");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      write        == 1'b0;
      addr         == local::target_addr;
      id           == local::rd_id;
      user         == local::rd_user;
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_wait_state_seq READ")
    end
    finish_item(rd_item);
  endtask : body
endclass : axi_wait_state_seq


// -----------------------------------------------------------------------------
// Sequence 3: Delayed BREADY (Backpressure) Sequence
// -----------------------------------------------------------------------------
class axi_bready_delay_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_bready_delay_seq)

  bit [31:0]   target_addr  = 32'h0000_2000;
  bit [31:0]   write_data   = 32'hFACE_FEED;
  bit [15:0]   trans_id     = 16'h00A1;
  bit [9:0]    user_val     = 10'h0A1;
  int unsigned bready_delay = 5;

  function new(string name = "axi_bready_delay_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item = axi_master_item::type_id::create("bready_item");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b1;
      addr         == local::target_addr;
      data         == local::write_data;
      id           == local::trans_id;
      user         == local::user_val;
      bready_delay == local::bready_delay;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_bready_delay_seq")
    end
    finish_item(item);
  endtask : body
endclass : axi_bready_delay_seq


// -----------------------------------------------------------------------------
// Sequence 4: Delayed RREADY (Backpressure) Sequence
// -----------------------------------------------------------------------------
class axi_rready_delay_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_rready_delay_seq)

  bit [31:0]   target_addr  = 32'h0000_2000;
  bit [15:0]   trans_id     = 16'h00A2;
  bit [9:0]    user_val     = 10'h0A2;
  int unsigned rready_delay = 5;

  function new(string name = "axi_rready_delay_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item = axi_master_item::type_id::create("rready_item");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b0;
      addr         == local::target_addr;
      id           == local::trans_id;
      user         == local::user_val;
      rready_delay == local::rready_delay;
    }) begin
      `uvm_fatal(get_type_name(), "Randomization failed for axi_rready_delay_seq")
    end
    finish_item(item);
  endtask : body
endclass : axi_rready_delay_seq


// -----------------------------------------------------------------------------
// Sequence 5: Back-to-Back Consecutive AXI Writes Sequence
// -----------------------------------------------------------------------------
class axi_b2b_writes_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_b2b_writes_seq)

  int unsigned num_writes = 4;
  bit [31:0] test_addrs [4] = '{32'h0000_2000, 32'h0000_2004, 32'h0000_2008, 32'h0000_200C};
  bit [31:0] test_data  [4] = '{32'hCAFE_0001, 32'hCAFE_0002, 32'hCAFE_0003, 32'hCAFE_0004};
  bit [15:0] test_ids   [4] = '{16'h0021,      16'h0022,      16'h0023,      16'h0024};
  bit [9:0]  test_users [4] = '{10'h021,       10'h022,       10'h023,       10'h024};

  function new(string name = "axi_b2b_writes_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item;
    for (int i = 0; i < num_writes; i++) begin
      item = axi_master_item::type_id::create($sformatf("b2b_wr_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        write        == 1'b1;
        addr         == local::test_addrs[i];
        data         == local::test_data[i];
        id           == local::test_ids[i];
        user         == local::test_users[i];
        bready_delay == 0;
        wvalid_delay == (i == 1) ? 2 : 0;
      }) begin
        `uvm_fatal(get_type_name(), $sformatf("Randomization failed for b2b write #%0d", i))
      end
      finish_item(item);
    end
  endtask : body
endclass : axi_b2b_writes_seq


// -----------------------------------------------------------------------------
// Sequence 6: Back-to-Back Consecutive AXI Reads Sequence
// -----------------------------------------------------------------------------
class axi_b2b_reads_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_b2b_reads_seq)

  int unsigned num_reads = 4;
  bit [31:0] test_addrs [4] = '{32'h0000_1000, 32'h0000_1004, 32'h0000_1008, 32'h0000_100C};
  bit [15:0] test_ids   [4] = '{16'h0011,      16'h0012,      16'h0013,      16'h0014};
  bit [9:0]  test_users [4] = '{10'h011,       10'h012,       10'h013,       10'h014};

  function new(string name = "axi_b2b_reads_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item;
    for (int i = 0; i < num_reads; i++) begin
      item = axi_master_item::type_id::create($sformatf("b2b_rd_item_%0d", i));
      start_item(item);
      if (!item.randomize() with {
        write        == 1'b0;
        addr         == local::test_addrs[i];
        id           == local::test_ids[i];
        user         == local::test_users[i];
        rready_delay == 0;
      }) begin
        `uvm_fatal(get_type_name(), $sformatf("Randomization failed for b2b read #%0d", i))
      end
      finish_item(item);
    end
  endtask : body
endclass : axi_b2b_reads_seq


// -----------------------------------------------------------------------------
// Sequence 7: Mixed Read/Write Traffic (RAW) Sequence
// -----------------------------------------------------------------------------
class axi_mixed_traffic_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_mixed_traffic_seq)

  bit [31:0] addrs [3]  = '{32'h0000_5000, 32'h0000_5004, 32'h0000_5008};
  bit [31:0] data  [3]  = '{32'hAAAA_1111, 32'hBBBB_2222, 32'hCCCC_3333};
  bit [15:0] wr_ids[3]  = '{16'h00D1,     16'h00D2,     16'h00D3};
  bit [15:0] rd_ids[3]  = '{16'h00E1,     16'h00E2,     16'h00E3};
  bit [9:0]  wr_user[3] = '{10'h0D1,      10'h0D2,      10'h0D3};
  bit [9:0]  rd_user[3] = '{10'h0E1,      10'h0E2,      10'h0E3};

  function new(string name = "axi_mixed_traffic_seq");
    super.new(name);
  endfunction : new


virtual task body();
  axi_master_item wr_item;
  axi_master_item rd_item;

  for (int i = 0; i < 3; i++) begin
    // Step A: Write to Address[i]
    wr_item = axi_master_item::type_id::create(
        $sformatf("mixed_wr_%0d", i));

    start_item(wr_item);

    if (!wr_item.randomize() with {
      write        == 1'b1;
      addr         == local::addrs[i];
      data         == local::data[i];
      id           == local::wr_ids[i];
      user         == local::wr_user[i];
      bready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(),
                 "Randomization failed for mixed write")
    end

    finish_item(wr_item);

    #10ns;

    // Step B: Read-back from same Address[i]
    rd_item = axi_master_item::type_id::create(
        $sformatf("mixed_rd_%0d", i));

    start_item(rd_item);

    if (!rd_item.randomize() with {
      write        == 1'b0;
      addr         == local::addrs[i];
      id           == local::rd_ids[i];
      user         == local::rd_user[i];
      rready_delay == 0;
    }) begin
      `uvm_fatal(get_type_name(),
                 "Randomization failed for mixed read")
    end

    finish_item(rd_item);

    #15ns;
  end
endtask : body
endclass : axi_mixed_traffic_seq


// -----------------------------------------------------------------------------
// Sequence 8: Diverse AXI IDs and USER Sideband Sequence
// -----------------------------------------------------------------------------
class axi_diff_ids_users_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_diff_ids_users_seq)

  function new(string name = "axi_diff_ids_users_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item item;

    // 1. Min boundary Write (ID=0x0000, USER=0x000)
    item = axi_master_item::type_id::create("id_wr_item_1");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b1;
      addr         == 32'h0000_6000;
      data         == 32'hCAFE_0001;
      id           == 16'h0000;
      user         == 10'h000;
      bready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(item);
    #15ns;

    // 2. Max boundary Read (ID=0xFFFF, USER=0x3FF)
    item = axi_master_item::type_id::create("id_rd_item_2");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b0;
      addr         == 32'h0000_6004;
      id           == 16'hFFFF;
      user         == 10'h3FF;
      rready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(item);
    #15ns;

    // 3. Checkerboard Pattern 1 Write (ID=0xA55A, USER=0x2AA)
    item = axi_master_item::type_id::create("id_wr_item_3");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b1;
      addr         == 32'h0000_6008;
      data         == 32'hCAFE_0003;
      id           == 16'hA55A;
      user         == 10'h2AA;
      bready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(item);
    #15ns;

    // 4. Checkerboard Pattern 2 Read (ID=0x5AA5, USER=0x155)
    item = axi_master_item::type_id::create("id_rd_item_4");
    start_item(item);
    if (!item.randomize() with {
      write        == 1'b0;
      addr         == 32'h0000_600C;
      id           == 16'h5AA5;
      user         == 10'h155;
      rready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(item);
    #15ns;
  endtask : body
endclass : axi_diff_ids_users_seq


// -----------------------------------------------------------------------------
// Sequence 9: APB PSLVERR Verification Sequence
// -----------------------------------------------------------------------------
class axi_pslverr_seq extends uvm_sequence #(axi_master_item);
  `uvm_object_utils(axi_pslverr_seq)

  bit [31:0] wr_addr = 32'h0000_7000;
  bit [31:0] wr_data = 32'hBAD0_0001;
  bit [15:0] wr_id   = 16'h00E1;

  bit [31:0] rd_addr = 32'h0000_7004;
  bit [15:0] rd_id   = 16'h00E2;

  function new(string name = "axi_pslverr_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    axi_master_item wr_item, rd_item;

    // Phase 1: Write
    wr_item = axi_master_item::type_id::create("wr_err_item");
    start_item(wr_item);
    if (!wr_item.randomize() with {
      write        == 1'b1;
      addr         == local::wr_addr;
      data         == local::wr_data;
      id           == local::wr_id;
      user         == 10'h0E1;
      bready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(wr_item);

    #40ns;

    // Phase 2: Read
    rd_item = axi_master_item::type_id::create("rd_err_item");
    start_item(rd_item);
    if (!rd_item.randomize() with {
      write        == 1'b0;
      addr         == local::rd_addr;
      id           == local::rd_id;
      user         == 10'h0E2;
      rready_delay == 0;
    }) `uvm_fatal(get_type_name(), "Randomization failed")
    finish_item(rd_item);
  endtask : body
endclass : axi_pslverr_seq

`endif // AXI2APB_TEST_SEQUENCES_SV
