ghdl -a --ieee=synopsys -fexplicit linear_shift.vhd data_generator_a10_tb.vhd ip_ram.vhd fifo.vhd readout_tb.vhd
ghdl -e --ieee=synopsys -fexplicit readout_tb
ghdl -r readout_tb --stop-time=2000ns --vcd=out.vcd
rm *.o *.cf readout_tb
