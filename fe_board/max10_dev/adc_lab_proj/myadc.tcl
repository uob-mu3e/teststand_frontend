# qsys scripting (.tcl) file for myadc
package require qsys 16.0

create_system {myadc}

set_project_property DEVICE_FAMILY {MAX 10}
set_project_property DEVICE {10M08SAE144C8GES}
set_project_property HIDE_FROM_IP_CATALOG {true}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance modular_adc_0 altera_modular_adc 18.0
set_instance_parameter_value modular_adc_0 {CORE_VAR} {3}
set_instance_parameter_value modular_adc_0 {ENABLE_DEBUG} {0}
set_instance_parameter_value modular_adc_0 {MONITOR_COUNT_WIDTH} {12}
set_instance_parameter_value modular_adc_0 {clkdiv} {2}
set_instance_parameter_value modular_adc_0 {en_thmax_ch0} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch1} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch10} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch11} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch12} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch13} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch14} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch15} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch16} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch2} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch3} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch4} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch5} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch6} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch7} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch8} {0}
set_instance_parameter_value modular_adc_0 {en_thmax_ch9} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch0} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch1} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch10} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch11} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch12} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch13} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch14} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch15} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch16} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch2} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch3} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch4} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch5} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch6} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch7} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch8} {0}
set_instance_parameter_value modular_adc_0 {en_thmin_ch9} {0}
set_instance_parameter_value modular_adc_0 {en_tsd_max} {0}
set_instance_parameter_value modular_adc_0 {en_tsd_min} {0}
set_instance_parameter_value modular_adc_0 {enable_usr_sim} {0}
set_instance_parameter_value modular_adc_0 {external_vref} {2.5}
set_instance_parameter_value modular_adc_0 {int_vref_vr} {3.0}
set_instance_parameter_value modular_adc_0 {ip_is_for_which_adc} {1}
set_instance_parameter_value modular_adc_0 {prescaler_ch16} {0}
set_instance_parameter_value modular_adc_0 {prescaler_ch8} {0}
set_instance_parameter_value modular_adc_0 {refsel} {0}
set_instance_parameter_value modular_adc_0 {sample_rate} {0}
set_instance_parameter_value modular_adc_0 {seq_order_length} {8}
set_instance_parameter_value modular_adc_0 {seq_order_slot_1} {17}
set_instance_parameter_value modular_adc_0 {seq_order_slot_10} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_11} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_12} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_13} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_14} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_15} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_16} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_17} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_18} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_19} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_2} {1}
set_instance_parameter_value modular_adc_0 {seq_order_slot_20} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_21} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_22} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_23} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_24} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_25} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_26} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_27} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_28} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_29} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_3} {2}
set_instance_parameter_value modular_adc_0 {seq_order_slot_30} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_31} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_32} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_33} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_34} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_35} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_36} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_37} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_38} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_39} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_4} {3}
set_instance_parameter_value modular_adc_0 {seq_order_slot_40} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_41} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_42} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_43} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_44} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_45} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_46} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_47} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_48} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_49} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_5} {4}
set_instance_parameter_value modular_adc_0 {seq_order_slot_50} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_51} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_52} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_53} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_54} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_55} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_56} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_57} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_58} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_59} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_6} {5}
set_instance_parameter_value modular_adc_0 {seq_order_slot_60} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_61} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_62} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_63} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_64} {30}
set_instance_parameter_value modular_adc_0 {seq_order_slot_7} {6}
set_instance_parameter_value modular_adc_0 {seq_order_slot_8} {7}
set_instance_parameter_value modular_adc_0 {seq_order_slot_9} {30}
set_instance_parameter_value modular_adc_0 {simfilename_ch0} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch1} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch10} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch11} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch12} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch13} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch14} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch15} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch16} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch2} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch3} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch4} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch5} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch6} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch7} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch8} {}
set_instance_parameter_value modular_adc_0 {simfilename_ch9} {}
set_instance_parameter_value modular_adc_0 {thmax_ch0} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch1} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch10} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch11} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch12} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch13} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch14} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch15} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch16} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch2} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch3} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch4} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch5} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch6} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch7} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch8} {0.0}
set_instance_parameter_value modular_adc_0 {thmax_ch9} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch0} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch1} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch10} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch11} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch12} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch13} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch14} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch15} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch16} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch2} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch3} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch4} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch5} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch6} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch7} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch8} {0.0}
set_instance_parameter_value modular_adc_0 {thmin_ch9} {0.0}
set_instance_parameter_value modular_adc_0 {tsclksel} {1}
set_instance_parameter_value modular_adc_0 {tsd_max} {125}
set_instance_parameter_value modular_adc_0 {tsd_min} {0}
set_instance_parameter_value modular_adc_0 {use_ch0} {0}
set_instance_parameter_value modular_adc_0 {use_ch1} {1}
set_instance_parameter_value modular_adc_0 {use_ch10} {0}
set_instance_parameter_value modular_adc_0 {use_ch11} {0}
set_instance_parameter_value modular_adc_0 {use_ch12} {0}
set_instance_parameter_value modular_adc_0 {use_ch13} {0}
set_instance_parameter_value modular_adc_0 {use_ch14} {0}
set_instance_parameter_value modular_adc_0 {use_ch15} {0}
set_instance_parameter_value modular_adc_0 {use_ch16} {0}
set_instance_parameter_value modular_adc_0 {use_ch2} {1}
set_instance_parameter_value modular_adc_0 {use_ch3} {1}
set_instance_parameter_value modular_adc_0 {use_ch4} {1}
set_instance_parameter_value modular_adc_0 {use_ch5} {1}
set_instance_parameter_value modular_adc_0 {use_ch6} {1}
set_instance_parameter_value modular_adc_0 {use_ch7} {1}
set_instance_parameter_value modular_adc_0 {use_ch8} {1}
set_instance_parameter_value modular_adc_0 {use_ch9} {0}
set_instance_parameter_value modular_adc_0 {use_tsd} {1}

# exported interfaces
set_instance_property modular_adc_0 AUTO_EXPORT {true}

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}

save_system {myadc.qsys}
