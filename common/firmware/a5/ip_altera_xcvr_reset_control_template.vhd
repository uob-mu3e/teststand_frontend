-- megafunction wizard: %Transceiver PHY Reset Controller v18.0%
-- GENERATION: XML
-- ip_altera_xcvr_reset_control.vhd


-- Retrieval info: <?xml version="1.0"?>
--<!--
--	Generated by Altera MegaWizard Launcher Utility version 1.0
--	************************************************************
--	THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--	************************************************************
--	Copyright (C) 1991-2020 Altera Corporation
--	Any megafunction design, and related net list (encrypted or decrypted),
--	support information, device programming or simulation file, and any other
--	associated documentation or information provided by Altera or a partner
--	under Altera's Megafunction Partnership Program may be used only to
--	program PLD devices (but not masked PLD devices) from Altera.  Any other
--	use of such megafunction design, net list, support information, device
--	programming or simulation file, or any other related documentation or
--	information is prohibited for any other purpose, including, but not
--	limited to modification, reverse engineering, de-compiling, or use with
--	any other silicon devices, unless such use is explicitly licensed under
--	a separate agreement with Altera or a megafunction partner.  Title to
--	the intellectual property, including patents, copyrights, trademarks,
--	trade secrets, or maskworks, embodied in any such megafunction design,
--	net list, support information, device programming or simulation file, or
--	any other related documentation or information provided by Altera or a
--	megafunction partner, remains with Altera, the megafunction partner, or
--	their respective licensors.  No other licenses, including any licenses
--	needed under any third party's intellectual property, are provided herein.
---->
-- Retrieval info: <instance entity-name="altera_xcvr_reset_control" version="18.0" >
-- Retrieval info: 	<generic name="device_family" value="Arria 10" />
-- Retrieval info: 	<generic name="CHANNELS" value="4" />
-- Retrieval info: 	<generic name="PLLS" value="4" />
-- Retrieval info: 	<generic name="SYS_CLK_IN_MHZ" value="50" />
-- Retrieval info: 	<generic name="SYNCHRONIZE_RESET" value="1" />
-- Retrieval info: 	<generic name="REDUCED_SIM_TIME" value="1" />
-- Retrieval info: 	<generic name="gui_split_interfaces" value="0" />
-- Retrieval info: 	<generic name="TX_PLL_ENABLE" value="1" />
-- Retrieval info: 	<generic name="T_PLL_POWERDOWN" value="1000" />
-- Retrieval info: 	<generic name="SYNCHRONIZE_PLL_RESET" value="0" />
-- Retrieval info: 	<generic name="TX_ENABLE" value="1" />
-- Retrieval info: 	<generic name="TX_PER_CHANNEL" value="1" />
-- Retrieval info: 	<generic name="gui_tx_auto_reset" value="0" />
-- Retrieval info: 	<generic name="T_TX_ANALOGRESET" value="0" />
-- Retrieval info: 	<generic name="T_TX_DIGITALRESET" value="20" />
-- Retrieval info: 	<generic name="T_PLL_LOCK_HYST" value="0" />
-- Retrieval info: 	<generic name="gui_pll_cal_busy" value="0" />
-- Retrieval info: 	<generic name="RX_ENABLE" value="1" />
-- Retrieval info: 	<generic name="RX_PER_CHANNEL" value="1" />
-- Retrieval info: 	<generic name="gui_rx_auto_reset" value="0" />
-- Retrieval info: 	<generic name="T_RX_ANALOGRESET" value="40" />
-- Retrieval info: 	<generic name="T_RX_DIGITALRESET" value="4000" />
-- Retrieval info: </instance>
-- IPFS_FILES : native_reset.vho
-- RELATED_FILES: native_reset.vhd, altera_xcvr_functions.sv, alt_xcvr_resync.sv, altera_xcvr_reset_control.sv, alt_xcvr_reset_counter.sv
