#
# Author: Yifeng Wang (yifenwan@phys.ethz.ch)
#
TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PKT_DIR := $(abspath $(TB_DIR)/../..)
REPO_ROOT := $(abspath $(PKT_DIR)/..)
DEFAULT_BUILD_DIR := $(abspath $(TB_DIR)/build)
BUILD_DIR ?= $(DEFAULT_BUILD_DIR)

QUESTA_HOME_ALLOWED := /data1/questaone_sim/questasim
QUESTA_HOME ?= $(QUESTA_HOME_ALLOWED)
ifneq ($(QUESTA_HOME),$(QUESTA_HOME_ALLOWED))
$(error Unsupported QUESTA_HOME=$(QUESTA_HOME). Use $(QUESTA_HOME_ALLOWED) only)
endif
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
QSIM_INI := $(QUESTA_HOME)/modelsim.ini
LM_LICENSE_FILE := $(ETH_MENTOR_SERVER)
MGLS_LICENSE_FILE := $(ETH_MENTOR_SERVER)
SALT_LICENSE_SERVER := $(ETH_MENTOR_SERVER)
export LM_LICENSE_FILE MGLS_LICENSE_FILE SALT_LICENSE_SERVER QSIM_INI

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))
VOPT := $(firstword $(wildcard $(QUESTA_HOME)/bin/vopt $(QUESTA_HOME)/linux_x86_64/vopt))
VCOVER := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcover $(QUESTA_HOME)/linux_x86_64/vcover))

UVM_SRC := $(firstword $(wildcard $(QUESTA_HOME)/verilog_src/uvm-1.2/src $(QUESTA_HOME)/uvm-1.2/src))
QUESTA_MODELSIM_INI ?= $(QSIM_INI)
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini
DPI_CPP_PATH ?= /usr/bin/gcc
OPQ_PAGE_RAM_DEPTH ?= 65536
OPQ_N_SHD ?= 256
OPQ_N_HIT ?= 255
OPQ_N_LANE ?= 2
OPQ_TICKET_FIFO_DEPTH ?= $(shell s=$(OPQ_N_SHD); l=$(OPQ_N_LANE); target_lane=$$((s * 32)); target_scan=$$((s * l * 2)); target=$$target_lane; if [ "$$target_scan" -gt "$$target" ]; then target=$$target_scan; fi; d=256; while [ "$$d" -lt "$$target" ]; do d=$$((d * 2)); done; echo $$d)
OPQ_LANE_FIFO_DEPTH ?= $(shell n=$(OPQ_N_LANE); if [ "$$n" -le 2 ]; then echo 1024; elif [ "$$n" -le 4 ]; then echo 2048; elif [ "$$n" -le 8 ]; then echo 4096; elif [ "$$n" -le 16 ]; then echo 8192; else echo 16384; fi)
OPQ_CHANNEL_WIDTH ?= $(shell n=$(OPQ_N_LANE); if [ "$$n" -le 4 ]; then echo 2; elif [ "$$n" -le 8 ]; then echo 3; elif [ "$$n" -le 16 ]; then echo 4; else awk -v n="$$n" 'BEGIN { w=0; p=1; while (p<n) { p*=2; w++ } if (w<1) w=1; print w }'; fi)
OPQ_PAGE_RAM_RD_WIDTH ?= 36
OPQ_EGRESS_SYMBOLS_PER_BEAT ?= $(shell w=$(OPQ_PAGE_RAM_RD_WIDTH); echo $$((w / 36)))
OPQ_EGRESS_EMPTY_WIDTH ?= $(shell n=$(OPQ_EGRESS_SYMBOLS_PER_BEAT); if [ "$$n" -le 1 ]; then echo 1; elif [ "$$n" -le 2 ]; then echo 1; elif [ "$$n" -le 4 ]; then echo 2; else echo 3; fi)

