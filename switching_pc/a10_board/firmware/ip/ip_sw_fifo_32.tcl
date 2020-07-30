#

package require qsys

set dir0 [ file dirname [ info script ] ]

source [ file join $dir0 "../device.tcl" ]
source [ file join $dir0 "../util/altera_ip.tcl" ]

set name [ file tail [ file rootname [ info script ] ] ]

create_system $name
add_fifo 32 256 -dc -usedw -aclr
save_system [ file join $dir0 "$name.qsys" ]