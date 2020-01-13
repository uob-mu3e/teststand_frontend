library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.pcie_components.all;
use work.mudaq_registers.all;

entity top is
port (
    BUTTON              : in    std_logic_vector(3 downto 0);

    HEX0_D              : out   std_logic_vector(6 downto 0);
--    HEX0_DP             : out   std_logic;

    HEX1_D              : out   std_logic_vector(6 downto 0);
--    HEX1_DP             : out   std_logic;

    LED                 : out   std_logic_vector(3 downto 0) := "0000";
    LED_BRACKET         : out   std_logic_vector(3 downto 0) := "0000";

    SMA_CLKOUT          : out std_logic;
    SMA_CLKIN           : in std_logic;

    RS422_DE            : out   std_logic;
    RS422_DIN           : in    std_logic; -- 1.8-V
    RS422_DOUT          : out   std_logic;
--    RS422_RE_n          : out   std_logic;
--    RJ45_LED_L          : out   std_logic;
    RJ45_LED_R          : out   std_logic;

--    refclk2_qr1_p       : in    std_logic; -- 1.5-V PCML, default 125MHz
--    refclk1_qr0_p       : in    std_logic; -- 1.5-V PCML, default 156.25MHz

    -- //////// FAN ////////
    FAN_I2C_SCL         : out   std_logic;
    FAN_I2C_SDA         : inout std_logic;

    -- //////// FLASH ////////
    FLASH_A             : out   std_logic_vector(26 downto 1);
    FLASH_D             : inout std_logic_vector(31 downto 0);
    FLASH_OE_n          : inout std_logic;
    FLASH_WE_n          : out   std_logic;
    FLASH_CE_n          : out   std_logic_vector(1 downto 0);
    FLASH_ADV_n         : out   std_logic;
    FLASH_CLK           : out   std_logic;
    FLASH_RESET_n       : out   std_logic;

    -- //////// POWER ////////
    POWER_MONITOR_I2C_SCL   : out   std_logic;
    POWER_MONITOR_I2C_SDA   : inout std_logic;

    -- //////// TEMP ////////
    TEMP_I2C_SCL        : out   std_logic;
    TEMP_I2C_SDA        : inout std_logic;

    SW : in std_logic_vector(1 downto 0);

--    clkin_50_top        : in    std_logic; -- 2.5V, default 50MHz

    -- //////// Transiver ////////
    QSFPA_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPB_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPC_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPD_TX_p          : out   std_logic_vector(3 downto 0);

    QSFPA_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPB_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPC_RX_p          : in    std_logic_vector(3 downto 0);
    QSFPD_RX_p          : in    std_logic_vector(3 downto 0);

    QSFPA_REFCLK_p      : in    std_logic;
    QSFPB_REFCLK_p      : in    std_logic;
    QSFPC_REFCLK_p      : in    std_logic;
    QSFPD_REFCLK_p      : in    std_logic;

    QSFPA_LP_MODE       : out   std_logic;
    QSFPB_LP_MODE       : out   std_logic;
    QSFPC_LP_MODE       : out   std_logic;
    QSFPD_LP_MODE       : out   std_logic;

    QSFPA_MOD_SEL_n     : out   std_logic;
    QSFPB_MOD_SEL_n     : out   std_logic;
    QSFPC_MOD_SEL_n     : out   std_logic;
    QSFPD_MOD_SEL_n     : out   std_logic;

    QSFPA_RST_n         : out   std_logic;
    QSFPB_RST_n         : out   std_logic;
    QSFPC_RST_n         : out   std_logic;
    QSFPD_RST_n         : out   std_logic;



    -- //////// PCIE ////////
    PCIE_RX_p           : in    std_logic_vector(7 downto 0);
    PCIE_TX_p           : out   std_logic_vector(7 downto 0);
    PCIE_PERST_n        : in    std_logic;
    PCIE_REFCLK_p       : in    std_logic;
    PCIE_SMBCLK         : in    std_logic;
    PCIE_SMBDAT         : inout std_logic;
    PCIE_WAKE_n         : out   std_logic;

    CPU_RESET_n         : in    std_logic;
    CLK_50_B2J          : in    std_logic--;
);
end entity;

