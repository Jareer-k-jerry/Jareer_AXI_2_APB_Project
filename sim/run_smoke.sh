#!/bin/bash
# ==============================================================================
# Script: run_smoke.sh
# Description: Automated script to compile and run UVM tests with VCS.
# Usage: ./run_smoke.sh [TEST_NAME]
# Default: axi_master_agent_test
# ==============================================================================

set -e

TEST="${1:-apb_agent_validation_test}"

echo "================================================================="
echo " Compiling AXI4-to-APB Verification with Synopsys VCS"
echo " Test Target: ${TEST}"
echo "================================================================="

mkdir -p ./out/build_${TEST}

vcs -sverilog \
    -f build.flist \
    -ntb_opts uvm-1.2 \
    -cm line+tgl+cond \
    -full64 \
    -debug_all \
    +UVM_TESTNAME=${TEST}

echo "Moving compilation binaries to ./out/build_${TEST}/ ..."
mv csrc simv.daidir simv.vdb simv vc_hdrs.h ./out/build_${TEST}/ 2>/dev/null || true

echo "================================================================="
echo " Running Simulation: ${TEST}"
echo "================================================================="
cd ./out/build_${TEST}
./simv -cm line+tgl+cond +UVM_TESTNAME=${TEST} | tee build_${TEST}.log

echo "================================================================="
echo " Simulation Complete. Log saved to ./out/build_${TEST}/build_${TEST}.log"
echo "================================================================="
