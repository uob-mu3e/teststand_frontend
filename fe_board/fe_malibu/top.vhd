library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daq_constants.all;

entity top is
port (
    -- FE.A
    malibu_ck_fpga_0    : out   std_logic; -- pin 36, 38 -- malibu.CK_FPGA_0_N/P
    malibu_pll_reset    : out   std_logic; -- pin 42, 44 -- malibu.PLL_reset_P/N
    malibu_spi_sck      : out   std_logic; -- pin 54 -- malibu.SPI_SCK_P
    malibu_spi_sdi      : inout std_logic; -- pin 50 -- malibu.SPI_SDI_P
    malibu_spi_sdo      : inout std_logic; -- pin 52 -- malibu.SPI_SDO_N
    malibu_chip_reset   : out   std_logic; -- pin 48 -- malibu.chip_reset

    -- FE.B
    malibu_ck_fpga_1    : out   std_logic; -- pin 36, 38 -- malibu.CK_FPGA_1_P/N
    malibu_pll_test     : out   std_logic; -- pin 42, 44 -- malibu.PLL_TEST_N/P
    malibu_i2c_scl      : out   std_logic; -- pin 54 -- malibu.i2c_SCL
    malibu_i2c_sda      : inout std_logic; -- pin 56 -- malibu.i2c_SDA
    malibu_i2c_int_n    : inout std_logic; -- pin 52 -- malibu.I2C_INTn
    malibu_spi_sdo_cec  : in    std_logic; -- pin 48 -- malibu.SPI_SDO_CEC

    malibu_data         : in    std_logic_vector(13 downto 0);



    -- SI45

    si45_oe_n       : out   std_logic; -- <= '0'
    si45_rst_n      : out   std_logic; -- reset
    si45_spi_out    : in    std_logic; -- slave data out
    si45_spi_in     : out   std_logic; -- slave data in
    si45_spi_sclk   : out   std_logic; -- clock
    si45_spi_cs_n   : out   std_logic; -- chip select



    -- QSFP

    qsfp_pll_clk    : in    std_logic; -- 156.25 MHz

    QSFP_ModSel_n   : out   std_logic; -- module select (i2c)
    QSFP_Rst_n      : out   std_logic;
    QSFP_LPM        : out   std_logic; -- Low Power Mode

    qsfp_tx         : out   std_logic_vector(3 downto 0);
    qsfp_rx         : in    std_logic_vector(3 downto 0);



    -- POD

    pod_pll_clk     : in    std_logic;

    pod_tx_reset    : out   std_logic;
    pod_rx_reset    : out   std_logic;

    pod_tx          : out   std_logic_vector(3 downto 0);
    pod_rx          : in    std_logic_vector(3 downto 0);



    -- MSCB

    mscb_data_in    : in    std_logic;
    mscb_data_out   : out   std_logic;
    mscb_oe         : out   std_logic;



    --

    led_n       : out   std_logic_vector(15 downto 0);

    PushButton  : in    std_logic_vector(1 downto 0);



    reset_n     : in    std_logic;

    -- 125 MHz
    clk_aux     : in    std_logic--;
);
end entity;

