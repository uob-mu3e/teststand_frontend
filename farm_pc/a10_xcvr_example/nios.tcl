#

source {device.tcl}

source {util/nios_base.tcl}
set_instance_parameter_value ram {memorySize} {0x00080000}
source {util/a10_flash1616.tcl}

nios_base.export_avm avm_qsfp 14 0x70010000
