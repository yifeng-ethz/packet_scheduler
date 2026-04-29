TB_OLD_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR ?= $(TB_OLD_DIR)/build
OLD_TM_LANE_COUNT ?= 4
OLD_TM_STAGE_FIFO_DEPTH ?= 128
VSIM_PLUSARGS ?=
QUESTA_HOME ?= /data1/questaone_sim/questasim
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
QUESTA_MODELSIM_INI ?= $(QUESTA_HOME)/modelsim.ini
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini

export LM_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export MGLS_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export SALT_LICENSE_SERVER := $(ETH_MENTOR_SERVER)
export QSIM_INI := $(QUESTA_MODELSIM_INI)

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))

RTL_SRCS := $(TB_OLD_DIR)/rtl/old_time_merger_ref.sv
SMOKE_SRCS := $(TB_OLD_DIR)/tb/old_time_merger_ref_smoke_tb.sv
LOSS_SRCS := $(TB_OLD_DIR)/tb/old_time_merger_ref_loss_tb.sv

.PHONY: prepare compile loss-compile smoke loss smoke-all clean

prepare:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && \
		cp $(QUESTA_MODELSIM_INI) $(MODELSIM_INI) && \
		chmod u+w $(MODELSIM_INI) && \
		$(VLIB) work && \
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null

compile: prepare
	cd $(BUILD_DIR) && $(VLOG) -ini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work +define+OLD_TM_LANE_COUNT=$(OLD_TM_LANE_COUNT) $(RTL_SRCS) $(SMOKE_SRCS)

loss-compile: prepare
	cd $(BUILD_DIR) && $(VLOG) -ini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work +define+OLD_TM_LANE_COUNT=$(OLD_TM_LANE_COUNT) +define+OLD_TM_STAGE_FIFO_DEPTH=$(OLD_TM_STAGE_FIFO_DEPTH) $(RTL_SRCS) $(LOSS_SRCS)

smoke: compile
	cd $(BUILD_DIR) && $(VSIM) -ini $(MODELSIM_INI) -c work.old_time_merger_ref_smoke_tb $(VSIM_PLUSARGS) -do "run -all; quit -f" && \
		! grep -E "\*\* Fatal:|Errors: [1-9][0-9]*" transcript

loss: loss-compile
	cd $(BUILD_DIR) && $(VSIM) -ini $(MODELSIM_INI) -c work.old_time_merger_ref_loss_tb $(VSIM_PLUSARGS) -do "run -all; quit -f" && \
		! grep -E "\*\* Fatal:|Errors: [1-9][0-9]*" transcript

smoke-all:
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane4 OLD_TM_LANE_COUNT=4 smoke
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane8 OLD_TM_LANE_COUNT=8 smoke
	$(MAKE) BUILD_DIR=$(BUILD_DIR)_lane16 OLD_TM_LANE_COUNT=16 smoke

clean:
	rm -rf $(BUILD_DIR)
