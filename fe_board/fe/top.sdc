#

# clocks

create_clock -period "125 MHz" [ get_ports clk_aux ]
create_clock -period "156.25 MHz" [ get_ports qsfp_pll_clk ]

# set rx_clk of the reset to a 50% phase shift relative to clk_aux   (rising 4.000, falling 8.000)
create_clock -name {pod_pll_clk} -period 8.000 -waveform {4.000 8.000} [get_ports pod_pll_clk ]


derive_pll_clocks -create_base_clocks
derive_clock_uncertainty



#set_false_path -to [ get_ports {LED[*]} ]
