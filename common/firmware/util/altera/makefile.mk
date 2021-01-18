#
# author : Alexandr Kozlinskiy
#

ifndef QUARTUS_ROOTDIR
    $(error QUARTUS_ROOTDIR is undefined)
endif

ifeq ($(PREFIX),)
    override PREFIX := .
endif

ifeq ($(SOF),)
    SOF := output_files/top.sof
endif

ifeq ($(NIOS_SOPCINFO),)
    NIOS_SOPCINFO := $(PREFIX)/nios.sopcinfo
endif

BSP_SCRIPT := software/hal_bsp.tcl
SRC_DIR := software/app_src

ifeq ($(BSP_DIR),)
    BSP_DIR := $(PREFIX)/software/hal_bsp
endif

ifeq ($(APP_DIR),)
    APP_DIR := $(PREFIX)/software/app
endif

.PRECIOUS : %.qip %.sip %.qsys %.sopcinfo $(BSP_DIR) $(APP_DIR)

all : $(IPs)

.PRECIOUS : %.qip %.sip
ip_%.qip : ip_%.v
#	qmegawiz -silent OPTIONAL_FILES=NONE ip_$*.v
	qmegawiz -silent ip_$*.v
#	sed -r 's/ +/ /g' -i ip_$*.v
	touch ip_$*.qip

.PRECIOUS : %.qsys
$(PREFIX)/%.qsys : %.tcl
	./util/altera/tcl2qsys.sh $< $@

.PRECIOUS : %.sopcinfo
$(PREFIX)/%.sopcinfo : $(PREFIX)/%.qsys
	./util/altera/qsys-generate.sh $<

.PHONY : flow
flow : $(IPs)
	quartus_sh -t util/altera/flow.tcl top

.PHONY : sof2flash
sof2flash :
	sof2flash --pfl --programmingmode=PS \
        --optionbit=0x00030000 \
        --input="$(SOF)" \
        --output="$(SOF).flash" --offset=0x02B40000
	objcopy -Isrec -Obinary $(SOF).flash $(SOF).bin

.PHONY : pgm
pgm : $(SOF)
	quartus_pgm -m jtag -c $(CABLE) --operation="p;$(SOF)"

.PRECIOUS : $(BSP_DIR)
$(BSP_DIR) : $(BSP_SCRIPT) $(NIOS_SOPCINFO)
	mkdir -p $(BSP_DIR)
	nios2-bsp-create-settings \
	    --type hal --script $(SOPC_KIT_NIOS2)/sdk2/bin/bsp-set-defaults.tcl \
	    --sopc $(NIOS_SOPCINFO) --cpu-name cpu \
	    --bsp-dir $(BSP_DIR) --settings $(BSP_DIR)/settings.bsp --script $(BSP_SCRIPT)

bsp : $(BSP_DIR)

.PRECIOUS : $(APP_DIR)/main.elf
.PHONY : $(APP_DIR)/main.elf
$(APP_DIR)/main.elf : $(SRC_DIR)/* $(BSP_DIR)
	nios2-app-generate-makefile \
	    --set ALT_CFLAGS "-Wextra -Wformat=0 -pedantic -std=c++14" \
	    --bsp-dir $(BSP_DIR) --app-dir $(APP_DIR) --src-dir $(SRC_DIR)
	$(MAKE) -C $(APP_DIR) clean
	$(MAKE) -C $(APP_DIR)
	nios2-elf-objcopy $(APP_DIR)/main.elf -O srec $(APP_DIR)/main.srec
	# generate flash image (srec)
	( cd $(APP_DIR) ; make mem_init_generate )

.PHONY : app
app : $(APP_DIR)/main.elf

.PHONY : app_flash
app_flash :
	nios2-flash-programmer -c $(CABLE) --base=0x0 $(APP_DIR)/main.flash

.PHONY : flash
flash : app_flash
	nios2-flash-programmer -c $(CABLE) --base=0x0 $(SOF).flash

.PHONY : app_upload
app_upload : app
	nios2-gdb-server -c $(CABLE) -r -w 1 -g $(APP_DIR)/main.srec

.PHONY : terminal
terminal :
	nios2-terminal -c $(CABLE)
