#------------------------------------------------------------------------------
# IP Name   : packet_scheduler/tb_int
# Author    : Yifeng Wang (yifenwan@phys.ethz.ch)
# Description:
#   QuestaOne UVM Makefile for the packet_scheduler integration testbench.
#   Mirrors tb/uvm/Makefile but points at the 4-lane monolithic OPQ and the
#   tb_int_* sources. Phase 1 compiles only the OPQ + swb_ingress_stub +
#   walking-skeleton tb_int_top. Phase 2 will pull in emulator_mutrig,
#   mutrig_frame_deassembly, mts_processor, ring_buffer_cam, feb_frame_assembly.
#
#   FEB firmware RTL (emulator_mutrig, mutrig_frame_deassembly, mts_processor,
#   ring_buffer_cam, feb_frame_assembly) is compiled from the authoritative
#   copies under firmware_builds/feb_system_v3/synthesis/submodules/ — the
#   Qsys-generated top-level submodule tree that Quartus compiles for the FEB
#   FPGA bitstream. This keeps tb_int in lock-step with the integration build.
#------------------------------------------------------------------------------
TB_INT_UVM_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TB_INT_DIR     := $(abspath $(TB_INT_UVM_DIR)/..)
PKT_DIR        := $(abspath $(TB_INT_DIR)/..)
REPO_ROOT      := $(abspath $(PKT_DIR)/..)
RTL_GEN_DIR    := $(abspath $(TB_INT_DIR)/rtl_gen_monolithic_4lane)
BUILD_DIR      := $(abspath $(TB_INT_UVM_DIR)/build)

QUESTA_HOME_ALLOWED := /data1/questaone_sim/questasim
QUESTA_HOME    ?= $(QUESTA_HOME_ALLOWED)
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
UVM_DPI_SO := $(firstword $(wildcard $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/verilog_src/uvm-1.2/linux_x86_64/uvm_dpi.so))
UVM_DPI_LIB := $(basename $(UVM_DPI_SO))

UVM_SRC := $(firstword $(wildcard $(QUESTA_HOME)/verilog_src/uvm-1.2/src $(QUESTA_HOME)/uvm-1.2/src))
QUESTA_MODELSIM_INI ?= $(QSIM_INI)
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini

QUARTUS_SH     ?= /data1/intelFPGA_pro/23.1/quartus/bin/quartus_sh
QUARTUS_ROOTDIR := /data1/intelFPGA_pro/23.1/quartus
QUARTUS_SIM_LIB := $(QUARTUS_ROOTDIR)/eda/sim_lib
IP_ROOT        := $(abspath $(REPO_ROOT))
# FEB firmware RTL is pulled from the Qsys-generated top-level submodule
# tree used by the FEB compile, so tb_int tracks the exact source set in
# feb_system_v3/synthesis/submodules/ (see CLAUDE.md "Qsys IP Source File Rule").
FIRMWARE_BUILDS_DIR := $(IP_ROOT)/firmware_builds
FEB_SUBMOD_DIR := $(FIRMWARE_BUILDS_DIR)/feb_system_v3/synthesis/submodules
DPI_CPP_PATH   ?= /usr/bin/gcc
OPQ_PAGE_RAM_DEPTH ?= 65536
OPQ_N_SHD          ?= 256
OPQ_TICKET_FIFO_DEPTH ?= 256

UVM_DEFINES ?=
TB_INT_EXTRA_DEFINES ?=
UVM_DEFINES += +define+OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH)
UVM_DEFINES += +define+OPQ_N_SHD=$(OPQ_N_SHD)
UVM_DEFINES += +define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH)
UVM_DEFINES += $(TB_INT_EXTRA_DEFINES)

TEST ?= tb_int_smoke_test
RUN_DO ?= run -all; quit -f
PLUSARGS ?=

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

# RTL: FEB firmware IPs pulled from the feb_system_v3 Qsys submodule tree
# (authoritative copy for the FEB compile). File order matches each IP's
# _hw.tcl so compile-order dependencies are preserved.
EMU_SV_SRCS := \
	$(FEB_SUBMOD_DIR)/emulator_mutrig_pkg.sv \
	$(FEB_SUBMOD_DIR)/prbs15_lfsr.sv \
	$(FEB_SUBMOD_DIR)/crc16_8.sv \
	$(FEB_SUBMOD_DIR)/hit_generator.sv \
	$(FEB_SUBMOD_DIR)/frame_assembler.sv \
	$(FEB_SUBMOD_DIR)/emulator_mutrig.sv

