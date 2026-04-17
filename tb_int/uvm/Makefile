#------------------------------------------------------------------------------
# IP Name   : packet_scheduler/tb_int
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Description:
#   Questa FSE UVM Makefile for the packet_scheduler integration testbench.
#   Mirrors tb/uvm/Makefile but points at the 4-lane monolithic OPQ and the
#   tb_int_* sources. Phase 1 compiles only the OPQ + swb_ingress_stub +
#   walking-skeleton tb_int_top. Phase 2 will pull in emulator_mutrig,
#   mutrig_frame_deassembly, mts_processor, ring_buffer_cam, feb_frame_assembly.
#------------------------------------------------------------------------------
TB_INT_UVM_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TB_INT_DIR     := $(abspath $(TB_INT_UVM_DIR)/..)
PKT_DIR        := $(abspath $(TB_INT_DIR)/..)
REPO_ROOT      := $(abspath $(PKT_DIR)/..)
RTL_GEN_DIR    := $(abspath $(TB_INT_DIR)/rtl_gen_monolithic_4lane)
BUILD_DIR      := $(abspath $(TB_INT_UVM_DIR)/build)

QUESTA_HOME    ?= /data1/intelFPGA_pro/23.1/questa_fse
QUESTA_LICENSE := $(firstword $(wildcard $(QUESTA_HOME)/LR-*_License.dat))
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

UVM_SRC := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
QUESTA_MODELSIM_INI ?= $(QUESTA_HOME)/modelsim.ini
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini

QUARTUS_SH     ?= /data1/intelFPGA_pro/23.1/quartus/bin/quartus_sh
QUARTUS_ROOTDIR := /data1/intelFPGA_pro/23.1/quartus
QUARTUS_SIM_LIB := $(QUARTUS_ROOTDIR)/eda/sim_lib
IP_ROOT        := $(abspath $(REPO_ROOT))
EMU_DIR        := $(IP_ROOT)/emulator_mutrig/rtl
FRAME_RCV_DIR  := $(IP_ROOT)/mutrig_frame_deassembly
MTS_DIR        := $(IP_ROOT)/mutrig_timestamp_processor
RBCAM_DIR      := $(IP_ROOT)/ring-buffer_cam
FFA_DIR        := $(IP_ROOT)/feb_frame_assembly
DPI_CPP_PATH   ?= /usr/bin/gcc
OPQ_PAGE_RAM_DEPTH ?= 65536
OPQ_N_SHD          ?= 256
OPQ_TICKET_FIFO_DEPTH ?= 256

UVM_DEFINES ?= +define+UVM_NO_DPI
TB_INT_EXTRA_DEFINES ?=
UVM_DEFINES += +define+OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH)
UVM_DEFINES += +define+OPQ_N_SHD=$(OPQ_N_SHD)
UVM_DEFINES += +define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH)
UVM_DEFINES += $(TB_INT_EXTRA_DEFINES)

TEST ?= tb_int_smoke_test
RUN_DO ?= run -all; quit -f
PLUSARGS ?=

LM_LICENSE_FILE := $(TB_LICENSE_CHAIN)
export LM_LICENSE_FILE
MGLS_LICENSE_FILE := $(TB_LICENSE_CHAIN)
export MGLS_LICENSE_FILE

ALT_RAM_SRCS := \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/frame_table.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/handle_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/lane_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/page_ram.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/ticket_fifo.v \
	$(PKT_DIR)/rtl/sv_ver/vendor/alt_ram/tile_fifo.v

# lpm library (needed by mts_processor: LPM_COUNTER, LPM_MULT, LPM_DIVIDE)
LPM_SRCS := \
	$(QUARTUS_SIM_LIB)/220pack.vhd \
	$(QUARTUS_SIM_LIB)/220model.vhd

# RTL: IP cores pulled from mu3e-ip-cores/<ip>/ (matching each IP's hw.tcl order)
EMU_SV_SRCS := \
	$(EMU_DIR)/emulator_mutrig_pkg.sv \
	$(EMU_DIR)/prbs15_lfsr.sv \
	$(EMU_DIR)/crc16_8.sv \
	$(EMU_DIR)/hit_generator.sv \
	$(EMU_DIR)/frame_assembler.sv \
	$(EMU_DIR)/emulator_mutrig.sv

FRAME_RCV_SRCS := \
	$(FRAME_RCV_DIR)/crc16_calc.vhd \
	$(FRAME_RCV_DIR)/frame_rcv_ip.vhd

MTS_V_SRCS := \
	$(MTS_DIR)/dual_port_rom.v
MTS_VHDL_SRCS := \
	$(MTS_DIR)/mts_processor.vhd

RBCAM_V_SRCS := \
	$(RBCAM_DIR)/rtl/b2o_encoder.v