architecture arch of top is

    -- https://www.altera.com/support/support-resources/knowledge-base/solutions/rd01262015_264.html
    signal ZERO : std_logic := '0';
    attribute keep : boolean;
    attribute keep of ZERO : signal is true;

    signal led : std_logic_vector(led_n'range) := (others => '0');

    signal nios_clk, nios_reset_n : std_logic;
    signal nios_pio : std_logic_vector(31 downto 0);

    signal i2c_scl_in, i2c_scl_oe, i2c_sda_in, i2c_sda_oe : std_logic;
    signal spi_miso, spi_mosi, spi_sclk : std_logic;
    signal spi_ss_n : std_logic_vector(1 downto 0);



    signal malibu_clk : std_logic;
    signal malibu_rx_data_clk : std_logic;

    signal fifo_data : std_logic_vector(35 downto 0);
    signal fifo_data_empty, fifo_data_read : std_logic;



    signal av_pod, av_qsfp : work.util.avalon_t;

    signal qsfp_tx_data : std_logic_vector(127 downto 0);
    signal qsfp_tx_datak : std_logic_vector(15 downto 0);

    signal qsfp_rx_data : std_logic_vector(127 downto 0);
    signal qsfp_rx_datak : std_logic_vector(15 downto 0);

    signal qsfp_reset_n : std_logic;



    signal av_sc : work.util.avalon_t;

    signal mscb_to_nios_parallel_in : std_logic_vector(11 downto 0);
    signal mscb_from_nios_parallel_out : std_logic_vector(11 downto 0);
    signal mscb_counter_in : unsigned(15 downto 0);
	 
	 signal reset_bypass : std_logic_vector(11 downto 0);

	 signal pod_rx_clk : std_logic;
	 signal pod_rx_data : std_logic_vector(7 downto 0);
	 
	 signal run_state : feb_run_state;
	 signal terminated : std_logic;

    signal av_test : work.util.avalon_t;

begin

    led_n <= not led;

    -- 125 MHz
    e_clk_aux_hz : entity work.clkdiv
    generic map ( P => 125000000 )
    port map ( clkout => led(15), rst_n => reset_n, clk => clk_aux );

    -- 156.25 MHz
    e_clk_qsfp_hz : entity work.clkdiv
    generic map ( P => 156250000 )
    port map ( clkout => led(14), rst_n => reset_n, clk => qsfp_pll_clk );

    -- 125 MHz
    e_clk_pod_hz : entity work.clkdiv
    generic map ( P => 125000000 )
    port map ( clkout => led(13), rst_n => reset_n, clk => pod_pll_clk );

    ----------------------------------------------------------------------------
    -- NIOS

    nios_clk <= clk_aux;

    e_nios_reset_n : entity work.reset_sync
    port map ( rstout_n => nios_reset_n, arst_n => reset_n, clk => nios_clk );

    e_qsfp_reset_n : entity work.reset_sync
    port map ( rstout_n => qsfp_reset_n, arst_n => reset_n, clk => qsfp_pll_clk );

    led(12) <= nios_pio(7);

    e_nios : component work.cmp.nios
    port map (
        avm_qsfp_address        => av_qsfp.address(15 downto 0),
        avm_qsfp_read           => av_qsfp.read,
        avm_qsfp_readdata       => av_qsfp.readdata,
        avm_qsfp_write          => av_qsfp.write,
        avm_qsfp_writedata      => av_qsfp.writedata,
        avm_qsfp_waitrequest    => av_qsfp.waitrequest,

        avm_pod_address         => av_pod.address(15 downto 0),
        avm_pod_read            => av_pod.read,
        avm_pod_readdata        => av_pod.readdata,
        avm_pod_write           => av_pod.write,
        avm_pod_writedata       => av_pod.writedata,
        avm_pod_waitrequest     => av_pod.waitrequest,

        avm_sc_address          => av_sc.address(17 downto 0),
        avm_sc_read             => av_sc.read,
        avm_sc_readdata         => av_sc.readdata,
        avm_sc_write            => av_sc.write,
        avm_sc_writedata        => av_sc.writedata,
        avm_sc_waitrequest      => av_sc.waitrequest,

        avm_test_address        => av_test.address(15 downto 0),
        avm_test_read           => av_test.read,
        avm_test_readdata       => av_test.readdata,
        avm_test_write          => av_test.write,
        avm_test_writedata      => av_test.writedata,
        avm_test_waitrequest    => av_test.waitrequest,

        avm_clk_clk          => qsfp_pll_clk,
        avm_reset_reset_n    => qsfp_reset_n,

        --
        -- nios base
        --

        i2c_scl_in => i2c_scl_in,
        i2c_scl_oe => i2c_scl_oe,
        i2c_sda_in => i2c_sda_in,
        i2c_sda_oe => i2c_sda_oe,

        spi_miso => spi_miso,
        spi_mosi => spi_mosi,
        spi_sclk => spi_sclk,
        spi_ss_n => spi_ss_n,

        pio_export => nios_pio,

        -- mscb
        parallel_mscb_in_export => mscb_to_nios_parallel_in,
        parallel_mscb_out_export => mscb_from_nios_parallel_out,
        counter_in_export => std_logic_vector(mscb_counter_in),
		  
		  -- reset bypass
		  reset_bypass_out_export => reset_bypass,

        rst_reset_n => nios_reset_n,
        clk_clk => nios_clk--,
    );

    si45_oe_n <= '0';
    si45_rst_n <= '1';
    si45_spi_in <= spi_mosi;
--    spi_miso <= si45_spi_out;
    si45_spi_sclk <= spi_sclk;
    si45_spi_cs_n <= spi_ss_n(0);



    -- I2C
    i2c_scl_in <= not i2c_scl_oe;
    i2c_sda_in <=
        malibu_i2c_sda and
        '1';
    malibu_i2c_scl <= ZERO when i2c_scl_oe = '1' else 'Z';
    malibu_i2c_sda <= ZERO when i2c_sda_oe = '1' else 'Z';

    -- SPI
    malibu_spi_sdi <= spi_mosi;
--    spi_miso <= malibu_spi_sdo;
    malibu_spi_sck <= spi_sclk;

    spi_miso <= si45_spi_out when spi_ss_n(0) = '0' else
                malibu_spi_sdo when spi_ss_n(1) = '0' else '0';

    ----------------------------------------------------------------------------



    ----------------------------------------------------------------------------
    -- MALIBU

    malibu_ck_fpga_1 <= '0';
    malibu_pll_reset <= '0';

    e_malibu_path : entity work.malibu_path
    generic map (
        N_g => 1--,
    )
    port map (
        i_avs_address       => av_test.address(5 downto 2),
        i_avs_read          => av_test.read,
        o_avs_readdata      => av_test.readdata,
        i_avs_write         => av_test.write,
        i_avs_writedata     => av_test.writedata,
        o_avs_waitrequest   => av_test.waitrequest,

        o_ck_fpga_0         => malibu_ck_fpga_0,
        o_chip_reset        => malibu_chip_reset,
        o_pll_test          => malibu_pll_test,
        i_data              => malibu_data(0 downto 0),

        o_fifo_data         => fifo_data,
        o_fifo_empty        => fifo_data_empty,
        i_fifo_rack         => fifo_data_read,

        i_reset             => not reset_n,
        i_clk               => qsfp_pll_clk--,
    );

    ----------------------------------------------------------------------------



    e_data_sc_path : entity work.data_sc_path
    port map (
        i_avs_address       => av_sc.address(17 downto 2),
        i_avs_read          => av_sc.read,
        o_avs_readdata      => av_sc.readdata,
        i_avs_write         => av_sc.write,
        i_avs_writedata     => av_sc.writedata,
        o_avs_waitrequest   => av_sc.waitrequest,

        i_fifo_data         => fifo_data,
        i_fifo_data_empty   => fifo_data_empty,
        o_fifo_data_read    => fifo_data_read,

        i_link_data         => qsfp_rx_data(31 downto 0),
        i_link_datak        => qsfp_rx_datak(3 downto 0),

        o_link_data         => qsfp_tx_data(31 downto 0),
        o_link_datak        => qsfp_tx_datak(3 downto 0),
		  
		  o_terminated			 => terminated,
		  i_run_state			 => run_state,

        i_reset             => not reset_n,
        i_clk               => qsfp_pll_clk--,
    );



    ----------------------------------------------------------------------------
    -- MSCB

    i_mscb : entity work.mscb
    port map (
        nios_clk                    => nios_clk,
        reset                       => not nios_reset_n,
        mscb_to_nios_parallel_in    => mscb_to_nios_parallel_in,
        mscb_from_nios_parallel_out => mscb_from_nios_parallel_out,
        mscb_data_in                => mscb_data_in,
        mscb_data_out               => mscb_data_out,
        mscb_oe                     => mscb_oe,
        mscb_counter_in             => mscb_counter_in--,
    );

    
	 ----------------------------------------------------------------------------
	 -- reset system
	 
	 e_reset_sys : entity work.resetsys
	 port map (
		 clk_reset_rx					   => pod_rx_clk,						-- recovered clk from reset receiver
		 clk_global							=> clk_aux,                   -- state transitions will be synchronised to this clock
		 clk_free							=> clk_aux,							-- replace with independent, free running clock (not required, used for phase measurement between clk_reset_rx and clk_global)
		 reset_in							=> not PushButton(0),			-- hard reset for testing, do not connect this to any "normal" reset
		 resets_out							=> open,								-- 16 bit reset mask, use this together with feb state .. example: nios_reset => (run_state=reset_state and resets(x)='1')  
		 phase_out							=> open,								-- phase between clk_reset_rx and clk_global
		 data_in								=> pod_rx_data,					-- 8 bit reset link input
		 reset_bypass						=> reset_bypass,					-- bypass of reset link using nios & jtag (for setups without the genesis board)
		 state_out							=> run_state,						-- run state of the frontend board
		 run_number_out					=> open,								-- run number from midas, updated on state run_prep
		 fpga_id								=> x"FEB0",							-- input of fpga id, needed for addressed reset commands in setups with >1 FEBs
		 terminated							=> terminated,						-- changes run state from terminating to idle if set to 1  (data merger will set this if run was finished properly)
		 testout								=> led(5 downto 0)
	 );
	
	
    ----------------------------------------------------------------------------
    -- QSFP
    -- (data and slow_control)

    QSFP_ModSel_n <= '1';
    QSFP_Rst_n <= '1';
    QSFP_LPM <= '0';

    e_qsfp : entity work.xcvr_s4
    generic map (
        NUMBER_OF_CHANNELS_g => 4,
        CHANNEL_WIDTH_g => 32,
        INPUT_CLOCK_FREQUENCY_g => 156250000,
        DATA_RATE_g => 6250,
        CLK_MHZ_g => 125--,
    )
    port map (
        i_tx_data   => qsfp_tx_data,
        i_tx_datak  => qsfp_tx_datak,

        o_rx_data   => qsfp_rx_data,
        o_rx_datak  => qsfp_rx_datak,

        o_tx_clkout => open,
        i_tx_clkin  => (others => qsfp_pll_clk),
        o_rx_clkout => open,
        i_rx_clkin  => (others => qsfp_pll_clk),

        o_tx_serial => qsfp_tx,
        i_rx_serial => qsfp_rx,

        i_pll_clk   => qsfp_pll_clk,
        i_cdr_clk   => qsfp_pll_clk,

        i_avs_address     => av_qsfp.address(15 downto 2),
        i_avs_read        => av_qsfp.read,
        o_avs_readdata    => av_qsfp.readdata,
        i_avs_write       => av_qsfp.write,
        i_avs_writedata   => av_qsfp.writedata,
        o_avs_waitrequest => av_qsfp.waitrequest,

        i_reset     => not nios_reset_n,
        i_clk       => nios_clk--,
    );

    qsfp_tx_data(127 downto 32) <=
          X"03CAFE" & work.util.D28_5
        & X"02BABE" & work.util.D28_5
        & X"01DEAD" & work.util.D28_5;

    qsfp_tx_datak(15 downto 4) <=
          "0001"
        & "0001"
        & "0001";

    ----------------------------------------------------------------------------



    ----------------------------------------------------------------------------
    -- POD
    -- (reset system)

    pod_tx_reset <= '0';
    pod_rx_reset <= '1';

    e_pod : entity work.xcvr_s4
    generic map (
        NUMBER_OF_CHANNELS_g => 4,
        CHANNEL_WIDTH_g => 8,
        INPUT_CLOCK_FREQUENCY_g => 125000000,
        DATA_RATE_g => 1250,
        CLK_MHZ_g => 125--,
    )
    port map (
        -- avalon slave interface
        i_avs_address     => av_pod.address(15 downto 2),
        i_avs_read        => av_pod.read,
        o_avs_readdata    => av_pod.readdata,
        i_avs_write       => av_pod.write,
        i_avs_writedata   => av_pod.writedata,
        o_avs_waitrequest => av_pod.waitrequest,

        i_tx_data   => work.util.D28_5
                     & work.util.D28_5
                     & work.util.D28_5
                     & work.util.D28_5,
        i_tx_datak  => "1"
                     & "1"
                     & "1"
                     & "1",

        o_rx_data(7 downto 0)   => pod_rx_data,
        o_rx_datak  => open,

        o_tx_clkout => open,
        i_tx_clkin  => (others => pod_pll_clk),
        o_rx_clkout(0) => pod_rx_clk,
        i_rx_clkin  => (others => pod_pll_clk),

        o_tx_serial => pod_tx,
        i_rx_serial => pod_rx,

        i_pll_clk   => pod_pll_clk,
        i_cdr_clk   => pod_pll_clk,

        i_reset     => not nios_reset_n,
        i_clk       => nios_clk--,
    );

    ----------------------------------------------------------------------------

end architecture;
