#compile mutrig asic files
do ../mutrig_sim_lib/compile_asic.do ~/git-repos-kip/mutrig/units
vcom -2008 -work mutrig_sim ../mutrig_sim_lib/faraday_emu.vhd

vlib work
