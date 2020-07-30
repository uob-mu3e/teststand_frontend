#include <cstring>
#include <iostream>
#include <iomanip>

#include "MutrigConfig.h"

namespace mutrig {

MutrigConfig::paras_t MutrigConfig::parameters_tdc = {
        make_param("vnd2c_scale",        1, 1),
        make_param("vnd2c_offset",       2, 1),
        make_param("vnd2c",              6, 1),
        make_param("vncntbuffer_scale",  1, 1),
        make_param("vncntbuffer_offset", 2, 1),
        make_param("vncntbuffer",        6, 1),
        make_param("vncnt_scale",        1, 1),
        make_param("vncnt_offset",       2, 1),
        make_param("vncnt",              6, 1),
        make_param("vnpcp_scale",        1, 1),
        make_param("vnpcp_offset",       2, 1),
        make_param("vnpcp",              6, 1),
        make_param("vnvcodelay_scale",   1, 1),
        make_param("vnvcodelay_offset",  2, 1),
        make_param("vnvcodelay",         6, 1),
        make_param("vnvcobuffer_scale",  1, 1),
        make_param("vnvcobuffer_offset", 2, 1),
        make_param("vnvcobuffer",        6, 1),
        make_param("vnhitlogic_scale",   1, 1),
        make_param("vnhitlogic_offset",  2, 1),
        make_param("vnhitlogic",         6, 1),
        make_param("vnpfc_scale",        1, 1),
        make_param("vnpfc_offset",       2, 1),
        make_param("vnpfc",              6, 1),
        make_param("latchbias",          12, 0)
    };

MutrigConfig::paras_t MutrigConfig::parameters_ch = {
        make_param("energy_c_en",       1, 1), //old name: anode_flag
        make_param("energy_r_en",       1, 1), //old name: cathode_flag
        make_param("sswitch",           1, 1),
        make_param("cm_sensing_high_r", 1, 1), //old name: SorD; should be always '0'
        make_param("amon_en_n",         1, 1), //old name: SorD_not; 0: enable amon in the channel
        make_param("edge",              1, 1),
        make_param("edge_cml",          1, 1),
        make_param("cml_sc",            1, 1),
        make_param("dmon_en",           1, 1),
        make_param("dmon_sw",           1, 1),
        make_param("tdctest_n",           1, 1),
        make_param("amonctrl",          3, 1),
        make_param("comp_spi",          2, 1),
        make_param("sipm_sc",           1, 1),
        make_param("sipm",              6, 1),
        make_param("tthresh_sc",        3, 1),
        make_param("tthresh",           6, 1),
        make_param("ampcom_sc",         2, 1),
        make_param("ampcom",            6, 1),
        make_param("inputbias_sc",      1, 1),
        make_param("inputbias",         6, 1),
        make_param("ethresh",           8, 1),
        make_param("pole_sc",           1, 1),
        make_param("pole",              6, 1),
        make_param("cml",               4, 1),
        make_param("delay",             1, 1),
        make_param("pole_en_n",         1, 1), //old name: dac_delay_bit1; 0: DAC_pole on
        make_param("mask",              1, 1)
     };

MutrigConfig::paras_t MutrigConfig::parameters_header = {
        make_param("gen_idle",              1, 1),
        make_param("recv_all",              1, 1),
        make_param("ext_trig_mode",         1, 1), // new
        make_param("ext_trig_endtime_sign", 1, 1), // sign of the external trigger matching window, 1: end time is after the trigger; 0: end time is before the trigger
        make_param("ext_trig_offset",       4, 0), // offset of the external trigger matching window
        make_param("ext_trig_endtime",      4, 0), // end time of external trigger matching window
        make_param("ms_limits",             5, 0),
        make_param("ms_switch_sel",         1, 1),
        make_param("ms_debug",              1, 1),
        make_param("prbs_debug",            1, 1), // new
        make_param("prbs_single",           1, 1), // new
        make_param("short_event_mode",      1, 1), //fast transmission mode
        make_param("pll_setcoarse",         1, 1),
        make_param("pll_envomonitor",       1, 1),
        make_param("disable_coarse",        1, 1)
    };

MutrigConfig::paras_t MutrigConfig::parameters_footer = {
        make_param("amon_en",       1, 1),
        make_param("amon_dac",      8, 1),
        make_param("dmon_1_en",     1, 1),
        make_param("dmon_1_dac",    8, 1),
        make_param("dmon_2_en",     1, 1),
        make_param("dmon_2_dac",    8, 1),
        make_param("lvds_tx_vcm",   8, 1), // new
        make_param("lvds_tx_bias",  6, 1)  // new
    };


MutrigConfig::MutrigConfig() {
    // populate name/offset map

    length_bits = 0;
    // header
    for(const auto& para : parameters_header )
        addPara(para, "");
    for(unsigned int ch = 0; ch < nch; ++ch) {
        for(const auto& para : parameters_ch )
            addPara(para, "_"+std::to_string(ch));
    }
    for(const auto& para : parameters_tdc )
        addPara(para, "");
    for(const auto& para : parameters_footer )
        addPara(para, "");

    // allocate memory for bitpattern
    length = length_bits/8;
    if( length_bits%8 > 0 ) length++;
    length_32bits = length/4;
    if( length%4 > 0 ) length_32bits++;
    bitpattern_r = new uint8_t[length_32bits*4];
    bitpattern_w = new uint8_t[length_32bits*4];
    reset();
}

MutrigConfig::~MutrigConfig() {
    delete[] bitpattern_r;
    delete[] bitpattern_w;
}

void MutrigConfig::Parse_GLOBAL_from_struct(MUTRIG_GLOBAL& mt_g){
    //hard coded in order to avoid macro magic
//    setParameter("", mt_g.n_asics);
//    setParameter("", mt_g.n_channels);
    setParameter("ext_trig_mode", mt_g.ext_trig_mode);
    setParameter("ext_trig_endtime_sign", mt_g.ext_trig_endtime_sign);
    setParameter("ext_trig_offset", mt_g.ext_trig_offset);
    setParameter("ext_trig_endtime", mt_g.ext_trig_endtime);
    setParameter("gen_idle", mt_g.gen_idle);
    setParameter("ms_debug", mt_g.ms_debug);
    setParameter("prbs_debug", mt_g.prbs_debug);
    setParameter("prbs_single", mt_g.prbs_single);
    setParameter("recv_all", mt_g.recv_all);
    setParameter("disable_coarse", mt_g.disable_coarse);
    setParameter("pll_setcoarse", mt_g.pll_setcoarse);
    setParameter("short_event_mode", mt_g.short_event_mode);
    setParameter("pll_envomonitor", mt_g.pll_envomonitor);
}

void MutrigConfig::Parse_TDC_from_struct(MUTRIG_TDC& mt_tdc){
    setParameter("vnpfc", mt_tdc.vnpfc);
    setParameter("vnpfc_offset", mt_tdc.vnpfc_offset);
    setParameter("vnpfc_scale", mt_tdc.vnpfc_scale);
    setParameter("vncnt", mt_tdc.vncnt);
    setParameter("vncnt_offset", mt_tdc.vncnt_offset);
    setParameter("vncnt_scale", mt_tdc.vncnt_scale);
    setParameter("vnvcobuffer", mt_tdc.vnvcobuffer);
    setParameter("vnvcobuffer_offset", mt_tdc.vnvcobuffer_offset);
    setParameter("vnvcobuffer_scale", mt_tdc.vnvcobuffer_scale);
    setParameter("vnd2c", mt_tdc.vnd2c);
    setParameter("vnd2c_offset", mt_tdc.vnd2c_offset);
    setParameter("vnd2c_scale", mt_tdc.vnd2c_scale);
    setParameter("vnpcp", mt_tdc.vnpcp);
    setParameter("vnpcp_offset", mt_tdc.vnpcp_offset);
    setParameter("vnpcp_scale", mt_tdc.vnpcp_scale);
    setParameter("vnhitlogic", mt_tdc.vnhitlogic);
    setParameter("vnhitlogic_offset", mt_tdc.vnhitlogic_offset);
    setParameter("vnhitlogic_scale", mt_tdc.vnhitlogic_scale);
    setParameter("vncntbuffer", mt_tdc.vncntbuffer);
    setParameter("vncntbuffer_offset", mt_tdc.vncntbuffer_offset);
    setParameter("vncntbuffer_scale", mt_tdc.vncntbuffer_scale);
    setParameter("vnvcodelay", mt_tdc.vnvcodelay);
    setParameter("vnvcodelay_offset", mt_tdc.vnvcodelay_offset);
    setParameter("vnvcodelay_scale", mt_tdc.vnvcodelay_scale);
    setParameter("latchbias", mt_tdc.latchbias);
    setParameter("ms_limits", mt_tdc.ms_limits);
    setParameter("ms_switch_sel", mt_tdc.ms_switch_sel);
    setParameter("amon_en", mt_tdc.amon_en);
    setParameter("amon_dac", mt_tdc.amon_dac);
    setParameter("dmon_1_en", mt_tdc.dmon_1_en);
    setParameter("dmon_1_dac", mt_tdc.dmon_1_dac);
    setParameter("dmon_2_en", mt_tdc.dmon_2_en);
    setParameter("dmon_2_dac", mt_tdc.dmon_2_dac);
    setParameter("lvds_tx_vcm", mt_tdc.lvds_tx_vcm);
    setParameter("lvds_tx_bias", mt_tdc.lvds_tx_bias);
}


void MutrigConfig::Parse_CH_from_struct(MUTRIG_CH& mt_ch, int channel){
    setParameter("mask_" + std::to_string(channel), mt_ch.mask);
    setParameter("tthresh_" + std::to_string(channel), mt_ch.tthresh);
    setParameter("tthresh_sc_" + std::to_string(channel), mt_ch.tthresh_sc);
    setParameter("ethresh_" + std::to_string(channel), mt_ch.ethresh);
    setParameter("sipm_" + std::to_string(channel), mt_ch.sipm);
    setParameter("sipm_sc_" + std::to_string(channel), mt_ch.sipm_sc);
    setParameter("inputbias_" + std::to_string(channel), mt_ch.inputbias);
    setParameter("inputbias_sc_" + std::to_string(channel), mt_ch.inputbias_sc);
    setParameter("pole_" + std::to_string(channel), mt_ch.pole);
    setParameter("pole_sc_" + std::to_string(channel), mt_ch.pole_sc);
    setParameter("ampcom_" + std::to_string(channel), mt_ch.ampcom);
    setParameter("ampcom_sc_" + std::to_string(channel), mt_ch.ampcom_sc);
    setParameter("cml_" + std::to_string(channel), mt_ch.cml);
    setParameter("cml_sc_" + std::to_string(channel), mt_ch.cml_sc);
    setParameter("amonctrl_" + std::to_string(channel), mt_ch.amonctrl);
    setParameter("comp_spi_" + std::to_string(channel), mt_ch.comp_spi);
    setParameter("tdctest_n_" + std::to_string(channel), mt_ch.tdctest_n);
    setParameter("sswitch_" + std::to_string(channel), mt_ch.sswitch);
    setParameter("delay_" + std::to_string(channel), mt_ch.delay);
    setParameter("pole_en_n_" + std::to_string(channel), mt_ch.pole_en_n);
    setParameter("energy_c_en_" + std::to_string(channel), mt_ch.energy_c_en);
    setParameter("energy_r_en_" + std::to_string(channel), mt_ch.energy_r_en);
    setParameter("cm_sensing_high_r_" + std::to_string(channel), mt_ch.cm_sensing_high_r);
    setParameter("amon_en_n_" + std::to_string(channel), mt_ch.amon_en_n);
    setParameter("edge_" + std::to_string(channel), mt_ch.edge);
    setParameter("edge_cml_" + std::to_string(channel), mt_ch.edge_cml);
    setParameter("dmon_en_" + std::to_string(channel), mt_ch.dmon_en);
    setParameter("dmon_sw_" + std::to_string(channel), mt_ch.dmon_sw);
}


} // namespace mutrig