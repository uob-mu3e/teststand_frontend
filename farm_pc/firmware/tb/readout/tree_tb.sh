#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=4us

entity=$(basename "$0" .sh)

../../util/sim.sh "$entity" "$entity.vhd" *.vhd ../../a10/midas_event_builder.vhd ../../a10/stream_merger.vhd ../../a10/time_merger_tree_fifo_64_old.vhd ../../../../common/firmware/s4/ip_ram.vhd ../../../../common/firmware/s4/ip_dcfifo.vhd ../../../../common/firmware/s4/ip_scfifo.vhd ../../../../fe_board/firmware/FEB_common/daq_constants.vhd ../../a10/data_generator_a10.vhd ../../util/util_pkg.vhd ../../util/link_to_fifo.vhd ../../dataflow/dataflow_components.vhd ../../util/linear_shift.vhd ../../a10/time_merger.vhd ../../../../common/firmware/s4/ip_dcfifo_mixed_widths.vhd