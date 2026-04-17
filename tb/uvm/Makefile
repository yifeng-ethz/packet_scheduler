#
# Author: Yifeng Wang (yifenwan@phys.ethz.ch)
#
TB_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PKT_DIR := $(abspath $(TB_DIR)/../..)
REPO_ROOT := $(abspath $(PKT_DIR)/..)
DEFAULT_BUILD_DIR := $(abspath $(TB_DIR)/build)
BUILD_DIR ?= $(DEFAULT_BUILD_DIR)

QUESTA_PREFER_FE ?= 0
ifeq ($(QUESTA_PREFER_FE),1)
ifneq ($(wildcard /data1/intelFPGA_pro/23.1/questa_fe),)
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
else
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
endif
else
ifneq ($(wildcard /data1/intelFPGA_pro/23.1/questa_fse),)
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
else
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
endif
endif
QUESTA_FLAVOR := $(notdir $(QUESTA_HOME))
QUESTA_LICENSE ?= $(firstword $(wildcard $(QUESTA_HOME)/LR-*_License.dat))
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
TB_LICENSE_CHAIN := $(ETH_MENTOR_SERVER)
ifneq ($(wildcard $(QUESTA_LICENSE)),)
TB_LICENSE_CHAIN := $(ETH_MENTOR_SERVER):$(QUESTA_LICENSE)
endif

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))
VOPT := $(firstword $(wildcard $(QUESTA_HOME)/bin/vopt $(QUESTA_HOME)/linux_x86_64/vopt))
VCOVER := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcover $(QUESTA_HOME)/linux_x86_64/vcover))

UVM_SRC := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
QUESTA_MODELSIM_INI ?= $(QUESTA_HOME)/modelsim.ini
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini
DPI_CPP_PATH ?= /usr/bin/gcc
OPQ_PAGE_RAM_DEPTH ?= 65536
OPQ_N_SHD ?= 256
OPQ_TICKET_FIFO_DEPTH ?= 256
OPQ_N_LANE ?= 2

QUARTUS_SH ?= /data1/intelFPGA_pro/23.1/quartus/bin/quartus_sh
QUARTUS_ROOTDIR := /data1/intelFPGA_pro/23.1/quartus
UVM_DEFINES ?= +define+UVM_NO_DPI
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
UVM_DEFINES += +define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH)
UVM_DEFINES += +define+OPQ_N_LANE=$(OPQ_N_LANE)
TEST ?= opq_basic_smoke_test
TOP ?= tb_top
COV ?= 0
COV_CODE ?= sbecft
RUN_DO ?= run -all; quit -f
DUT_IMPL ?= native_sv
VSIM_PLUSARGS ?=

LM_LICENSE_FILE := $(TB_LICENSE_CHAIN)
export LM_LICENSE_FILE
MGLS_LICENSE_FILE := $(TB_LICENSE_CHAIN)
export MGLS_LICENSE_FILE
unexport SALT_LICENSE_SERVER
ifeq ($(QUESTA_FLAVOR),questa_fe)
SALT_LICENSE_SERVER := $(ETH_MENTOR_SERVER)
export SALT_LICENSE_SERVER
endif

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

SV_SRCS := \
	$(UVM_SRC)/uvm_pkg.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_dut_sv.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_block_path.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_presenter.sv \
	$(PKT_DIR)/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv \
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
VLOG_FLAGS := -modelsimini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work $(UVM_DEFINES) +incdir+$(UVM_SRC) +incdir+$(TB_DIR)
VCOM_FLAGS := -modelsimini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/work
VSIM_FLAGS := -modelsimini $(MODELSIM_INI) -L altera_mf -voptargs=+acc
VOPT_FLAGS := -modelsimini $(MODELSIM_INI) -check_synthesis
ifeq ($(COV),1)
VLOG_FLAGS += +cover=$(COV_CODE)
VCOM_FLAGS += +cover=$(COV_CODE)
VSIM_FLAGS += -coverage
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
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) altera_mf $(QUESTA_HOME)/intel/vhdl/altera_mf >/dev/null
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
	$(VLOG) $(VLOG_FLAGS) $(ALT_RAM_SRCS)
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
	@echo "QUESTA_FLAVOR=$(QUESTA_FLAVOR)"
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