QUARTUS_SH ?= /data1/intelFPGA_pro/23.1/quartus/bin/quartus_sh
QUARTUS_ROOTDIR := /data1/intelFPGA_pro/23.1/quartus
QUARTUS_SIM_LIB ?= $(QUARTUS_ROOTDIR)/eda/sim_lib
UVM_DPI_SO := $(firstword $(wildcard $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/verilog_src/uvm-1.2/linux_x86_64/uvm_dpi.so))
UVM_DPI_LIB := $(basename $(UVM_DPI_SO))
UVM_DEFINES ?=
FORMAL_SVA ?= 0
FORMAL_STRICT ?= 0
FORMAL_PLANE ?= all
ifeq ($(FORMAL_SVA),1)
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_SVA
ifeq ($(FORMAL_PLANE),ingress)
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_INGRESS
endif
ifeq ($(FORMAL_PLANE),mover)
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_MOVER
endif
ifeq ($(FORMAL_PLANE),egress)
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_EGRESS +define+OPQ_ENABLE_NATIVE_FORMAL_FTABLE
endif
ifeq ($(FORMAL_PLANE),all)
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_INGRESS
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_MOVER
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_EGRESS
UVM_DEFINES += +define+OPQ_ENABLE_NATIVE_FORMAL_FTABLE
endif
endif
ifeq ($(FORMAL_STRICT),1)
UVM_DEFINES += +define+OPQ_NATIVE_FORMAL_STRICT
endif
UVM_DEFINES += +define+OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH)
UVM_DEFINES += +define+OPQ_N_SHD=$(OPQ_N_SHD)
UVM_DEFINES += +define+OPQ_N_HIT=$(OPQ_N_HIT)
UVM_DEFINES += +define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH)
UVM_DEFINES += +define+OPQ_N_LANE=$(OPQ_N_LANE)
UVM_DEFINES += +define+OPQ_LANE_FIFO_DEPTH=$(OPQ_LANE_FIFO_DEPTH)
UVM_DEFINES += +define+OPQ_CHANNEL_WIDTH=$(OPQ_CHANNEL_WIDTH)
UVM_DEFINES += +define+OPQ_PAGE_RAM_RD_WIDTH=$(OPQ_PAGE_RAM_RD_WIDTH)
UVM_DEFINES += +define+OPQ_EGRESS_SYMBOLS_PER_BEAT=$(OPQ_EGRESS_SYMBOLS_PER_BEAT)
UVM_DEFINES += +define+OPQ_EGRESS_EMPTY_WIDTH=$(OPQ_EGRESS_EMPTY_WIDTH)
TEST ?= opq_basic_smoke_test
TOP ?= tb_top
COV ?= 0
COV_CODE ?= sbecft
COV_VENDOR_RAM ?= 0
VSIM_ACC ?= +acc
RUN_DO ?= run -all; quit -f
DUT_IMPL ?= native_sv
VSIM_PLUSARGS ?=

ifeq ($(OPQ_N_LANE),4)
RTL_GEN_DIR := $(abspath $(PKT_DIR)/tb/rtl_gen_monolithic_4lane)
VHDL_SRCS := \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut4_impl.vhd \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut4.vhd
else
RTL_GEN_DIR := $(abspath $(PKT_DIR)/tb/rtl_gen_monolithic)
VHDL_SRCS := \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut_impl.vhd \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut.vhd
endif

ALT_RAM_SRCS := \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/frame_table.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/handle_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/lane_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/page_ram.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/ticket_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/tile_fifo.v

ifeq ($(DUT_IMPL),native_sv)
OPQ_DUT_WRAPPER_SRCS := \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_dut_array_sv.sv
else
OPQ_DUT_WRAPPER_SRCS := \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_dut_sv.sv
endif

SV_SRCS := \
	$(UVM_SRC)/uvm_pkg.sv \
	$(OPQ_DUT_WRAPPER_SRCS) \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_block_path.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_presenter.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_egress_packer.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic.sv \
	$(TB_DIR)/opq_if.sv \
	$(TB_DIR)/opq_pkg.sv \
	$(TB_DIR)/opq_env_pkg.sv \
	$(TB_DIR)/sva/opq_avst_ingress_sva.sv \
	$(TB_DIR)/sva/opq_avst_egress_sva.sv \
	$(TB_DIR)/sva/opq_hit3_contract_sva.sv \
	$(TB_DIR)/sva/opq_csr_sva.sv \
	$(TB_DIR)/sva/opq_drr_sva.sv \
	$(TB_DIR)/sva/opq_native_ingress_formal_sva.sv \
	$(TB_DIR)/sva/opq_native_block_path_formal_sva.sv \
	$(TB_DIR)/sva/opq_native_basic_presenter_formal_sva.sv \
	$(TB_DIR)/sva/opq_native_frame_table_formal_sva.sv \
	$(TB_DIR)/formal/opq_formal_ingress_tb.sv \
	$(TB_DIR)/formal/opq_formal_ftable_tb.sv \
	$(TB_DIR)/tb_top.sv

ifeq ($(DUT_IMPL),native_sv)
UVM_DEFINES += +define+OPQ_USE_NATIVE_SV
endif
VLOG_FLAGS := -ini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work $(UVM_DEFINES) +incdir+$(UVM_SRC) +incdir+$(TB_DIR)
VCOM_FLAGS := -ini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/work
VSIM_FLAGS := -ini $(MODELSIM_INI) -L altera_mf $(if $(VSIM_ACC),-voptargs=$(VSIM_ACC)) $(if $(UVM_DPI_LIB),-dpicpppath $(DPI_CPP_PATH) -sv_lib $(UVM_DPI_LIB))
VOPT_FLAGS := -ini $(MODELSIM_INI) -check_synthesis
ifeq ($(COV),1)
VLOG_FLAGS += +cover=$(COV_CODE)
VCOM_FLAGS += +cover=$(COV_CODE)
VSIM_FLAGS += -coverage
endif
ALT_RAM_VLOG_FLAGS = $(VLOG_FLAGS)
ifeq ($(COV),1)
ifeq ($(COV_VENDOR_RAM),0)
ALT_RAM_VLOG_FLAGS = $(filter-out +cover=%,$(VLOG_FLAGS))
endif
endif

.PHONY: all gen_dut prepare compile run run_no_compile run_cov run_cov_no_compile lint lint_src lint_elab clean license_diag coverage_report

