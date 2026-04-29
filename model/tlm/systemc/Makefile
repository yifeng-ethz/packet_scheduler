SYSTEMC_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR ?= $(SYSTEMC_DIR)/build
QUESTA_HOME ?= /data1/questaone_sim/questasim
QUESTA_MODELSIM_INI ?= $(QUESTA_HOME)/modelsim.ini
MODELSIM_INI := $(BUILD_DIR)/modelsim.ini
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
SCCOM_CPPPATH ?= /usr/bin/g++
SCCOM_PREDEF := $(BUILD_DIR)/predef_macro_gcc120_linux_x86_64.txt

export LM_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export MGLS_LICENSE_FILE := $(ETH_MENTOR_SERVER)
export SALT_LICENSE_SERVER := $(ETH_MENTOR_SERVER)
export QSIM_INI := $(QUESTA_MODELSIM_INI)

VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
SCCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/sccom $(QUESTA_HOME)/linux_x86_64/sccom))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))

SMOKE_SRC := $(SYSTEMC_DIR)/opq_tm_tlm_smoke.cpp

.PHONY: prepare compile link smoke clean

prepare:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && \
		cp $(QUESTA_MODELSIM_INI) $(MODELSIM_INI) && \
		chmod u+w $(MODELSIM_INI) && \
		$(VLIB) work && \
		$(VMAP) -modelsimini $(MODELSIM_INI) work $(BUILD_DIR)/work >/dev/null

compile: prepare
	cd $(BUILD_DIR) && \
		if [ ! -f "$(SCCOM_PREDEF)" ]; then \
			$(SCCOM) -nodebug -sctop top -suppress 94 -ini $(MODELSIM_INI) -work work -cpppath $(SCCOM_CPPPATH) -g -std=c++17 $(SMOKE_SRC) || test -f "$(SCCOM_PREDEF)"; \
		fi
	cd $(BUILD_DIR) && $(SCCOM) -nodebug -sctop top -suppress 94 -ini $(MODELSIM_INI) -work work -cpppath $(SCCOM_CPPPATH) -predefmacrofile $(SCCOM_PREDEF) -g -std=c++17 $(SMOKE_SRC)

link: compile
	cd $(BUILD_DIR) && $(SCCOM) -nodebug -suppress 94 -ini $(MODELSIM_INI) -work work -cpppath $(SCCOM_CPPPATH) -link

smoke: link
	cd $(BUILD_DIR) && $(VSIM) -ini $(MODELSIM_INI) -c top -do "run -all; quit -f" && \
		grep -q "SYSTEMC_TLM_SMOKE_RESULT" transcript

clean:
	rm -rf $(BUILD_DIR)