FRAME_RCV_SRCS := \
	$(FEB_SUBMOD_DIR)/crc16_calc.vhd \
	$(FEB_SUBMOD_DIR)/frame_rcv_ip.vhd

MTS_V_SRCS := \
	$(FEB_SUBMOD_DIR)/dual_port_rom.v
MTS_VHDL_SRCS := \
	$(FEB_SUBMOD_DIR)/mts_processor.vhd

RBCAM_V_SRCS := \
	$(FEB_SUBMOD_DIR)/b2o_encoder.v
RBCAM_VHDL_SRCS := \
	$(FEB_SUBMOD_DIR)/cam_helper_pkg.vhd \
	$(FEB_SUBMOD_DIR)/alt_simple_dpram.vhd \
	$(FEB_SUBMOD_DIR)/cam_mem_blk_a5.vhd \
	$(FEB_SUBMOD_DIR)/cam_mem_a5.vhd \
	$(FEB_SUBMOD_DIR)/alt_fifo/scfifo_w40d256.vhd \
	$(FEB_SUBMOD_DIR)/alt_fifo/cmd_fifo/cmd_fifo.vhd \
	$(FEB_SUBMOD_DIR)/addr_enc_logic_small.vhd \
	$(FEB_SUBMOD_DIR)/addr_enc_logic_partitioned.vhd \
	$(FEB_SUBMOD_DIR)/ring_buffer_cam_v2_core.vhd \
	$(FEB_SUBMOD_DIR)/ring_buffer_cam.vhd

FFA_VHDL_SRCS := \
	$(FEB_SUBMOD_DIR)/alt_dcfifo_w40d256.vhd \
	$(FEB_SUBMOD_DIR)/alt_dcfifo_w40d256_patched.vhd \
	$(FEB_SUBMOD_DIR)/alt_dcfifo_w48d4.vhd \
	$(FEB_SUBMOD_DIR)/alt_scfifo_w40d8.vhd \
	$(FEB_SUBMOD_DIR)/main_fifo.vhd \
	$(FEB_SUBMOD_DIR)/alt_parallel_add.vhd \
	$(FEB_SUBMOD_DIR)/search_for_extreme.vhd \
	$(FEB_SUBMOD_DIR)/search_for_extreme3.vhd \
	$(FEB_SUBMOD_DIR)/feb_frame_assembly.vhd

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

VLOG_FLAGS := -ini $(MODELSIM_INI) -sv -work $(BUILD_DIR)/work $(UVM_DEFINES) +incdir+$(UVM_SRC) +incdir+$(TB_INT_UVM_DIR) +incdir+$(FEB_SUBMOD_DIR)
VCOM_FLAGS := -ini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/work
VCOM_LPM_FLAGS := -ini $(MODELSIM_INI) -2008 -work $(BUILD_DIR)/lpm
VSIM_FLAGS := -ini $(MODELSIM_INI) -L altera_mf -L lpm -voptargs=+acc $(if $(UVM_DPI_LIB),-dpicpppath $(DPI_CPP_PATH) -sv_lib $(UVM_DPI_LIB)) -suppress 19 -suppress 3009

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
		( [ -d $(BUILD_DIR)/altera_mf ] || $(VLIB) altera_mf ) && \
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) lpm  $(BUILD_DIR)/lpm  >/dev/null && \
		$(VMAP) -modelsimini $(MODELSIM_INI) altera_mf $(BUILD_DIR)/altera_mf >/dev/null
	cp $(FEB_SUBMOD_DIR)/dual_port_rom_init.txt $(BUILD_DIR)/dual_port_rom_init.txt
	@$(VCOM) -ini $(MODELSIM_INI) -2008 -work altera_mf $(QUARTUS_SIM_LIB)/altera_mf_components.vhd
	@$(VCOM) -ini $(MODELSIM_INI) -2008 -work altera_mf $(QUARTUS_SIM_LIB)/altera_mf.vhd
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
