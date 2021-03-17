library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use std.textio.all;
use ieee.std_logic_textio.all;

package mupix is
    
    -----------------------------------------------------------------
    -- Things to clean up with the generics
    -----------------------------------------------------------------
    constant NINPUTS                :  integer := 36;
    constant NSORTERINPUTS          :  integer :=  1;
    constant NCHIPS                 :  integer := 12;

    -----------------------------------------------------------------
    -- conflicts between detectorfpga_constants and mupix_constants (to be checked & tested)
    -----------------------------------------------------------------

    constant HITSIZE                :  integer := 32;

    constant TIMESTAMPSIZE          :  integer := 11;

    subtype TSRANGE                 is integer range TIMESTAMPSIZE-1 downto 0;

    constant COARSECOUNTERSIZE      :  integer := 32;

    subtype  COLRANGE               is integer range 23 downto 16;
    subtype  ROWRANGE               is integer range 15 downto 8;

    constant CHIPRANGE              :  integer := 3;

    -----------------------------------------------------------
    -----------------------------------------------------------

    constant BINCOUNTERSIZE         :  integer := 24;
    constant CHARGESIZE_MP10        :  integer := 5;
    constant SLOWTIMESTAMPSIZE      :  integer := 10;

    constant NOTSHITSIZE            :  integer := HITSIZE -TIMESTAMPSIZE;--HITSIZE -TIMESTAMPSIZE-1;
    subtype SLOWTSRANGE             is integer range TIMESTAMPSIZE-1 downto 1;
    subtype NOTSRANGE               is integer range HITSIZE-1 downto TIMESTAMPSIZE;--TIMESTAMPSIZE+1;

    constant HITSORTERBINBITS       :  integer := 4;
    constant H                      :  integer := HITSORTERBINBITS;
    constant HITSORTERADDRSIZE      :  integer := TIMESTAMPSIZE + HITSORTERBINBITS;

    constant BITSPERTSBLOCK         :  integer := 4;
    subtype TSBLOCKRANGE            is integer range TIMESTAMPSIZE-1 downto BITSPERTSBLOCK;
    subtype SLOWTSNONBLOCKRANGE     is integer range BITSPERTSBLOCK-2 downto 0;

    constant COMMANDBITS            :  integer := 20;

    constant COUNTERMEMADDRSIZE     :  integer := 8;
    constant NMEMS                  :  integer := 2**(TIMESTAMPSIZE-COUNTERMEMADDRSIZE-1); -- -1 due to even odd in single memory
    constant COUNTERMEMDATASIZE     :  integer := 10;
    subtype COUNTERMEMSELRANGE      is integer range TIMESTAMPSIZE-1 downto COUNTERMEMADDRSIZE+1;
    subtype SLOWTSCOUNTERMEMSELRANGE is integer range TIMESTAMPSIZE-2 downto COUNTERMEMADDRSIZE;
    subtype COUNTERMEMADDRRANGE     is integer range COUNTERMEMADDRSIZE downto 1;
    subtype SLOWCOUNTERMEMADDRRANGE is integer range COUNTERMEMADDRSIZE-1 downto 0;

    -- Bit positions in the counter fifo of the sorter
    subtype EVENCOUNTERRANGE        is integer range 2*NCHIPS*HITSORTERBINBITS-1 downto 0;
    constant EVENOVERFLOWBIT        :  integer := 2*NCHIPS*HITSORTERBINBITS;
    constant HASEVENBIT             :  integer := 2*NCHIPS*HITSORTERBINBITS+1;
    subtype ODDCOUNTERRANGE         is integer range 2*NCHIPS*HITSORTERBINBITS+HASEVENBIT downto HASEVENBIT+1;
    constant ODDOVERFLOWBIT         :  integer := 2*NCHIPS*HITSORTERBINBITS+HASEVENBIT+1;
    constant HASODDBIT              :  integer := 2*NCHIPS*HITSORTERBINBITS+HASEVENBIT+2;
    subtype TSINFIFORANGE           is integer range 2*NCHIPS*HITSORTERBINBITS+HASEVENBIT+SLOWTIMESTAMPSIZE+2 downto 2*NCHIPS*HITSORTERBINBITS+HASEVENBIT+3;
    subtype TSBLOCKINFIFORANGE      is integer range TSINFIFORANGE'left downto TSINFIFORANGE'left-BITSPERTSBLOCK+1;
    subtype TSINBLOCKINFIFORANGE    is integer range TSINFIFORANGE'right+BITSPERTSBLOCK-2  downto TSINFIFORANGE'right;


    -----------------------------------------------------------
    -- mupix ctrl constants
    -----------------------------------------------------------

    type mp_config_regs_length_t    is array (5 downto 0) of integer;
    constant MP_CONFIG_REGS_LENGTH  : mp_config_regs_length_t := (512, 896, 896, 80, 90, 210);

    type mp_link_order_t    is array (35 downto 0) of integer;
    constant MP_LINK_ORDER  : mp_link_order_t := (33,31,29,35,32,28,34,30,27,26,25,20,24,23,21,22,19,18,15,11,9,17,13,10,16,14,12,5,3,2,6,4,1,8,7,0);



    type ts_array_t                 is array (natural range <>) of std_logic_vector(10 downto 0);
    type row_array_t                is array (natural range <>) of std_logic_vector(7 downto 0);
    type col_array_t                is array (natural range <>) of std_logic_vector(7 downto 0);
    type ch_ID_array_t              is array (natural range <>) of std_logic_vector(5 downto 0);
    type tot_array_t                is array (natural range <>) of std_logic_vector(5 downto 0);

    subtype hit_t is                std_logic_vector(HITSIZE-1 downto 0);
    subtype cnt_t is                std_logic_vector(COARSECOUNTERSIZE-1  downto 0);
    subtype ts_t is                 std_logic_vector(TSRANGE);
    subtype slowts_t                is std_logic_vector(SLOWTIMESTAMPSIZE-1 downto 0);
    subtype nots_t                  is std_logic_vector(NOTSHITSIZE-1 downto 0);
    subtype addr_t                  is std_logic_vector(HITSORTERADDRSIZE-1 downto 0);
    subtype counter_t               is std_logic_vector(HITSORTERBINBITS-1 downto 0);

    constant counter1               :  counter_t := (others => '1');

    type wide_hit_array             is array (NINPUTS-1 downto 0) of hit_t;
    type hit_array                  is array (NCHIPS-1 downto 0) of hit_t;

    type wide_cnt_array             is array (NINPUTS-1 downto 0) of cnt_t;
    type cnt_array                  is array (NCHIPS-1 downto 0) of cnt_t;

    type ts_array                   is array (NCHIPS-1 downto 0) of ts_t;
    type slowts_array               is array (NCHIPS-1 downto 0) of slowts_t;

    type nots_hit_array             is array (NCHIPS-1 downto 0) of nots_t;
    type addr_array                 is array (NCHIPS-1 downto 0) of addr_t;

    type counter_chips              is array (NCHIPS-1 downto 0) of counter_t;
    subtype counter2_chips          is std_logic_vector(2*NCHIPS*HITSORTERBINBITS-1 downto 0);

    type hitcounter_sum3_type is array (NCHIPS/3-1 downto 0) of integer;

    subtype chip_bits_t             is std_logic_vector(NCHIPS-1 downto 0);

    subtype muxhit_t                is std_logic_vector(HITSIZE+1 downto 0);
    type muxhit_array               is array ((NINPUTS/4) downto 0) of muxhit_t;

    subtype byte_t                  is std_logic_vector(7 downto 0);
    type inbyte_array               is array (NINPUTS-1 downto 0) of byte_t;

    type state_type                 is (INIT, START, PRECOUNT, COUNT);

    subtype block_t                 is std_logic_vector(TSBLOCKRANGE);

    subtype command_t               is std_logic_vector(COMMANDBITS-1 downto 0);
    constant COMMAND_HEADER1        :  command_t := X"80000";
    constant COMMAND_HEADER2        :  command_t := X"90000";
    constant COMMAND_SUBHEADER      :  command_t := X"C0000";
    constant COMMAND_FOOTER         :  command_t := X"E0000";

    subtype doublecounter_t         is std_logic_vector(COUNTERMEMDATASIZE-1 downto 0);
    type doublecounter_array        is array (NMEMS-1 downto 0) of doublecounter_t;
    type doublecounter_chiparray    is array (NCHIPS-1 downto 0) of doublecounter_t;
    type alldoublecounter_array     is array (NCHIPS-1 downto 0) of doublecounter_array;

    subtype counteraddr_t           is std_logic_vector(COUNTERMEMADDRSIZE-1 downto 0);
    type counteraddr_array          is array (NMEMS-1 downto 0) of counteraddr_t;
    type counteraddr_chiparray      is array (NCHIPS-1 downto 0) of counteraddr_t;
    type allcounteraddr_array       is array (NCHIPS-1 downto 0) of counteraddr_array;

    type counterwren_array          is array (NMEMS-1 downto 0) of std_logic;
    type allcounterwren_array       is array (NCHIPS-1 downto 0) of counterwren_array;
    subtype countermemsel_t         is std_logic_vector(COUNTERMEMADDRRANGE);
    type reg_array                  is array (NCHIPS-1 downto 0) of work.mudaq.reg32;

end package;