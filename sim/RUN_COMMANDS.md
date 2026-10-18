# AXI4-to-APB Bridge — VCS Run Commands Cheat Sheet

> **Note:** All commands must be run from inside the `sim/` directory:
> ```bash
> cd sim
> ```

---

## 1. Randomized Tests (100 Iterations by Default)

These tests execute with randomized addresses, randomized data, and varying delays across 100 consecutive iterations.

| Test Description | Run Command |
| :--- | :--- |
| **100-Transfer Full Random Stress Test** | `make run TEST=axi2apb_random_100_trans_test` |
| **100 Randomized Writes** | `make run TEST=axi2apb_random_single_write_test` |
| **100 Randomized Reads** | `make run TEST=axi2apb_random_single_read_test` |
| **Random APB Wait States (1-4 cycles)** | `make run TEST=axi2apb_random_wait_state_test` |
| **Random Write with BREADY Delays** | `make run TEST=axi2apb_random_bready_delay_test` |
| **Random Read with RREADY Delays** | `make run TEST=axi2apb_random_rready_delay_test` |
| **Random Simultaneous Read/Write Priority** | `make run TEST=axi2apb_random_simultaneous_rw_test` |
| **Random Back-to-Back Reads** | `make run TEST=axi2apb_random_b2b_reads_test` |
| **Random Back-to-Back Writes** | `make run TEST=axi2apb_random_b2b_writes_test` |
| **Random Mixed Read/Write Traffic** | `make run TEST=axi2apb_random_mixed_traffic_test` |
| **Random Diverse IDs & USER Sidebands** | `make run TEST=axi2apb_random_diff_ids_users_test` |
| **Random APB PSLVERR Injection** | `make run TEST=axi2apb_random_pslverr_test` |
| **Random Reset Smoke Stability** | `make run TEST=axi2apb_random_smoke_test` |

### Customizing Iteration Count from Command Line
You can change the number of iterations on the fly without editing code by adding `N=<count>`:
```bash
make run TEST=axi2apb_random_bready_delay_test N=50
make run TEST=axi2apb_random_bready_delay_test N=200
```

---

## 2. Directed Tests (Feature Corner Cases)

| Feature Checked | Run Command |
| :--- | :--- |
| **Reset & Idle Smoke Test** | `make run TEST=axi2apb_smoke_test` |
| **Single Write (immediate APB)** | `make run TEST=axi2apb_single_write_test` |
| **Single Read (immediate APB)** | `make run TEST=axi2apb_single_read_test` |
| **APB Wait States (Write & Read)** | `make run TEST=axi2apb_wait_state_test` |
| **Read with Delayed RREADY** | `make run TEST=axi2apb_rready_delay_test` |
| **Write with Delayed BREADY** | `make run TEST=axi2apb_bready_delay_test` |
| **Simultaneous Read & Write Priority** | `make run TEST=axi2apb_simultaneous_rw_test` |
| **Back-to-Back Reads (Pipeline)** | `make run TEST=axi2apb_b2b_reads_test` |
| **Back-to-Back Writes (Buffer)** | `make run TEST=axi2apb_b2b_writes_test` |
| **Mixed Traffic (R/W Interleaved)** | `make run TEST=axi2apb_mixed_traffic_test` |
| **Different IDs & USER Sidebands** | `make run TEST=axi2apb_diff_ids_users_test` |
| **APB PSLVERR Response Verification** | `make run TEST=axi2apb_pslverr_test` |

---

## 3. Coverage HTML Reports (Synopsys URG Dashboard)

Coverage reports are generated automatically inside the `urgReport/` directory after every simulation run.

- **To manually regenerate the HTML report:**
  ```bash
  make report TEST=axi2apb_random_100_trans_test
  ```
- **To merge coverage across multiple tests (Cumulative Coverage):**
  ```bash
  make merge
  ```
  *Merges coverage databases from all executed tests into `./urgReport/dashboard.html` and lists all completed tests in the Tests dashboard section.*

- **To view Dashboard in Firefox:**
  ```bash
  make code_covg_gui
  # Or:
  firefox ./urgReport/dashboard.html &
  ```
- **To view Functional Covergroups in Firefox:**
  ```bash
  make func_covg_gui
  # Or:
  firefox ./urgReport/groups.html &
  ```

---

## 4. Waveforms, Regressions & Cleaning

- **Open Waveforms in Synopsys DVE:**
  ```bash
  make gui TEST=axi2apb_random_bready_delay_test
  ```
- **Run All Directed Tests in Regression:**
  ```bash
  make regression_directed
  ```
- **Run All Randomized Tests in Regression:**
  ```bash
  make regression_random
  ```
- **Run Full Suite Regression:**
  ```bash
  make regression_all
  ```
- **Clean Build Artifacts:**
  ```bash
  make clean TEST=axi2apb_random_bready_delay_test
  make clean_all
  ```
