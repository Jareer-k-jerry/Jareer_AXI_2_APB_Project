
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
	vcs -sverilog -f build.flist -ntb_opts uvm-1.2 -cm line+tgl+cond -full64 -debug_all +UVM_TESTNAME=$(TEST)
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

sim:
	@test -f ./out/build_$(TEST)/simv || (echo "ERROR: Test executable ./out/build_$(TEST)/simv does not exist. Run 'make compile TEST=$(TEST)' first." && exit 1)
	cd ./out/build_$(TEST) && ./simv -cm line+tgl+cond +UVM_TESTNAME=$(TEST) | tee build_$(TEST).log


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
	firefox ./out/code_coverage_report/dashboard.html &


# ============================================================
# OPEN FUNCTIONAL COVERAGE REPORT
# ============================================================

func_covg_gui:
	firefox ./out/functional_coverage_report/groups.html &


# ============================================================
# CLEAN ONE TEST
# Usage:
# make clean TEST=<test_name>
# ============================================================

clean:
	cd ./out && rm -rf build_$(TEST)


# ============================================================
# CLEAN ALL TEST DIRECTORIES
# ============================================================

clean_all:
	cd ./out && rm -rf build_*


# ============================================================
# CLEAN COVERAGE REPORTS
# ============================================================

clean_covg:
	rm -rf ./out/code_coverage_report
	rm -rf ./out/functional_coverage_report


.PHONY: compile sim run gui code_covg func_covg coverage \
        code_covg_gui func_covg_gui clean clean_all clean_covg
