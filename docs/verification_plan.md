# 📋 Verification Plan: AXI4-to-APB Bridge

**Project:** Dual-Agent UVM Verification Environment for PULP-Platform `axi2apb`  
**Document Ref:** Milestone 3 Formal Verification Plan  
**DUT:** `axi2apb.sv` (with internal channel FIFO buffers)  
**Methodology:** UVM 1.2 (IEEE 1800.2) + Synopsys VCS  

---

## 1. Scope & Objective

The objective of this verification plan is to validate the functional correctness, protocol compliance, data integrity, and timing robustness of the PULP-Platform AXI4-to-APB bridge. 

The testbench employs a **Dual-Agent UVM Architecture**:
1. **AXI Master Agent**: Emulates an AXI4 Master issuing single-beat 32-bit read and write transactions.
2. **APB Reactive Slave Agent**: Emulates an APB3 peripheral responding to DUT bridge requests with programmable wait-states (`PREADY`) and error indications (`PSLVERR`).
3. **Scoreboard & Predictor**: Compares incoming AXI requests against observed APB transfers and validates response generation on AXI response channels.
4. **Functional Coverage Collector**: Tracks coverage across address spaces, data patterns, transfer types, wait states, and backpressure delays.

---

## 2. DUT Architecture & FSM Overview

The bridge features a 5-state Mealy/Moore Finite State Machine:
- `IDLE`: Waits for incoming read or write requests from the channel input buffers.
- `WAIT_R_PREADY`: Stalls during an active APB read until `PREADY == 1` is returned.
- `DONE_SINGLE_RD`: Asserts `RVALID` and `RLAST` to return read data to the AXI Master.
- `WAIT_W_PREADY`: Stalls during an active APB write until `PREADY == 1` is returned.
- `SEND_B_RESP`: Asserts `BVALID` with captured `BID` and `BUSER` to complete the write handshake.

---

## 3. Detailed Verification Feature Matrix (18 Required Sections)

| Ref # | Feature / Scenario Description | Test Implementation | Scoreboard Check | Coverage Points |
| :---: | :--- | :--- | :--- | :--- |
| **01** | **Reset & Idle Behavior**<br>Asynchronous assert, synchronous release, verify zero spurious bus activity. | `axi2apb_smoke_test`<br>`axi2apb_random_smoke_test` | Confirms 0 transfers initiated during reset; bridge settles in `IDLE`. | Reset state coverage, idle cycle stability. |
| **02** | **AXI Write Address Handshake**<br>AW channel handshake (`AWVALID` & `AWREADY`). | `axi2apb_single_write_test`<br>`axi2apb_random_single_write_test` | Checks `AWADDR`, `AWID`, and `AWUSER` latched into FIFO buffer. | AW handshake cross with address boundaries. |
| **03** | **AXI Write Data Handshake**<br>Bridge requires both `AWVALID` and `WVALID` before starting APB write. | `axi2apb_single_write_test`<br>`axi2apb_b2b_writes_test` | Verifies APB write does not initiate until `WVALID` is available. | WDATA patterns, strobe checks. |
| **04** | **Write Conversion to APB**<br>Translation of `AWADDR` → `PADDR`, `WDATA` → `PWDATA`, `PWRITE=1`, `PSEL=1`. | `axi2apb_single_write_test`<br>`axi2apb_random_100_trans_test` | Compares `AXI.addr == APB.paddr` and `AXI.wdata == APB.pwdata`. | APB write direction and address bins. |
| **05** | **APB Wait States for Writes**<br>DUT stalls in `WAIT_W_PREADY` while `PREADY` is low (1 to 4 cycles). | `axi2apb_wait_state_test`<br>`axi2apb_random_wait_state_test` | Verifies `PWDATA` and `PADDR` remain stable during stall; no data loss. | Wait-state bins: `[0]`, `[1:2]`, `[3:4]`. |
| **06** | **AXI Write Response & BREADY Delays**<br>Backpressure on B channel; `BVALID` held until `BREADY` asserted. | `axi2apb_bready_delay_test`<br>`axi2apb_random_bready_delay_test` | Scoreboard checks `BRESP == OKAY` and ID propagation (`BID == AWID`). | `BREADY` delay bins `[1:10]`. |
| **07** | **AXI Read Address Handshake**<br>AR channel handshake (`ARVALID` & `ARREADY`). | `axi2apb_single_read_test`<br>`axi2apb_random_single_read_test` | Checks `ARADDR`, `ARID`, `ARUSER` latched cleanly into AR buffer. | AR handshake cross with address boundaries. |
| **08** | **Read Conversion to APB**<br>Translation of `ARADDR` → `PADDR`, `PWRITE=0`, `PSEL=1`, `PENABLE=1`. | `axi2apb_single_read_test`<br>`axi2apb_random_single_read_test` | Compares `AXI.addr == APB.paddr` and `APB.pwrite == 0`. | APB read direction and address bins. |
| **09** | **APB Wait States for Reads**<br>DUT stalls in `WAIT_R_PREADY` while `PREADY` is low. | `axi2apb_wait_state_test`<br>`axi2apb_random_wait_state_test` | Confirms read request holds APB control signals stable; captures data on rising edge. | Read wait-state bins: `[1:4]`. |
| **10** | **PRDATA Capture & RDATA Delivery**<br>Sampled `PRDATA` accurately propagated to AXI `RDATA`. | `axi2apb_single_read_test`<br>`axi2apb_mixed_traffic_test` | Compares `APB.prdata == AXI.rdata`. | Data patterns (walking 1s, alternating, random). |
| **11** | **RVALID/RREADY Backpressure & RLAST**<br>`RVALID` and `RLAST` asserted; held until `RREADY` handshake. | `axi2apb_rready_delay_test`<br>`axi2apb_random_rready_delay_test` | Checks `RLAST == 1` for single-beat; ensures no premature deassertion. | `RREADY` delay bins `[1:10]`. |
| **12** | **ID and USER Sideband Propagation**<br>Bidirectional propagation: `BID=AWID`, `BUSER=AWUSER`, `RID=ARID`, `RUSER=ARUSER`. | `axi2apb_diff_ids_users_test`<br>`axi2apb_random_diff_ids_users_test` | Exact bit-for-bit check on response ID and USER sidebands. | ID bins: `[0]`, `[1:15]`, `[16:127]`, `[128:255]`. USER bins. |
| **13** | **Simultaneous Read & Write Priority**<br>Both `ARVALID` and `AWVALID` asserted concurrently from `IDLE`. | `axi2apb_simultaneous_rw_test`<br>`axi2apb_random_simultaneous_rw_test` | Confirms **READ is serviced first** by bridge, followed immediately by WRITE. | Cross: Simultaneous request priority bin. |
| **14** | **Back-to-Back Transactions**<br>Pipelined streams of reads or writes with 0 inter-transaction bubbles. | `axi2apb_b2b_reads_test`<br>`axi2apb_b2b_writes_test` | Verifies internal FIFO buffer depths (4 beats) operate without overrun. | Back-to-back burst stress coverage. |
| **15** | **Different Address & Data Patterns**<br>Comprehensive data integrity and boundary testing. | `axi2apb_random_100_trans_test`<br>`axi2apb_mixed_traffic_test` | Verifies data integrity across full 32-bit width (`0x00000000` to `0xFFFFFFFF`). | Address boundary bins, walking patterns. |
| **16** | **Boundary Addresses & Alignment**<br>Addresses aligned to 4 bytes within APB peripheral range. | `axi2apb_random_100_trans_test`<br>Sequences constraint | Verifies `addr[1:0] == 2'b00` across `0x0000_0000` to `0x0000_FFFC`. | Low, mid, and high address ranges. |
| **17** | **PSLVERR Response Behavior**<br>Document actual DUT behavior when APB asserts `PSLVERR`. | `axi2apb_pslverr_test`<br>`axi2apb_random_pslverr_test` | Verifies RTL maintains `OKAY` response (RTL ignores `PSLVERR`). | `PSLVERR` sampled high/low coverage point. |
| **18** | **Unsupported Features Documentation**<br>AXI Bursts (`len > 0`), Write Strobes (`WSTRB`). | All test suites & documentation | FSM operates strictly on single-beat completion (`DONE_SINGLE_RD`). | Documented in verification plan and reports. |

