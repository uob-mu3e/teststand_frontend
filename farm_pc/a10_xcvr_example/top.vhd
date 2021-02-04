library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
port (
    LED             : out   std_logic_vector(3 downto 0);

    FLASH_A         : out   std_logic_vector(26 downto 1);
    FLASH_D         : inout std_logic_vector(31 downto 0);
    FLASH_OE_n      : inout std_logic;
    FLASH_WE_n      : out   std_logic;
    FLASH_CE_n      : out   std_logic_vector(1 downto 0);
    FLASH_ADV_n     : out   std_logic;
    FLASH_CLK       : out   std_logic;
    FLASH_RESET_n   : out   std_logic;

    FAN_I2C_SCL             : inout std_logic;
    FAN_I2C_SDA             : inout std_logic;
    POWER_MONITOR_I2C_SCL   : inout std_logic;
    POWER_MONITOR_I2C_SDA   : inout std_logic;
    TEMP_I2C_SCL            : inout std_logic;
    TEMP_I2C_SDA            : inout std_logic;

--    QSFPA_INTERRUPT_n   : in    std_logic;
    QSFPA_LP_MODE       : out   std_logic;
--    QSFPA_MOD_PRS_n     : in    std_logic;
    QSFPA_MOD_SEL_n     : out   std_logic;
    QSFPA_REFCLK_p      : in    std_logic;
    QSFPA_RST_n         : out   std_logic;
--    QSFPA_SCL           : out   std_logic;
--    QSFPA_SDA           : inout std_logic;
    QSFPA_TX_p          : out   std_logic_vector(3 downto 0);
    QSFPA_RX_p          : in    std_logic_vector(3 downto 0);

    SMA_CLKIN       : in    std_logic;
    SMA_CLKOUT      : out   std_logic;

    CPU_RESET_n     : in    std_logic;
    CLK_50_B2J      : in    std_logic--;
);
end entity;

architecture rtl of top is

    signal nios_i2c_scl     : std_logic;
    signal nios_i2c_scl_oe  : std_logic;
    signal nios_i2c_sda     : std_logic;
    signal nios_i2c_sda_oe  : std_logic;
    signal nios_i2c_ss_n    : std_logic_vector(31 downto 0);

    signal nios_clk      : std_logic;
    signal nios_rst_n    : std_logic;
    signal flash_rst_n  : std_logic;

    signal refclk_125   : std_logic;

    signal wd_rst_n     : std_logic;

    signal nios_pio_i : std_logic_vector(31 downto 0);

    signal flash_ce_n_i : std_logic;

    signal av_qsfp : work.util.avalon_t;

