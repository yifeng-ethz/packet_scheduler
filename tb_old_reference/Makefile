TB_OLD_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR ?= $(TB_OLD_DIR)/build
OLD_TM_LANE_COUNT ?= 4
VSIM_PLUSARGS ?=
QUESTA_HOME ?= /data1/questaone_sim/questasim
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch

export LM_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export MGLS_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export SALT_LICENSE_SERVER := $(ETH_MENTOR_SERVER)

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))

RTL_SRCS := $(TB_OLD_DIR)/rtl/old_time_merger_ref.sv
SMOKE_SRCS := $(TB_OLD_DIR)/tb/old_time_merger_ref_smoke_tb.sv

.PHONY: prepare compile smoke smoke-all clean

prepare:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VLIB) work

compile: prepare
	cd $(BUILD_DIR) && $(VLOG) -sv -work work +define+OLD_TM_LANE_COUNT=$(OLD_TM_LANE_COUNT) $(RTL_SRCS) $(SMOKE_SRCS)

smoke: compile
	cd $(BUILD_DIR) && $(VSIM) -c work.old_time_merger_ref_smoke_tb $(VSIM_PLUSARGS) -do "run -all; quit -f" && \
		! grep -E "\*\* Fatal:|Errors: [1-9][0-9]*" transcript

smoke-all:
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane4 OLD_TM_LANE_COUNT=4 smoke
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane8 OLD_TM_LANE_COUNT=8 smoke
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane16 OLD_TM_LANE_COUNT=16 smoke

clean:
	rm -rf $(BUILD_DIR)