all: run

gen_dut:
ifeq ($(OPQ_N_LANE),4)
	QUARTUS_SH=$(QUARTUS_SH) QUARTUS_ROOTDIR=$(QUARTUS_ROOTDIR) OPQ_N_SHD=$(OPQ_N_SHD) OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH) OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH) $(PKT_DIR)/tb_int/scripts/gen_monolithic_dut_4lane.sh $(RTL_GEN_DIR)
else
	QUARTUS_SH=$(QUARTUS_SH) QUARTUS_ROOTDIR=$(QUARTUS_ROOTDIR) OPQ_N_SHD=$(OPQ_N_SHD) OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH) $(TB_DIR)/scripts/gen_monolithic_dut.sh $(RTL_GEN_DIR)
endif

prepare:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && \
		cp $(QUESTA_MODELSIM_INI) $(MODELSIM_INI) && \
		chmod u+w $(MODELSIM_INI) && \
		$(VLIB) work && \
		$(VLIB) altera_mf && \
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) altera_mf $(BUILD_DIR)/altera_mf >/dev/null
	cd $(BUILD_DIR) && \
		$(VCOM) -ini $(MODELSIM_INI) -2008 -work altera_mf $(QUARTUS_SIM_LIB)/altera_mf_components.vhd >/dev/null && \
		$(VCOM) -ini $(MODELSIM_INI) -2008 -work altera_mf $(QUARTUS_SIM_LIB)/altera_mf.vhd >/dev/null
	@if [ -x "$(DPI_CPP_PATH)" ]; then \
		tmp_file="$(MODELSIM_INI).tmp"; \
		awk ' \
			BEGIN { inserted = 0; seen = 0 } \
			{ \
				if ($$0 ~ /^DpiCppPath[[:space:]]*=/) { \
					if (seen == 0) { \
						print "DpiCppPath = $(DPI_CPP_PATH)"; \
						seen = 1; \
					} \
					next; \
				} \
				print; \
				if ($$0 == "[vsim]" && inserted == 0 && seen == 0) { \
					print "DpiCppPath = $(DPI_CPP_PATH)"; \
					inserted = 1; \
					seen = 1; \
				} \
			} \
			END { \
				if (inserted == 0 && seen == 0) { \
					print "DpiCppPath = $(DPI_CPP_PATH)"; \
				} \
			}' "$(MODELSIM_INI)" > "$$tmp_file"; \
		mv -f "$$tmp_file" "$(MODELSIM_INI)"; \
	fi

compile: prepare
	$(VLOG) $(ALT_RAM_VLOG_FLAGS) $(ALT_RAM_SRCS)
ifeq ($(DUT_IMPL),vhdl)
	$(MAKE) gen_dut
	$(VCOM) $(VCOM_FLAGS) $(VHDL_SRCS)
endif
	$(VLOG) $(VLOG_FLAGS) $(SV_SRCS)

run: compile
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) -c work.$(TOP) +UVM_TESTNAME=$(TEST) $(VSIM_PLUSARGS) -do "$(RUN_DO)"

run_no_compile:
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) -c work.$(TOP) +UVM_TESTNAME=$(TEST) $(VSIM_PLUSARGS) -do "$(RUN_DO)"

run_cov: compile
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) -c work.$(TOP) +UVM_TESTNAME=$(TEST) $(VSIM_PLUSARGS) -do "coverage save -onexit opq_$(TEST).ucdb; $(RUN_DO)"

run_cov_no_compile:
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) -c work.$(TOP) +UVM_TESTNAME=$(TEST) $(VSIM_PLUSARGS) -do "coverage save -onexit opq_$(TEST).ucdb; $(RUN_DO)"

lint:
	python3 $(PKT_DIR)/tb/legacy/tb/lint/lint_opq.py

lint_src: gen_dut prepare
	$(VCOM) $(VCOM_FLAGS) -lint=full -check_synthesis $(VHDL_SRCS)

lint_elab: compile
	$(VOPT) $(VOPT_FLAGS) work.$(TOP) -o $(TOP)_opt

license_diag:
	@echo "QUESTA_HOME=$(QUESTA_HOME)"
	@echo "LM_LICENSE_FILE=$(LM_LICENSE_FILE)"
	@echo "MGLS_LICENSE_FILE=$(MGLS_LICENSE_FILE)"
	@echo "SALT_LICENSE_SERVER=$(SALT_LICENSE_SERVER)"
	@echo "MODELSIM_INI=$(MODELSIM_INI)"
	@echo "--- vsim banner ---"
	@$(VSIM) -version
	@echo "--- mtiverification availability ---"
	@$(QUESTA_HOME)/linux_x86_64/lmutil lmdiag -c $(ETH_MENTOR_SERVER) -n mtiverification || true

coverage_report:
	@if [ -z "$(VCOVER)" ]; then \
		echo "vcover not found under $(QUESTA_HOME)"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && $(VCOVER) report -details -all opq_$(TEST).ucdb

clean:
	rm -rf $(BUILD_DIR) $(RTL_GEN_DIR)