begin

    e_iopll_125 : component work.cmp.ip_iopll_125
    port map (
        refclk => CLK_50_B2J,
        outclk_0 => SMA_CLKOUT,
        rst => not CPU_RESET_n--,
    );

    -- SMA input -> refclk_125
    e_clkctrl : component work.cmp.ip_clkctrl
    port map (
        inclk => SMA_CLKIN,
        outclk => refclk_125--,
    );

    e_nios_clk_hz : entity work.clkdiv
    generic map ( P => 125000000 )
    port map (
        o_clk => LED(0),
        i_reset_n => CPU_RESET_n,
        i_clk => refclk_125--,
    );



    nios_clk <= refclk_125;

    -- generate reset sequence for flash and nios
    i_reset_ctrl : entity work.reset_ctrl
    generic map (
        W => 2,
        N => 125 * 10**5 -- 100ms
    )
    port map (
        rstout_n(1) => flash_rst_n,
        rstout_n(0) => nios_rst_n,

        rst_n => CPU_RESET_n and wd_rst_n,
        clk => nios_clk--,
    );
    LED(1) <= not flash_rst_n;
    LED(2) <= not nios_rst_n;

    watchdog_i : entity work.watchdog
    generic map (
        W => 4,
        N => 125 * 10**6 -- 1s
    )
    port map (
        d => nios_pio_i(3 downto 0),

        rstout_n => wd_rst_n,

        rst_n => CPU_RESET_n,
        clk => nios_clk--,
    );

    LED(3) <= nios_pio_i(7);



    i_nios : component work.cmp.nios
    port map (
        avm_qsfp_address        => av_qsfp.address(13 downto 0),
        avm_qsfp_read           => av_qsfp.read,
        avm_qsfp_readdata       => av_qsfp.readdata,
        avm_qsfp_write          => av_qsfp.write,
        avm_qsfp_writedata      => av_qsfp.writedata,
        avm_qsfp_waitrequest    => av_qsfp.waitrequest,

        flash_tcm_address_out(27 downto 2) => FLASH_A,
        flash_tcm_data_out => FLASH_D,
        flash_tcm_read_n_out(0) => FLASH_OE_n,
        flash_tcm_write_n_out(0) => FLASH_WE_n,
        flash_tcm_chipselect_n_out(0) => flash_ce_n_i,

        i2c_scl_in      => nios_i2c_scl,
        i2c_scl_oe      => nios_i2c_scl_oe,
        i2c_sda_in      => nios_i2c_sda,
        i2c_sda_oe      => nios_i2c_sda_oe,
        i2c_ss_n_export => nios_i2c_ss_n,

        spi_MISO    => '-',
        spi_MOSI    => open,
        spi_SCLK    => open,
        spi_SS_n    => open,

        pio_export => nios_pio_i,

        rst_reset_n => nios_rst_n,
        clk_clk     => nios_clk--,
    );

    FLASH_CE_n <= (flash_ce_n_i, flash_ce_n_i);
    FLASH_ADV_n <= '0';
    FLASH_CLK <= '0';
    FLASH_RESET_n <= flash_rst_n;



    e_i2c_mux : entity work.i2c_mux
    port map (
        io_scl(0)   => FAN_I2C_SCL,
        io_sda(0)   => FAN_I2C_SDA,
        io_scl(1)   => TEMP_I2C_SCL,
        io_sda(1)   => TEMP_I2C_SDA,
        io_scl(2)   => POWER_MONITOR_I2C_SCL,
        io_sda(2)   => POWER_MONITOR_I2C_SDA,

        o_scl       => nios_i2c_scl,
        i_scl_oe    => nios_i2c_scl_oe,
        o_sda       => nios_i2c_sda,
        i_sda_oe    => nios_i2c_sda_oe,

        i_ss_n      => nios_i2c_ss_n--,
    );



    QSFPA_LP_MODE <= '0';
    QSFPA_MOD_SEL_n <= '1';
    QSFPA_RST_n <= '1';

    e_qsfp : entity work.xcvr_a10
    generic map (
        INPUT_CLOCK_FREQUENCY_g => 125000000,
        DATA_RATE_g => 5000,
        CLK_MHZ_g => 125--,
    )
    port map (
        i_tx_data   => X"03CAFEBC"
                     & X"02BABEBC"
                     & X"01DEADBC"
                     & X"00BEEFBC",
        i_tx_datak  => "0001"
                     & "0001"
                     & "0001"
                     & "0001",

        o_rx_data   => open,
        o_rx_datak  => open,

        o_tx_clkout => open,
        i_tx_clkin  => (others => refclk_125),
        o_rx_clkout => open,
        i_rx_clkin  => (others => refclk_125),

        o_tx_serial => QSFPA_TX_p,
        i_rx_serial => QSFPA_RX_p,

        i_pll_clk   => refclk_125,
        i_cdr_clk   => refclk_125,

        i_avs_address     => av_qsfp.address(13 downto 0),
        i_avs_read        => av_qsfp.read,
        o_avs_readdata    => av_qsfp.readdata,
        i_avs_write       => av_qsfp.write,
        i_avs_writedata   => av_qsfp.writedata,
        o_avs_waitrequest => av_qsfp.waitrequest,

        i_reset     => not nios_rst_n,
        i_clk       => nios_clk--,
    );

end architecture;
