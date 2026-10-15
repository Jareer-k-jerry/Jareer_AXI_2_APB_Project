// ==============================================================================
// File: apb_slave_random_response_seq.sv
// Description: Reactive APB slave sequence with randomized wait states.
//              Varies APB response timing across immediate (0 wait) and multi-cycle
//              wait states (1-4 cycles) for a configurable number of transfers.
// ==============================================================================

`ifndef APB_SLAVE_RANDOM_RESPONSE_SEQ_SV
`define APB_SLAVE_RANDOM_RESPONSE_SEQ_SV

class apb_slave_random_response_seq extends uvm_sequence #(apb_slave_item);
  `uvm_object_utils(apb_slave_random_response_seq)

  // Configurable number of transfers to service
  int unsigned num_trans = 20;

  function new(string name = "apb_slave_random_response_seq");
    super.new(name);
  endfunction : new

  virtual task body();
    `uvm_info(get_type_name(), $sformatf("Starting random-response sequence for %0d APB transfers", num_trans), UVM_LOW)

    repeat (num_trans) begin
      apb_slave_item item;
      item = apb_slave_item::type_id::create("apb_rand_resp_item");

      start_item(item);
      if (!item.randomize() with {
        // Vary wait states: 40% immediate (0 wait), 40% short (1-2), 20% medium (3-4)
        wait_cycles dist {0 := 4, [1:2] := 4, [3:4] := 2};
        inject_error == 1'b0;
      }) begin
        `uvm_fatal(get_type_name(), "Randomization failed in apb_slave_random_response_seq")
      end
      finish_item(item);
    end

    `uvm_info(get_type_name(), "Completed all randomized APB response items.", UVM_LOW)
  endtask : body

endclass : apb_slave_random_response_seq

`endif // APB_SLAVE_RANDOM_RESPONSE_SEQ_SV
