#

package require qsys

create_system {nios}
source {device.tcl}

source {util/nios_base.tcl}
set_instance_parameter_value ram {memorySize} {0x00080000}



nios_base.export_avm avm_qsfp 14 0x70010000 -addressUnits 32



save_system {nios.qsys}