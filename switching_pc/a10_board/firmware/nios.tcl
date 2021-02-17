#

source {device.tcl}

source {util/nios_base.tcl}
set_instance_parameter_value ram {memorySize} {0x00080000}
set_instance_parameter_value spi numberOfSlaves 32

source {util/a10_flash1616.tcl}

nios_base.add_clock_source avm_clk 156250000 -clock_export avm_clock -reset_export avm_reset
nios_base.export_avm avm_xcvr 18 0x70100000 -clk avm_clk