architecture rtl of top is

    -- free running clock (used as nios clock)
    signal clk_50 : std_logic;
    signal reset_50_n : std_logic;
    signal clk_50_cnt : unsigned(31 downto 0);

    -- global 125 MHz clock
    signal clk_125 : std_logic;
    signal reset_125_n : std_logic;
    signal clk_125_cnt : unsigned(31 downto 0);

    -- 156.25 MHz data clock (derived from global 125 MHz clock)
    signal clk_156 : std_logic;
    signal reset_156_n : std_logic;

    -- PCIe clock
    signal pcie_clk : std_logic;
    signal pcie_reset_n : std_logic;

    signal nios_clk : std_logic;
    signal nios_reset_n : std_logic;
    signal flash_rst_n : std_logic;
    signal flash_ce_n_i : std_logic;



        constant NLINKS_DATA : integer := 2;
        constant NLINKS_TOTL : integer := 16;

        signal reset : std_logic;
        signal reset_n : std_logic;

        signal resets : std_logic_vector(31 downto 0);
        signal resets_n: std_logic_vector(31 downto 0);
        
        signal resets_fast : std_logic_vector(31 downto 0);
        signal resets_n_fast: std_logic_vector(31 downto 0);

        ------------------ Signal declaration ------------------------
        
        -- pcie read / write regs
        signal writeregs				: reg32array;
        signal writeregs_slow		: reg32array;
        signal regwritten				: std_logic_vector(63 downto 0);
        signal regwritten_fast		: std_logic_vector(63 downto 0);
        signal regwritten_del1		: std_logic_vector(63 downto 0);
        signal regwritten_del2		: std_logic_vector(63 downto 0);
        signal regwritten_del3		: std_logic_vector(63 downto 0);
        signal regwritten_del4		: std_logic_vector(63 downto 0);
        signal pb_in : std_logic_vector(2 downto 0);
        
        signal readregs				: reg32array;
        signal readregs_slow			: reg32array;
        
        -- pcie read / write memory
        signal readmem_writedata 	: std_logic_vector(31 downto 0);
        signal readmem_writeaddr 	: std_logic_vector(63 downto 0);
        signal readmem_writeaddr_finished: std_logic_vector(15 downto 0);
        signal readmem_writeaddr_lowbits : std_logic_vector(15 downto 0);
        signal readmem_wren	 		: std_logic;
        signal readmem_endofevent 	: std_logic;
        signal writememreadaddr 	: std_logic_vector(15 downto 0);
        signal writememreaddata 	: std_logic_vector (31 downto 0);
        
        -- pcie dma
        signal dmamem_writedata 	: std_logic_vector(255 downto 0);
        signal dmamem_wren	 		: std_logic;
        signal dmamem_endofevent 	: std_logic;
        signal dmamemhalffull 		: std_logic;
        signal dmamemhalffull_counter : std_logic_vector(31 downto 0);
        signal dmamemnothalffull_counter : std_logic_vector(31 downto 0);
        signal endofevent_counter : std_logic_vector(31 downto 0);
        signal notendofevent_counter : std_logic_vector(31 downto 0);
        signal dmamemhalffull_tx : std_logic;
        signal sync_chain_halffull : std_logic_vector(1 downto 0);
        
        -- pcie dma2
        signal dma2mem_writedata 	: std_logic_vector(255 downto 0);
        signal dma2mem_wren	 		: std_logic;
        signal dma2mem_endofevent 	: std_logic;
        signal dma2memhalffull 		: std_logic;
        
        -- //pcie fast clock
        signal pcie_fastclk_out		: std_logic;
        
        -- //pcie debug signals
        signal pcie_testout				: std_logic_vector(127 downto 0);
        
        -- Clocksync stuff
        signal clk_sync : std_logic;
        signal clk_last : std_logic;
        
        -- debouncer
        signal push_button0_db : std_logic;
        signal push_button1_db : std_logic;
        signal push_button2_db : std_logic;
        signal push_button3_db : std_logic;

        -- NIOS
        signal i2c_scl_in   : std_logic;
        signal i2c_scl_oe   : std_logic;
        signal i2c_sda_in   : std_logic;
        signal i2c_sda_oe   : std_logic;
        signal flash_tcm_address_out : std_logic_vector(27 downto 0);
        signal wd_rst_n     : std_logic;
        signal cpu_pio_i : std_logic_vector(31 downto 0);
        signal debug_nios : std_logic_vector(31 downto 0);
        signal av_qsfp : work.util.avalon_array_t(3 downto 0);

        -- https://www.altera.com/support/support-resources/knowledge-base/solutions/rd01262015_264.html
        signal ZERO : std_logic := '0';
        attribute keep : boolean;
        attribute keep of ZERO : signal is true;

        -- tranciever ip signals
        signal tx_clk : std_logic_vector(15 downto 0);
        signal rx_clk : std_logic_vector(15 downto 0);
        type fifo_out_array_type is array (3 downto 0) of std_logic_vector(35 downto 0);

        --all signals from QSFP plugs
        signal QSFP_TX : std_logic_vector(15 downto 0);
        signal QSFP_RX : std_logic_vector(15 downto 0);
        --data behind QSFP tranceivers
        type data_array_type is array (NLINKS_TOTL-1 downto 0) of std_logic_vector(31 downto 0);
        type datak_array_type is array (NLINKS_TOTL-1 downto 0) of std_logic_vector(3 downto 0);
        signal rx_data : data_array_type;