---

## 4. Testbench Architecture & Data Flow

```
+-----------------------------------------------------------------------------------------+
|                                    UVM TEST (test_top)                                 |
|                                                                                         |
|  +--------------------------------+               +----------------------------------+  |
|  |       AXI Master Agent         |               |         APB Slave Agent          |  |
|  |                                |               |                                  |  |
|  |  +--------------------------+  |               |  +----------------------------+  |  |
|  |  |    AXI Sequencer         |  |               |  |     APB Sequencer          |  |  |
|  |  +------------+-------------+  |               |  +-------------+--------------+  |  |
|  |               |                |               |                |                 |  |
|  |  +------------v-------------+  |               |  +-------------v--------------+  |  |
|  |  |    AXI Master Driver     |  |               |  |     APB Reactive Driver    |  |  |
|  |  +------------+-------------+  |               |  +-------------^--------------+  |  |
|  +---------------|----------------+               +----------------|-----------------+  |
|                  |                                                 |                    |
|             (AXI4 Interface)                                 (APB Interface)            |
|                  |                                                 |                    |
|  +---------------v-------------------------------------------------v-----------------+  |
|  |                                   DUT (axi2apb)                                   |  |
|  +-----------------------------------------------------------------------------------+  |
|                  |                                                 |                    |
|             (AXI Monitor)                                    (APB Monitor)              |
|                  |                                                 |                    |
|  +---------------v-------------------------------------------------v-----------------+  |
|  |                                  Analysis Ports                                   |  |
|  |                                         |                                         |  |
|  |          +------------------------------+-------------------------------+         |  |
|  |          |                                                              |         |  |
|  |  +-------v-------------------------+            +-----------------------v------+  |  |
|  |  |   Scoreboard & Reference Model  |            | Functional Coverage Collector|  |  |
|  |  +---------------------------------+            +------------------------------+  |  |
+--+-----------------------------------------------------------------------------------+--+
```

---

## 5. Coverage Goals & Metrics

- **Code Coverage Target:**
  - Line Coverage: $\ge 98\%$
  - Condition Coverage: $\ge 95\%$
  - Toggle Coverage: $\ge 98\%$
- **Functional Coverage Target:**
  - `axi_cg`: $100\%$
  - `apb_cg`: $100\%$
  - Overall Group Coverage: $100\%$

---

## 6. Regression Strategy

Simulations are executed via `sim/Makefile`:
1. `make regression_directed`: Runs all 12 directed corner cases.
2. `make regression_random`: Runs all 13 randomized multi-iteration tests.
3. `make regression_all`: Executes entire regression suite and generates combined HTML report at `urgReport/dashboard.html`.