RBCAM_VHDL_SRCS := \
	$(RBCAM_DIR)/rtl/cam_helper_pkg.vhd \
	$(RBCAM_DIR)/rtl/alt_simple_dpram.vhd \
	$(RBCAM_DIR)/cam_mem_blk_a5.vhd \
	$(RBCAM_DIR)/cam_mem_a5.vhd \
	$(RBCAM_DIR)/rtl/alt_fifo/scfifo_w40d256.vhd \
	$(RBCAM_DIR)/rtl/alt_fifo/cmd_fifo/cmd_fifo.vhd \
	$(RBCAM_DIR)/addr_enc_logic_small.vhd \
	$(RBCAM_DIR)/addr_enc_logic_partitioned.vhd \
	$(RBCAM_DIR)/ring_buffer_cam_v2_core.vhd \
	$(RBCAM_DIR)/ring_buffer_cam.vhd

FFA_VHDL_SRCS := \
	$(FFA_DIR)/alt_fifos/alt_dcfifo_w40d256/alt_dcfifo_w40d256.vhd \
	$(FFA_DIR)/alt_fifos/alt_dcfifo_w40d256/alt_dcfifo_w40d256_patched.vhd \
	$(FFA_DIR)/alt_fifos/alt_dcfifo_w48d4/alt_dcfifo_w48d4.vhd \
	$(FFA_DIR)/alt_fifos/alt_scfifo_w40d8/alt_scfifo_w40d8.vhd \
	$(FFA_DIR)/alt_fifos/main_fifo/main_fifo.vhd \
	$(FFA_DIR)/alt_lpm/alt_parallel_add.vhd \
	$(FFA_DIR)/search_for_extreme.vhd \
	$(FFA_DIR)/search_for_extreme3.vhd \
	$(FFA_DIR)/feb_frame_assembly.vhd

VHDL_SRCS := \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut4_impl.vhd \
	$(RTL_GEN_DIR)/ordered_priority_queue_dut4.vhd \
	$(TB_INT_DIR)/rtl/swb_ingress_stub.vhd \
	$(FRAME_RCV_SRCS) \
	$(MTS_VHDL_SRCS) \
	$(RBCAM_VHDL_SRCS) \
	$(FFA_VHDL_SRCS)

SV_SRCS := \
	$(UVM_SRC)/uvm_pkg.sv \
	$(TB_INT_UVM_DIR)/tb_int_if.sv \
	$(TB_INT_UVM_DIR)/tb_int_hit0_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_hit2_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_frame_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_egress_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_run_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_run_enable_contract_sva.sv \
	$(TB_INT_UVM_DIR)/tb_int_pkg.sv \
	$(EMU_SV_SRCS) \
	$(TB_INT_DIR)/rtl/datapath_stub.sv \
	$(TB_INT_DIR)/rtl/tb_int_top.sv

V_SRCS := \
	$(MTS_V_SRCS) \
	$(RBCAM_V_SRCS)

VLOG_FLAGS := -modelsimini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work $(UVM_DEFINES) +incdir+$(UVM_SRC) +incdir+$(TB_INT_UVM_DIR) +incdir+$(EMU_DIR)
VCOM_FLAGS := -modelsimini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/work
VCOM_LPM_FLAGS := -modelsimini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/lpm
VSIM_FLAGS := -modelsimini $(MODELSIM_INI) -L altera_mf -L lpm -voptargs=+acc -nodpiexports -suppress 19 -suppress 3009

.PHONY: all gen_dut prepare compile run run_cached clean

all: run

gen_dut:
	QUARTUS_SH=$(QUARTUS_SH) QUARTUS_ROOTDIR=$(QUARTUS_ROOTDIR) \
	OPQ_N_SHD=$(OPQ_N_SHD) OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH) \
	OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH) \
	$(TB_INT_DIR)/scripts/gen_monolithic_dut_4lane.sh $(RTL_GEN_DIR)

prepare:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && \
		cp $(QUESTA_MODELSIM_INI) $(MODELSIM_INI) && \
		chmod u+w $(MODELSIM_INI) && \
		( [ -d $(BUILD_DIR)/work ] || $(VLIB) work ) && \
		( [ -d $(BUILD_DIR)/lpm  ] || $(VLIB) lpm ) && \
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) lpm  $(BUILD_DIR)/lpm  >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) altera_mf $(QUESTA_HOME)/intel/vhdl/altera_mf >/dev/null
	cp $(MTS_DIR)/dual_port_rom_init.txt $(BUILD_DIR)/dual_port_rom_init.txt
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

compile: prepare gen_dut
	$(VCOM) $(VCOM_LPM_FLAGS) $(LPM_SRCS)
	$(VLOG) $(VLOG_FLAGS) $(ALT_RAM_SRCS)
	$(VLOG) $(VLOG_FLAGS) $(V_SRCS)
	$(VCOM) $(VCOM_FLAGS) $(VHDL_SRCS)
	$(VLOG) $(VLOG_FLAGS) $(SV_SRCS)

run: compile run_cached

run_cached:
	cd $(BUILD_DIR) && $(VSIM) $(VSIM_FLAGS) -c work.tb_int_top +UVM_TESTNAME=$(TEST) \
		$(PLUSARGS) -do "$(RUN_DO)"

clean:
	@echo "Leaving $(BUILD_DIR) and $(RTL_GEN_DIR) for manual cleanup (see CLAUDE.md hard safety rules)."