--        signal tx_data : data_array_type;
        signal rx_datak : datak_array_type;
--        signal tx_datak : datak_array_type;

	signal rx_data_v : std_logic_vector(NLINKS_TOTL*32-1 downto 0);
        signal rx_datak_v : std_logic_vector(NLINKS_TOTL*4-1 downto 0);
	signal tx_data_v : std_logic_vector(NLINKS_TOTL*32-1 downto 0);
        signal tx_datak_v : std_logic_vector(NLINKS_TOTL*4-1 downto 0);

	type mapping_t is array(natural range <>) of integer;
	--mapping as follows: fiber link_mapping(0)=1 - Fiber QSFPA.1 is mapped to first(0) link
        constant link_mapping : mapping_t(NLINKS_DATA-1 downto 0):=(1,2);
	signal rx_mapped_data_v : std_logic_vector(NLINKS_DATA*32-1 downto 0);
        signal rx_mapped_datak_v : std_logic_vector(NLINKS_DATA*4-1 downto 0);
        signal rx_mapped_linkmask : std_logic_vector(NLINKS_DATA-1  downto 0); --writeregs_slow(FEB_ENABLE_REGISTER_W)(NLINKS_-1 downto 0),

--        signal idle_ch : std_logic_vector(3 downto 0);
--        
--        signal sc_data : data_array_type;
--        signal sc_datak : datak_array_type;
--        signal sc_ready : std_logic_vector(3 downto 0);
--        signal fifo_data : data_array_type;
--        signal fifo_datak : datak_array_type;
--        signal fifo_wren : std_logic_vector(3 downto 0);
--        signal fifo_out : fifo_out_array_type;
--        
--        signal fifo_read : std_logic;
--        signal fifo_empty : std_logic_vector(3 downto 0);
        
        -- Slow Control
        signal mem_data_out : std_logic_vector(63 downto 0);
        signal mem_datak_out : std_logic_vector(7 downto 0);
        signal mem_add_sc : std_logic_vector(15 downto 0);
        signal mem_data_sc : std_logic_vector(31 downto 0);
        signal mem_wen_sc : std_logic;
        
        -- Link test
        signal mem_add_link_test : std_logic_vector(2 downto 0);
        signal mem_data_link_test : std_logic_vector(31 downto 0);
        signal mem_wen_link_test : std_logic;
        
        -- event counter
        signal state_out_eventcounter : std_logic_vector(3 downto 0);
        signal state_out_datagen : std_logic_vector(3 downto 0);
        signal data_pix_generated : std_logic_vector(31 downto 0);
        signal datak_pix_generated : std_logic_vector(3 downto 0);
        signal data_pix_ready : std_logic;
        signal event_length : std_logic_vector(11 downto 0);
        signal dma_data_wren : std_logic;
        signal dma_data : std_logic_vector(255 downto 0);
        signal dma_data_test : std_logic_vector(159 downto 0);
        signal dma_event_data : std_logic_vector(255 downto 0);
        signal dma_wren_cnt : std_logic;
        signal dma_wren_test : std_logic;
        signal dma_end_event_cnt : std_logic;
        signal dma_end_event_test : std_logic;
        signal data_counter : std_logic_vector(32*NLINKS_DATA-1 downto 0);
        signal datak_counter : std_logic_vector(4*NLINKS_DATA-1 downto 0);

begin

    -- 50 MHz oscillator
    clk_50 <= CLK_50_B2J;

    -- generate reset
    e_reset_50_n : entity work.reset_sync
    port map ( o_reset_n => reset_50_n, i_reset_n => CPU_RESET_n, i_clk => clk_50 );

    -- generate 125 MHz clock on SMA output
    -- (can be connected to SMA input as global clock)
    e_pll_125 : component work.cmp.ip_pll_125
    port map (
        outclk_0 => SMA_CLKOUT,
        refclk => clk_50,
        rst => not reset_50_n
    );

    -- 125 MHz global clock (from SMA input)
    e_clk_125 : work.cmp.ip_clk_ctrl
    port map (
        inclk => SMA_CLKIN,
        outclk => clk_125--,
    );

    e_reset_125_n : entity work.reset_sync
    port map ( o_reset_n => reset_125_n, i_reset_n => CPU_RESET_n, i_clk => clk_125 );

    -- 156.25 MHz data clock (from tx pll, reference is 125 MHz global clock)
    clk_156 <= tx_clk(0);

    e_reset_156_n : entity work.reset_sync
    port map ( o_reset_n => reset_156_n, i_reset_n => CPU_RESET_n, i_clk => clk_156 );

