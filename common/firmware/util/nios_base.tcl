#
# author : Alexandr Kozlinskiy
#

# clock
add_instance clk clock_source
set_instance_parameter_value clk {clockFrequency} $nios_freq
set_instance_parameter_value clk {resetSynchronousEdges} {DEASSERT}

# cpu
add_instance cpu altera_nios2_gen2
set_instance_parameter_value cpu {impl} {Tiny}
set_instance_parameter_value cpu {resetSlave} {ram.s1}
set_instance_parameter_value cpu {resetOffset} {0x00000000}
set_instance_parameter_value cpu {exceptionSlave} {ram.s1}

# ram
add_instance ram altera_avalon_onchip_memory2
set_instance_parameter_value ram {memorySize} {0x00010000}
set_instance_parameter_value ram {initMemContent} {0}

# jtag master
add_instance jtag_master altera_jtag_avalon_master



add_connection clk.clk cpu.clk
add_connection clk.clk ram.clk1
add_connection clk.clk jtag_master.clk

add_connection clk.clk_reset cpu.reset
add_connection clk.clk_reset ram.reset1
add_connection clk.clk_reset jtag_master.clk_reset

add_connection                 cpu.data_master ram.s1
set_connection_parameter_value cpu.data_master/ram.s1                      baseAddress {0x10000000}
add_connection                 cpu.instruction_master ram.s1
set_connection_parameter_value cpu.instruction_master/ram.s1               baseAddress {0x10000000}
add_connection                 cpu.data_master cpu.debug_mem_slave
set_connection_parameter_value cpu.data_master/cpu.debug_mem_slave         baseAddress {0x70000000}
add_connection                 cpu.instruction_master cpu.debug_mem_slave
set_connection_parameter_value cpu.instruction_master/cpu.debug_mem_slave  baseAddress {0x70000000}



add_connection jtag_master.master ram.s1
add_connection jtag_master.master cpu.debug_mem_slave
add_connection cpu.debug_reset_request cpu.reset
add_connection cpu.debug_reset_request ram.reset1



# exported interfaces
add_interface clk clock sink
set_interface_property clk EXPORT_OF clk.clk_in
add_interface rst reset sink
set_interface_property rst EXPORT_OF clk.clk_in_reset



proc nios_base.connect { name clk reset avalon addr } {
    if { [ string length ${clk} ] > 0 } {
        add_connection clk.clk ${name}.${clk}
    }
    if { [ string length ${reset} ] > 0 } {
        add_connection clk.clk_reset ${name}.${reset}
        add_connection cpu.debug_reset_request ${name}.${reset}
    }
    if { [ string length ${avalon} ] > 0 } {
        add_connection                 cpu.data_master ${name}.${avalon}
        set_connection_parameter_value cpu.data_master/${name}.${avalon} baseAddress ${addr}
    }
}

proc nios_base.add_pio { name width direction addr } {
    add_instance ${name} altera_avalon_pio
    set_instance_parameter_value ${name} {width} ${width}
    set_instance_parameter_value ${name} {direction} ${direction}
    set_instance_parameter_value ${name} {bitModifyingOutReg} {1}

    nios_base.connect ${name} clk reset s1 ${addr}

    add_interface ${name} conduit end
    set_interface_property ${name} EXPORT_OF ${name}.external_connection
}

# uart, timers, i2c, spi
if 1 {
    add_instance sysid altera_avalon_sysid_qsys

    add_instance jtag_uart altera_avalon_jtag_uart

    add_instance timer altera_avalon_timer
    apply_preset timer "Simple periodic interrupt"
    set_instance_parameter_value timer {period} {1}
    set_instance_parameter_value timer {periodUnits} {MSEC}

    add_instance timer_ts altera_avalon_timer
    apply_preset timer_ts "Full-featured"

    add_instance i2c altera_avalon_i2c
    add_instance spi altera_avalon_spi

    nios_base.connect   sysid       clk     reset       control_slave       0x700F0000
    nios_base.connect   jtag_uart   clk     reset       avalon_jtag_slave   0x700F0010
    nios_base.connect   timer       clk     reset       s1                  0x700F0100
    nios_base.connect   timer_ts    clk     reset       s1                  0x700F0140
    nios_base.connect   i2c         clock   reset_sink  csr                 0x700F0200
    nios_base.connect   spi         clk     reset       spi_control_port    0x700F0240

    # IRQ assignments
    foreach { name irq } {
        jtag_uart.irq 3
        timer.irq 0
        i2c.interrupt_sender 10
        spi.irq 11
    } {
        add_connection cpu.irq $name
        set_connection_parameter_value cpu.irq/$name irqNumber $irq
    }

    add_interface i2c conduit end
    set_interface_property i2c EXPORTOF i2c.i2c_serial

    add_interface spi conduit end
    set_interface_property spi EXPORTOF spi.external

    nios_base.add_pio pio 32 Output 0x700F0280
}

#package require cmdline

proc nios_base.export_avm { name baseAddress addressWidth args } {
    set dataWidth 32
    set addressUnits 8
    set readLatency 0
    for { set i 0 } { $i < [ llength $args ] } { incr i } {
        switch -- [ lindex $args $i ] {
            -dataWidth { incr i
                set dataWidth [ lindex $args $i ]
            }
            -addressUnits { incr i
                set addressUnits [ lindex $args $i ]
            }
            -readLatency { incr i
                set readLatency [ lindex $args $i ]
            }
            default {
                send_message "Error" "\[nios_base.export_avm\] invalid argument '[ lindex $args $i ]'"
            }
        }
    }

    add_instance ${name} avalon_proxy
    set_instance_parameter_value ${name} {DATA_WIDTH} ${dataWidth}
    set_instance_parameter_value ${name} {ADDRESS_UNITS} ${addressUnits}
    set_instance_parameter_value ${name} {ADDRESS_WIDTH} ${addressWidth}
    if { ${readLatency} >= 0 } {
        set_instance_parameter_value ${name} {READ_LATENCY} ${readLatency}
    } else {
        set_instance_parameter_value ${name} {READ_LATENCY} 0
        set_instance_parameter_value ${name} {USE_READ_DATA_VALID} true
    }

    add_connection clk.clk       ${name}.clk
    add_connection clk.clk_reset ${name}.reset

    add_connection                 cpu.data_master ${name}.slave
    set_connection_parameter_value cpu.data_master/${name}.slave baseAddress ${baseAddress}

    add_interface ${name} avalon master
    set_interface_property ${name} EXPORT_OF ${name}.master
}
