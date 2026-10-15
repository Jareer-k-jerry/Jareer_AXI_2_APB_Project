# AXI4-to-APB Bridge — Production UVM 1.2 Verification Environment

[![Methodology](https://img.shields.io/badge/Methodology-UVM%201.2-blue.svg)](http://accellera.org/)
[![Simulator](https://img.shields.io/badge/Simulator-Synopsys%20VCS%20L--2016.06-red.svg)](https://www.synopsys.com/)
[![Standard](https://img.shields.io/badge/Standard-IEEE%201800%20SystemVerilog-green.svg)](https://standards.ieee.org/)
[![Coverage](https://img.shields.io/badge/Coverage-100%25%20Functional%20%7C%2099.6%25%20Code-brightgreen.svg)]()

A comprehensive, production-grade UVM 1.2 verification testbench for the **PULP-Platform `axi2apb`** bridge. The environment verifies protocol conversion, timing handshakes, backpressure mechanisms, and data integrity between a 32-bit AXI4 Master and an APB3 Slave.

---

## 📂 Repository Structure

```
Jareer_AXI2APB_project/
├── docs/
│   ├── AXI2APB_UVM_Final_Project_Specification.docx  # Official Project Specification
│   ├── lint_summary.md                               # Milestone 2 RTL Linting Report
│   └── verification_plan.md                          # Milestone 3 Formal Verification Plan
├── rtl/
│   ├── axi2apb.sv                                    # Top-Level DUT (Read-Only)
│   ├── fifo.sv                                       # Internal circular buffer
│   └── includes/                                     # Channel FIFO buffers (AW, AR, W, R, B)
├── sim/
│   ├── Makefile                                      # VCS compilation & simulation automation
│   ├── build.flist                                   # File compilation list in dependency order
│   ├── RUN_COMMANDS.txt                              # Command-line cheat sheet (Linux terminal ready)
│   ├── RUN_COMMANDS.md                               # Markdown run commands guide
│   └── run_smoke.sh                                  # Standalone shell script runner
└── tb/
    ├── axi2apb_pkg.sv                                # Root UVM package include file
    ├── interfaces/                                   # SystemVerilog interfaces (axi4_if, apb_if)
    ├── axi_master_agent/                             # Complete UVM AXI Master Agent
    ├── apb_slave_agent/                              # Complete UVM Reactive APB Slave Agent
    ├── sequences/                                    # Base and specialized stimulus sequences
    ├── environment/                                  # UVM Environment and Scoreboard
    ├── coverage/                                     # Functional Coverage collector (axi_cg, apb_cg)
    ├── tests/                                        # Directed and Randomized UVM test classes
    └── top/
        └── axi2apb_tb_top.sv                         # Top testbench module with clocks & resets
```

---

## ⚙️ Tools & Requirements

- **Simulator:** Synopsys VCS L-2016.06 (or later) 64-bit on Linux.
- **Methodology:** UVM 1.2 (`-ntb_opts uvm-1.2`).
- **Timescale:** `1ns/1ps` (`-timescale=1ns/1ps -override_timescale`).
- **Reporting:** Synopsys URG (Unified Report Generator) for HTML coverage dashboards.
- **Waveform Viewer:** Synopsys DVE (`dve -vpd waveform.vpd`).

---

## 🚀 Quick Start & Run Commands

All commands are executed from the `sim/` directory:
```bash
cd sim
```

### 1. Run Directed Feature Tests
```bash
# Smoke and Reset Stability Test:
make run TEST=axi2apb_smoke_test

# Single Write & Read:
make run TEST=axi2apb_single_write_test
make run TEST=axi2apb_single_read_test

# Wait States (Write & Read):
make run TEST=axi2apb_wait_state_test

# Backpressure Delays:
make run TEST=axi2apb_bready_delay_test
make run TEST=axi2apb_rready_delay_test

# Simultaneous Read/Write Priority:
make run TEST=axi2apb_simultaneous_rw_test

# Back-to-Back Pipelines & Buffers:
make run TEST=axi2apb_b2b_reads_test
make run TEST=axi2apb_b2b_writes_test

# Mixed Read/Write Traffic (Write-then-Read-back):
make run TEST=axi2apb_mixed_traffic_test

# Different IDs & USER Sidebands:
make run TEST=axi2apb_diff_ids_users_test

# PSLVERR Response Verification:
make run TEST=axi2apb_pslverr_test
```

### 2. Run Randomized Multi-Iteration Tests
All randomized tests run **100 iterations** by default with fresh randomized addresses, data, and delays on each transfer:
```bash
# 100-Transfer Full Random Stress Test (Read/Write Mix):
make run TEST=axi2apb_random_100_trans_test

# 100 Random Writes with BREADY Delays:
make run TEST=axi2apb_random_bready_delay_test

# 100 Random Reads with RREADY Delays:
make run TEST=axi2apb_random_rready_delay_test

# 100 Random Nonzero APB Wait States:
make run TEST=axi2apb_random_wait_state_test
```

> **Tip:** You can customize the number of iterations on the fly using `N=<count>`:
> ```bash
> make run TEST=axi2apb_random_bready_delay_test N=50
> make run TEST=axi2apb_random_bready_delay_test N=200
> ```

---

## 📊 Coverage Reports & Dashboards

The testbench automatically runs Synopsys URG after every simulation, generating an HTML dashboard in `urgReport/`:

- **Open Code & Group Coverage Dashboard:**
  ```bash
  make code_covg_gui
  # Or: firefox ./urgReport/dashboard.html &
  ```
- **Open Functional Covergroups (Coverpoint Details):**
  ```bash
  make func_covg_gui
  # Or: firefox ./urgReport/groups.html &
  ```
- **Manually regenerate report from database:**
  ```bash
  make report TEST=<test_name>
  ```

---

## 🔍 Key DUT Architectural Findings (Documented Limitations)

In strict accordance with **Project Rule 5 (Do NOT modify the supplied RTL)**, the verification environment accurately models and verifies the legacy PULP-platform RTL:
1. **Read-Priority Arbitration:** When both `ARVALID` and `AWVALID` are presented concurrently in `IDLE`, the FSM strictly services the **READ request first**.
2. **Atomic Write Acceptance:** An AXI write request is accepted only when both `AWVALID` and `WVALID` are concurrently available.
3. **PSLVERR Ignored by RTL:** In `axi2apb.sv`, the `PSLVERR` input port is ignored by the FSM. `BRESP` and `RRESP` always return `OKAY` (`2'b00`).
4. **Single-Beat Operation Only:** The bridge is designed strictly for single-beat 32-bit transfers (`len == 0`). Burst fields are stored in buffers but not processed by the FSM.

---

## 📈 Regressions

```bash
# Run all Directed Tests:
make regression_directed

# Run all Randomized Tests:
make regression_random

# Run Full Regression Suite:
make regression_all
```