--    e_pcie_reset_n : entity work.reset_sync
--    port map ( o_reset_n => pcie_reset_n, i_reset_n => CPU_RESET_n and BUTTON(0), i_clk => pcie_clk );



    -------- Debouncer/seg7 --------

    e_debouncer : entity work.debouncer
    generic map (
        W => 4,
        N => 125 * 10**3 -- 1ms
    )
    port map (
        i_d => BUTTON,
        o_q(0) => push_button0_db,
        o_q(1) => push_button1_db,
        o_q(2) => push_button2_db,
        o_q(3) => push_button3_db,
        i_reset_n => CPU_RESET_n,
        i_clk => clk_50--,
    );



    process(clk_50)
    begin
    if rising_edge(clk_50) then
        clk_50_cnt <= clk_50_cnt + 1;
    end if;
    end process;

    process(clk_125)
    begin
    if rising_edge(clk_125) then
        clk_125_cnt <= clk_125_cnt + 1;
    end if;
    end process;

    -- monitor 50 MHz clock
    e_hex2seg7_50 : entity work.hex2seg7
    port map (
        i_hex => std_logic_vector(clk_50_cnt)(27 downto 24),
        o_seg => HEX0_D--,
    );

    -- monitor 125 MHz external clock
    e_hex2seg7_125 : entity work.hex2seg7
    port map (
        i_hex => std_logic_vector(clk_125_cnt)(27 downto 24),
        o_seg => HEX1_D--,
    );



    -------- NIOS --------

    nios_clk <= clk_50;

    e_nios : work.cmp.nios
    port map (
        clk_156_reset_reset_n           => reset_156_n,
        clk_156_clock_clk               => clk_156,

        avm_qsfpA_address               => av_qsfp(0).address(13 downto 0),
        avm_qsfpA_read                  => av_qsfp(0).read,
        avm_qsfpA_readdata              => av_qsfp(0).readdata,
        avm_qsfpA_write                 => av_qsfp(0).write,
        avm_qsfpA_writedata             => av_qsfp(0).writedata,
        avm_qsfpA_waitrequest           => av_qsfp(0).waitrequest,

        avm_qsfpB_address               => av_qsfp(1).address(13 downto 0),
        avm_qsfpB_read                  => av_qsfp(1).read,
        avm_qsfpB_readdata              => av_qsfp(1).readdata,
        avm_qsfpB_write                 => av_qsfp(1).write,
        avm_qsfpB_writedata             => av_qsfp(1).writedata,
        avm_qsfpB_waitrequest           => av_qsfp(1).waitrequest,

        avm_qsfpC_address               => av_qsfp(2).address(13 downto 0),
        avm_qsfpC_read                  => av_qsfp(2).read,
        avm_qsfpC_readdata              => av_qsfp(2).readdata,
        avm_qsfpC_write                 => av_qsfp(2).write,
        avm_qsfpC_writedata             => av_qsfp(2).writedata,
        avm_qsfpC_waitrequest           => av_qsfp(2).waitrequest,

        avm_qsfpD_address               => av_qsfp(3).address(13 downto 0),
        avm_qsfpD_read                  => av_qsfp(3).read,
        avm_qsfpD_readdata              => av_qsfp(3).readdata,
        avm_qsfpD_write                 => av_qsfp(3).write,
        avm_qsfpD_writedata             => av_qsfp(3).writedata,
        avm_qsfpD_waitrequest           => av_qsfp(3).waitrequest,

        flash_tcm_address_out           => flash_tcm_address_out,
        flash_tcm_data_out              => FLASH_D,
        flash_tcm_read_n_out(0)         => FLASH_OE_n,
        flash_tcm_write_n_out(0)        => FLASH_WE_n,
        flash_tcm_chipselect_n_out(0)   => flash_ce_n_i,

        i2c_sda_in                      => i2c_sda_in,
        i2c_scl_in                      => i2c_scl_in,
        i2c_sda_oe                      => i2c_sda_oe,
        i2c_scl_oe                      => i2c_scl_oe,

        pio_export                      => cpu_pio_i,

        spi_MISO                        => RS422_DIN,
        spi_MOSI                        => RS422_DOUT,
        spi_SCLK                        => RJ45_LED_R,
        spi_SS_n                        => RS422_DE,

        rst_reset_n                     => nios_reset_n,
        clk_clk                         => nios_clk--,
    );

    FLASH_A <= flash_tcm_address_out(27 downto 2);
    FLASH_CE_n <= (flash_ce_n_i, flash_ce_n_i);
    FLASH_ADV_n <= '0';
    FLASH_CLK <= '0';
    FLASH_RESET_n <= flash_rst_n;

    -- generate reset sequence for flash and nios
    e_reset_ctrl : entity work.reset_ctrl
    generic map (
        W => 2,
        N => 125 * 10**5 -- 100ms
    )
    port map (
        rstout_n(1) => flash_rst_n,
        rstout_n(0) => nios_reset_n,
        rst_n => reset_50_n,
        clk => clk_50--,
    );

    watchdog_i : entity work.watchdog
    generic map (
        W => 4,
        N => 125 * 10**6 -- 1s
    )
    port map (
        d           => cpu_pio_i(3 downto 0),
        rstout_n    => wd_rst_n,
        rst_n       => reset_50_n,
        clk         => clk_50--,
    );

    -- monitor nios
    LED(0) <= not cpu_pio_i(7);
    LED(1) <= not nios_reset_n;
    LED(2) <= not flash_rst_n;
    LED(3) <= '0';

    i2c_scl_in <= not i2c_scl_oe;
    FAN_I2C_SCL <= ZERO when i2c_scl_oe = '1' else 'Z';
    TEMP_I2C_SCL <= ZERO when i2c_scl_oe = '1' else 'Z';
    POWER_MONITOR_I2C_SCL <= ZERO when i2c_scl_oe = '1' else 'Z';

    i2c_sda_in <=
        FAN_I2C_SDA and
        TEMP_I2C_SDA and
        POWER_MONITOR_I2C_SDA and
        '1';
    FAN_I2C_SDA <= ZERO when i2c_sda_oe = '1' else 'Z';
    TEMP_I2C_SDA <= ZERO when i2c_sda_oe = '1' else 'Z';
    POWER_MONITOR_I2C_SDA <= ZERO when i2c_sda_oe = '1' else 'Z';



    -------- Receiving Data and word aligning --------

    QSFPA_LP_MODE <= '0';
    QSFPB_LP_MODE <= '0';
    QSFPC_LP_MODE <= '0';
    QSFPD_LP_MODE <= '0';

    QSFPA_MOD_SEL_n <= '1';
    QSFPB_MOD_SEL_n <= '1';
    QSFPC_MOD_SEL_n <= '1';
    QSFPD_MOD_SEL_n <= '1';

    QSFPA_RST_n <= '1';
    QSFPB_RST_n <= '1';
    QSFPC_RST_n <= '1';
    QSFPD_RST_n <= '1';

    --mapping of qsfp signals
    QSFPA_TX_p <= QSFP_TX(3 downto 0);
    QSFPB_TX_p <= QSFP_TX(7 downto 4);
    QSFPC_TX_p <= QSFP_TX(11 downto 8);
    QSFPD_TX_p <= QSFP_TX(15 downto 12);

    QSFP_RX(3 downto 0)   <= QSFPA_RX_p;
    QSFP_RX(7 downto 4)   <= QSFPB_RX_p;
    QSFP_RX(11 downto 8)  <= QSFPC_RX_p;
    QSFP_RX(15 downto 12) <= QSFPD_RX_p;

    gen_qsfp : for i in 0 to 3 generate
    e_qsfp : entity work.xcvr_a10
    generic map (
        NUMBER_OF_CHANNELS_g => 4--,
    )
    port map (
        i_tx_data   => tx_data_v(4*32*(i+1)-1 downto 4*32*i),
        i_tx_datak  => tx_datak_v(4*4*(i+1)-1 downto 4*4*i),

        o_rx_data   => rx_data_v(4*32*(i+1)-1 downto 4*32*i),
        o_rx_datak  => rx_datak_v(4*4*(i+1)-1 downto 4*4*i),

        o_tx_clkout => tx_clk(4*(i+1)-1 downto 4*i),
        i_tx_clkin  => (others => clk_156),
        o_rx_clkout => open,--rx_clk,
        i_rx_clkin  => (others => clk_156),

        o_tx_serial => QSFP_TX(4*(i+1)-1 downto 4*i),
        i_rx_serial => QSFP_RX(4*(i+1)-1 downto 4*i),

        i_pll_clk   => clk_125,
        i_cdr_clk   => clk_125,

        i_avs_address       => av_qsfp(i).address(13 downto 0),
        i_avs_read          => av_qsfp(i).read,
        o_avs_readdata      => av_qsfp(i).readdata,
        i_avs_write         => av_qsfp(i).write,
        i_avs_writedata     => av_qsfp(i).writedata,
        o_avs_waitrequest   => av_qsfp(i).waitrequest,

        i_reset     => not reset_156_n,
        i_clk       => clk_156--,
    );
    end generate;
    --assign vector types to array types for qsfp rx signals (used by link observer module)
    gen_rx_data : for i in 0 to NLINKS_TOTL-1 generate
        rx_data(i) <= rx_data_v(32*(i+1)-1 downto 32*i);
        rx_datak(i) <= rx_datak_v(4*(i+1)-1 downto 4*i);
    end generate;

    --assign long vectors for used fibers. Wired to run_control, sc, data receivers
    g_assign_usedlinks: for i in NLINKS_DATA-1 downto 0 generate
       rx_mapped_data_v(32*(i+1)-1 downto 32*i) <= rx_data_v(32*(link_mapping(i)+1)-1 downto 32*link_mapping(i));
       rx_mapped_datak_v(4*(i+1)-1 downto  4*i) <= rx_datak_v(4*(link_mapping(i)+1)-1 downto  4*link_mapping(i));
       rx_mapped_linkmask(i) <= writeregs_slow(FEB_ENABLE_REGISTER_W)(link_mapping(i));
    end generate;


    -------- MIDAS RUN control --------

    e_run_control : entity work.run_control
    generic map (
        N_LINKS_g                           => NLINKS_TOTL--,
    )
    port map (
        i_reset_ack_seen_n                  => resets_n(RESET_BIT_RUN_START_ACK),
        i_reset_run_end_n                   => resets_n(RESET_BIT_RUN_END_ACK),
        i_buffers_empty                     => (others => '1'), -- TODO: connect buffers emtpy from dma here
        i_aligned                           => (others => '1'),
        i_data                              => rx_data_v,
        i_datak                             => rx_datak_v,
        i_link_enable                       => writeregs_slow(FEB_ENABLE_REGISTER_W),
        i_addr                              => writeregs_slow(RUN_NR_ADDR_REGISTER_W), -- ask for run number of FEB with this addr.
        i_run_number                        => writeregs_slow(RUN_NR_REGISTER_W)(23 downto 0),
        o_run_number                        => readregs_slow(RUN_NR_REGISTER_R), -- run number of i_addr
        o_runNr_ack                         => readregs_slow(RUN_NR_ACK_REGISTER_R), -- which FEBs have responded with run number in i_run_number
        o_run_stop_ack                      => readregs_slow(RUN_STOP_ACK_REGISTER_R),
        i_clk                               => clk_156--,
    );

    -------- Event Builder --------

    e_data_gen : entity work.data_generator_a10
    port map (
        reset               => resets(RESET_BIT_DATAGEN),
        enable_pix          => writeregs_slow(DATAGENERATOR_REGISTER_W)(DATAGENERATOR_BIT_ENABLE_PIXEL),
        i_dma_half_full     => dmamemhalffull_tx,
        random_seed         => (others => '1'),
        data_pix_generated  => data_pix_generated,
        datak_pix_generated => datak_pix_generated,
        data_pix_ready      => data_pix_ready,
        start_global_time   => (others => '0'),
        slow_down           => writeregs_slow(DMA_SLOW_DOWN_REGISTER_W),
        state_out           => state_out_datagen,
        clk                 => clk_156--,
    );
    
    -- sync halffull 2 flip-flops
    sync_halffull : process(clk_156, reset_156_n)
    begin
    if ( reset_156_n = '0' ) then
        sync_chain_halffull <= (others => '0');
    elsif rising_edge(clk_156) then
        sync_chain_halffull <= sync_chain_halffull(sync_chain_halffull'high-1 downto 0) & dmamemhalffull;
    end if;
    end process;

    dmamemhalffull_tx <= sync_chain_halffull(sync_chain_halffull'high);

    --process(clk_156, reset_156_n)
    --begin
    --if ( reset_156_n = '0' ) then
    --    data_counter    <= (others => '0');
    --    datak_counter   <= (others => '0');
    --elsif rising_edge(clk_156) then
    --    if (writeregs_slow(DATAGENERATOR_REGISTER_W)(DATAGENERATOR_BIT_ENABLE_PIXEL) = '1') then
    --        for i in 0 to NLINKS_DATA-1 loop
    --           data_counter(32*(i+1)-1 downto 32*i)    <= data_pix_generated;
    --           datak_counter(4*(i+1)-1 downto 4*i)    <= datak_pix_generated;
    --        end loop;
    --    else
    --        data_counter    <=rx_mapped_data_v;
    --        datak_counter   <=rx_mapped_datak_v;
    --    end if;
    --end if;
    --end process;
    --
    --e_midas_event_builder : entity work.midas_event_builder
    --    generic map (
    --        NLINKS => NLINKS_DATA--;
    --    )
    --    port map(
    --        i_clk_data => clk_156,
    --        i_clk_dma  => pcie_fastclk_out,
    --        i_reset_data_n  => resets_n(RESET_BIT_EVENT_COUNTER),
    --        i_reset_dma_n  => resets_n_fast(RESET_BIT_EVENT_COUNTER),
    --        i_rx_data  => data_counter,
    --        i_rx_datak => datak_counter,
    --        i_wen_reg  => writeregs(DMA_REGISTER_W)(DMA_BIT_ENABLE),
    --        i_link_mask => rx_mapped_linkmask, --writeregs_slow(FEB_ENABLE_REGISTER_W)(NLINKS_-1 downto 0),
    --        o_event_wren => dma_wren_cnt,
    --        o_endofevent => dma_end_event_cnt,
    --        o_event_data => dma_event_data,
    --        o_state_out => state_out_eventcounter--,
    --);
    
    dma_data <= (others =>'0');--dma_event_data;
    dma_data_wren <= '0';--dma_wren_cnt;
    dmamem_endofevent <= '0';--dma_end_event_cnt;
    
    -------- Slow Control --------
    
    e_master : work.sc_master
    generic map (
        NLINKS => NLINKS_TOTL
    )
    port map (
        reset_n         => resets_n(RESET_BIT_SC_MASTER),
        enable          => '1',
        mem_data_in     => writememreaddata,
        mem_addr        => writememreadaddr,
        mem_data_out    => tx_data_v,
        mem_data_out_k  => tx_datak_v,
        done            => open,
        stateout        => open,
        clk             => clk_156--,
    );
    
    e_slave : work.sc_slave
    generic map (
        NLINKS => NLINKS_TOTL
    )
    port map (
        reset_n                 => resets_n(RESET_BIT_SC_SLAVE),
        i_link_enable           => writeregs_slow(FEB_ENABLE_REGISTER_W)(NLINKS_TOTL-1 downto 0),
        link_data_in            => rx_data_v,
        link_data_in_k          => rx_datak_v,
        mem_addr_out            => mem_add_sc,
        mem_addr_finished_out   => readmem_writeaddr_finished,
        mem_data_out            => mem_data_sc,
        mem_wren                => mem_wen_sc,
        stateout                => LED_BRACKET,
        clk                     => clk_156--,
    );
    
    -------- Link Test --------
    
    e_link_observer : entity work.link_observer
    generic map (
        g_m     => 32,
        g_poly  => "10000000001000000000000000000110"
    )
    port map (
        reset_n     => resets_n(RESET_BIT_LINK_TEST),
        rx_data     => rx_data(1),
        rx_datak    => rx_datak(1),
        mem_add     => mem_add_link_test,
        mem_data    => mem_data_link_test,
        mem_wen     => mem_wen_link_test,
        clk         => clk_156--,
    );

    process(clk_156, reset_156_n)
    begin
    if ( reset_156_n = '0' ) then
        readmem_writeaddr <= (others => '0');
        readmem_writedata <= (others => '0');
        readmem_wren <= '0';
    elsif rising_edge(clk_156) then
        readmem_writeaddr <= (others => '0');
        if (writeregs_slow(LINK_TEST_REGISTER_W)(LINK_TEST_BIT_ENABLE) = '1') then
            readmem_writeaddr(2 downto 0)   <= mem_add_link_test;
            readmem_writedata               <= mem_data_link_test;
            readmem_wren                    <= mem_wen_link_test;
        else
            readmem_writeaddr(15 downto 0)  <= mem_add_sc;
            readmem_writedata               <= mem_data_sc;
            readmem_wren                    <= mem_wen_sc;
        end if;
    end if;
    end process;

    -------- PCIe --------

    -- reset regs
    e_reset_logic : entity work.reset_logic
    port map (
        rst_n                   => push_button0_db,
        reset_register          => writeregs_slow(RESET_REGISTER_W),
        resets                  => resets,
        resets_n                => resets_n,
        clk                     => clk_156--,
    );
    
    e_reset_logic_fast : entity work.reset_logic
    port map (
        rst_n                   => push_button0_db,
        reset_register          => writeregs(RESET_REGISTER_W),
        resets                  => resets_fast,
        resets_n                => resets_n_fast,
        clk                     => pcie_fastclk_out--,
    );

    e_version_reg : entity work.version_reg
    port map (
        data_out  => readregs_slow(VERSION_REGISTER_R)(27 downto 0)
    );

    --Sync read regs from slow (156.25 MHz) to fast (250 MHz) clock
    process(pcie_fastclk_out)
    begin
    if rising_edge(pcie_fastclk_out) then
        clk_sync <= clk_156;
        clk_last <= clk_sync;
        
        if(clk_sync = '1' and clk_last = '0') then
            readregs(PLL_REGISTER_R)                <= readregs_slow(PLL_REGISTER_R);
            readregs(VERSION_REGISTER_R)            <= readregs_slow(VERSION_REGISTER_R);
            readregs(RUN_NR_REGISTER_R)             <= readregs_slow(RUN_NR_REGISTER_R);
            readregs(RUN_NR_ACK_REGISTER_R)         <= readregs_slow(RUN_NR_ACK_REGISTER_R);
            readregs(RUN_STOP_ACK_REGISTER_R)       <= readregs_slow(RUN_STOP_ACK_REGISTER_R);
            readregs(MEM_WRITEADDR_HIGH_REGISTER_R) <= (others => '0');
            readregs(MEM_WRITEADDR_LOW_REGISTER_R)  <= (X"0000" & readmem_writeaddr_finished);
        end if;
        
        readregs(DMA_STATUS_R)(DMA_DATA_WEN)        <= dma_data_wren;
        readregs(DMA_HALFFUL_REGISTER_R)            <= dmamemhalffull_counter;
        readregs(DMA_NOTHALFFUL_REGISTER_R)         <= dmamemnothalffull_counter;
        readregs(DMA_ENDEVENT_REGISTER_R)           <= endofevent_counter;
        readregs(DMA_NOTENDEVENT_REGISTER_R)        <= notendofevent_counter;
    end if;
    end process;

    -- DMA status stuff
    e_dma_evaluation : entity work.dma_evaluation
    port map (
        reset_n						=> resets_n_fast(RESET_BIT_DMA_EVAL),
        dmamemhalffull				=> dmamemhalffull,
        dmamem_endofevent			=> dmamem_endofevent,
        halffull_counter			=> dmamemhalffull_counter,
        nothalffull_counter		=> dmamemnothalffull_counter,
        endofevent_counter		=> endofevent_counter,
        notendofevent_counter	=> notendofevent_counter,
        clk                     => pcie_fastclk_out--,
    );
       
    -- Prolong regwritten signals for 156.25 MHz clock
    -- we just delay the fast signal so the slow clock will see it
    process(pcie_fastclk_out)
    begin
    if rising_edge(pcie_fastclk_out) then
        regwritten_del1 <= regwritten_fast;
        regwritten_del2 <= regwritten_del1;
        regwritten_del3 <= regwritten_del2;
        regwritten_del4 <= regwritten_del3;
        for I in 63 downto 0 loop
            if(regwritten_fast(I) = '1' or
                regwritten_del1(I) = '1' or
                regwritten_del2(I) = '1' or
                regwritten_del3(I) = '1' or
                regwritten_del4(I) = '1')
                then
                regwritten(I)   <= '1';
            else
            regwritten(I)       <= '0';
            end if;
        end loop;
    end if;
    end process;

    process(clk_156)
    begin
    if rising_edge(clk_156) then
        for I in 63 downto 0 loop
            if(regwritten(I) = '1') then
                writeregs_slow(I) <= writeregs(I);
            end if;
        end loop;
    end if;
    end process;

    readmem_writeaddr_lowbits   <= readmem_writeaddr(15 downto 0);
    pb_in                       <= push_button0_db & push_button1_db & push_button2_db;

    e_pcie_block : entity work.pcie_block
    generic map (
        DMAMEMWRITEADDRSIZE     => 11,
        DMAMEMREADADDRSIZE      => 11,
        DMAMEMWRITEWIDTH        => 256
    )
    port map (
        local_rstn              => '1',
        appl_rstn               => '1',
        refclk                  => PCIE_REFCLK_p,
        pcie_fastclk_out        => pcie_fastclk_out,
        
        --//PCI-Express--------------------------//25 pins //--------------------------
        pcie_rx_p               => PCIE_RX_p,
        pcie_tx_p               => PCIE_TX_p,
        pcie_refclk_p           => PCIE_REFCLK_p,
        pcie_led_g2             => open,
        pcie_led_x1             => open,
        pcie_led_x4             => open,
        pcie_led_x8             => open,
        pcie_perstn             => PCIE_PERST_n,
        pcie_smbclk             => PCIE_SMBCLK,
        pcie_smbdat             => PCIE_SMBDAT,
        pcie_waken              => PCIE_WAKE_n,
        
        -- LEDs
        alive_led               => open,
        comp_led                => open,
        L0_led                  => open,
        
        -- pcie registers (write / read register, readonly, read write, in tools/dmatest/rw) -Sync read regs
        writeregs               => writeregs,
        regwritten              => regwritten_fast,
        readregs                => readregs,

        -- pcie writeable memory
        writememclk             => clk_156,
        writememreadaddr        => writememreadaddr,
        writememreaddata        => writememreaddata,

        -- pcie readable memory
        readmem_data            => readmem_writedata,
        readmem_addr            => readmem_writeaddr_lowbits,
        readmemclk              => clk_156,
        readmem_wren            => readmem_wren,
        readmem_endofevent      => readmem_endofevent,
        
        -- dma memory
        dma_data                => dma_data,
        dmamemclk               => pcie_fastclk_out,
        dmamem_wren             => dma_data_wren,
        dmamem_endofevent       => dmamem_endofevent,
        dmamemhalffull          => dmamemhalffull,
        
        -- dma memory
        dma2_data               => dma2mem_writedata,
        dma2memclk              => pcie_fastclk_out,
        dma2mem_wren            => dma2mem_wren,
        dma2mem_endofevent      => dma2mem_endofevent,
        dma2memhalffull         => dma2memhalffull,
        
        -- test ports
        testout                 => pcie_testout,
        testout_ena             => open,
        pb_in                   => pb_in,
        inaddr32_r              => readregs(inaddr32_r),
        inaddr32_w              => readregs(inaddr32_w)--,
    );

end architecture;
