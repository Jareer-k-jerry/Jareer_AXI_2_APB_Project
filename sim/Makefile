
TEST ?= apb_agent_validation_test

# ============================================================
# COMPILE
# Usage:
# make compile TEST=<test_name>
# ============================================================

# Shell configuration for robust command execution and pipeline error propagation
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

compile:
	@mkdir -p ./out
	vcs -sverilog -timescale=1ns/1ps -override_timescale -f build.flist -ntb_opts uvm-1.2 -cm line+tgl+cond -full64 -debug_all +UVM_TESTNAME=$(TEST)
	@rm -rf ./out/build_$(TEST)
	@mkdir -p ./out/build_$(TEST)
	@for item in csrc simv.daidir simv.vdb simv vc_hdrs.h ucli.key; do \
		if [ -e "$$item" ]; then \
			mv "$$item" ./out/build_$(TEST)/; \
		fi; \
	done
	@test -f ./out/build_$(TEST)/simv || (echo "ERROR: Compilation finished but simv executable was not found!" && exit 1)

# ============================================================
# SIMULATION
# Usage:
# make sim TEST=<test_name>
# ============================================================

# Optional transaction count override (e.g., make run TEST=xxx N=100)
N ?=
PLUSARGS ?=

ifneq ($(N),)
  RUN_ARGS := +NUM_TRANS=$(N) $(PLUSARGS)
else
  RUN_ARGS := $(PLUSARGS)
endif

sim:
	@test -f ./out/build_$(TEST)/simv || (echo "ERROR: Test executable ./out/build_$(TEST)/simv does not exist. Run 'make compile TEST=$(TEST)' first." && exit 1)
	cd ./out/build_$(TEST) && ./simv -cm line+tgl+cond -cm_name $(TEST) +UVM_TESTNAME=$(TEST) $(RUN_ARGS) | tee build_$(TEST).log
	@if [ -d "./out/build_$(TEST)/simv.vdb" ]; then \
		echo ">>> Generating URG Coverage HTML Report for $(TEST) ..."; \
		(cd ./out/build_$(TEST) && urg -dir simv.vdb -report urgReport) && \
		rm -rf ./urgReport && \
		cp -r ./out/build_$(TEST)/urgReport ./urgReport && \
		echo "============================================================" && \
		echo "Coverage Report generated successfully in urgReport/ folder!" && \
		echo "  Open in browser: ./urgReport/dashboard.html" && \
		echo "============================================================"; \
	fi


# ============================================================
# COMPILE + SIMULATE
# Usage:
# make run TEST=<test_name>
# ============================================================

run: compile sim


# ============================================================
# OPEN WAVEFORM
# Usage:
# make gui TEST=<test_name>
# ============================================================

gui:
	cd ./out/build_$(TEST) && dve -vpd waveform.vpd


# ============================================================
# GENERATE URG HTML REPORT MANUALLY
# Usage:
# make report TEST=<test_name>
# ============================================================

report urg:
	@test -d ./out/build_$(TEST)/simv.vdb || (echo "ERROR: Coverage database ./out/build_$(TEST)/simv.vdb not found. Run 'make run TEST=$(TEST)' first." && exit 1)
	cd ./out/build_$(TEST) && urg -dir simv.vdb -report urgReport
	@rm -rf ./urgReport
	@cp -r ./out/build_$(TEST)/urgReport ./urgReport
	@echo "============================================================"
	@echo "Coverage Report generated successfully in urgReport/ folder!"
	@echo "  Open in browser: ./urgReport/dashboard.html"
	@echo "============================================================"


# ============================================================
# CODE COVERAGE
#
# Merges coverage databases from all test directories.
#
# Output:
# ./out/code_coverage_report
# ============================================================

code_covg:
	rm -rf ./out/code_coverage_report
	urg -report ./out/code_coverage_report -dir ./out/build_*/*.vdb


# ============================================================
# FUNCTIONAL COVERAGE
#
# Uses the same VDB files.
# Covergroups are collected from axi2apb_coverage.sv.
#
# Output:
# ./out/functional_coverage_report
# ============================================================

func_covg:
	rm -rf ./out/functional_coverage_report
	urg -report ./out/functional_coverage_report -dir ./out/build_*/*.vdb


# ============================================================
# GENERATE BOTH COVERAGE REPORTS
# ============================================================

coverage: code_covg func_covg


# ============================================================
# OPEN CODE COVERAGE REPORT
# ============================================================

code_covg_gui:
	firefox ./urgReport/dashboard.html &


# ============================================================
# OPEN FUNCTIONAL COVERAGE REPORT
# ============================================================

func_covg_gui:
	firefox ./urgReport/groups.html &


# ============================================================
# CLEAN ONE TEST
# Usage:
# make clean TEST=<test_name>
# ============================================================

clean:
	cd ./out && rm -rf build_$(TEST)
	rm -rf ./urgReport

clean_all:
	cd ./out && rm -rf build_*
	rm -rf ./urgReport ./out/code_coverage_report ./out/functional_coverage_report


# ============================================================
# REGRESSIONS
# ============================================================

DIRECTED_TESTS = axi2apb_smoke_test \
                 axi2apb_single_write_test \
                 axi2apb_single_read_test \
                 axi2apb_wait_state_test \
                 axi2apb_simultaneous_rw_test

RANDOM_TESTS   = axi2apb_random_smoke_test \
                 axi2apb_random_single_write_test \
                 axi2apb_random_single_read_test \
                 axi2apb_random_wait_state_test \
                 axi2apb_random_simultaneous_rw_test \
                 axi2apb_constrained_random_test

regression_directed:
	@for t in $(DIRECTED_TESTS); do \
		echo ">>> Running Directed Test: $$t <<<"; \
		$(MAKE) run TEST=$$t || exit 1; \
	done
	$(MAKE) coverage

regression_random:
	@for t in $(RANDOM_TESTS); do \
		echo ">>> Running Randomized Test: $$t <<<"; \
		$(MAKE) run TEST=$$t || exit 1; \
	done
	$(MAKE) coverage

regression_all:
	@for t in $(DIRECTED_TESTS) $(RANDOM_TESTS); do \
		echo ">>> Running Test: $$t <<<"; \
		$(MAKE) run TEST=$$t || exit 1; \
	done
	$(MAKE) coverage


.PHONY: compile sim run gui code_covg func_covg coverage \
        code_covg_gui func_covg_gui clean clean_all clean_covg \
        regression_directed regression_random regression_all
