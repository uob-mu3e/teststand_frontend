library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
generic (
    g_PCIE0_X : positive := 8;
    g_PCIE1_X : positive := 8--;
);
port (
    -- LEDs
    A10_LED                             : OUT   STD_LOGIC_VECTOR(7 DOWNTO 0);

    -- Color LEDs
    A10_LED_3C_1                        : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);
    A10_LED_3C_2                        : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);
    A10_LED_3C_3                        : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);
    A10_LED_3C_4                        : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);



    -- POD
    rx_gbt                              : IN    STD_LOGIC_VECTOR(47 DOWNTO 0);
    tx_gbt                              : OUT   STD_LOGIC_VECTOR(47 DOWNTO 0);
    A10_REFCLK_GBT_P_0                  : IN    STD_LOGIC; -- <- SI5345_1/2[IN2] <- SI53340_1[CLK1] <- SMA1
    A10_REFCLK_GBT_P_1                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_2                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_3                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_4                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_5                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_6                  : IN    STD_LOGIC;
    A10_REFCLK_GBT_P_7                  : IN    STD_LOGIC;



    -- PCIe 0
    i_pcie0_rx                          : in    std_logic_vector(g_PCIE0_X-1 downto 0);
    o_pcie0_tx                          : out   std_logic_vector(g_PCIE0_X-1 downto 0);
    i_pcie0_perst_n                     : in    std_logic;
    i_pcie0_refclk                      : in    std_logic;

    -- PCIe 1
    i_pcie1_rx                          : in    std_logic_vector(g_PCIE1_X-1 downto 0);
    o_pcie1_tx                          : out   std_logic_vector(g_PCIE1_X-1 downto 0);
    i_pcie1_perst_n                     : in    std_logic;
    i_pcie1_refclk                      : in    std_logic;



    -- SMA
--    A10_SMA_CLK_IN_P                    : in    std_logic;
    A10_SMA_CLK_OUT_P                   : out   std_logic;

    -- SI53344
    A10_SI53344_FANOUT_CLK_P            : out   std_logic; -- -> SI53344[CLK0]
    -- - CLK_SEL = SWITCH_6[0]
    -- - SI53340_1[CLK1] <- SMA1
    A10_CUSTOM_CLK_P                    : in    std_logic; -- <- SI53344 <- SI53340_1[CLK_SEL]

    -- SI5345_1
    -- - IN_SEL = SWITCH_6[1-2]
    -- - SI5345_1[IN2] <- SI53340_1
    A10_SI5345_1_SMB_SCL                : inout std_logic;
    A10_SI5345_1_SMB_SDA                : inout std_logic;
    A10_SI5345_1_JITTER_CLOCK_P         : out   std_logic; -- -> SI5345_1[IN1]

    -- SI5345_2
    -- - IN_SEL = SWITCH_6[3-4]
    -- - SI5345_2[IN2] <- SI53340_1
    A10_SI5345_2_SMB_SCL                : inout std_logic;
    A10_SI5345_2_SMB_SDA                : inout std_logic;
    A10_SI5345_2_JITTER_CLOCK_P         : out   std_logic; -- -> SI5345_2[IN1]



    -- reset from push button through Max V
    A10_M5FL_CPU_RESET_N                : IN    STD_LOGIC;

    -- general purpose internal clock
    CLK_A10_100MHZ_P                    : IN    STD_LOGIC--; -- from internal 100 MHz oscillator
);
end entity;

architecture arch of top is

    -- constants
    constant SWB_ID : std_logic_vector(7 downto 0) := x"01";
    constant g_NLINKS_FEB_TOTL   : positive := 16;
    constant g_NLINKS_FARM_TOTL  : positive := 16;
    constant g_NLINKS_FARM_PIXEL : positive := 8;
    constant g_NLINKS_DATA_PIXEL : positive := 10;
    constant g_NLINKS_FARM_SCIFI : positive := 8;
    constant g_NLINKS_DATA_SCIFI : positive := 4;
    constant g_NLINKS_FARM_TILE  : positive := 8;
    constant g_NLINKS_DATA_TILE  : positive := 12;

    signal led : std_logic_vector(7 downto 0) := (others => '0');
    signal reset_n : std_logic;

    -- local 100 MHz clock
    signal clk_100, reset_100_n : std_logic;

    signal pll_125 : std_logic;

    -- global 125 MHz clock
    signal clk_125, reset_125_n : std_logic;

    signal clk_156, reset_156_n, clk_250, reset_250_n : std_logic;
    signal pcie0_clk, pcie1_clk : std_logic;



    signal pod_rx_data : work.util.slv32_array_t(47 downto 0);
    signal pod_tx_data : work.util.slv32_array_t(47 downto 0) := (
        others => X"000000BC"--,
    );
    signal pod_rx_datak : work.util.slv4_array_t(47 downto 0);
    signal pod_tx_datak : work.util.slv4_array_t(47 downto 0) := (
        others => "0001"--,
    );

    -- pcie read / write registers
    signal pcie0_resets_n_A   : std_logic_vector(31 downto 0);
    signal pcie0_resets_n_B   : std_logic_vector(31 downto 0);
    signal pcie0_writeregs_A  : work.util.slv32_array_t(63 downto 0);
    signal pcie0_writeregs_B  : work.util.slv32_array_t(63 downto 0);
    signal pcie0_readregs_A   : work.util.slv32_array_t(63 downto 0);
    signal pcie0_readregs_B   : work.util.slv32_array_t(63 downto 0);
    
    -- pcie dma
    signal dma_data_wren, dmamem_endofevent, pcie0_dma0_hfull : std_logic;
    signal dma_data : std_logic_vector(255 downto 0);

begin

    A10_LED <= not led;
    reset_n <= A10_M5FL_CPU_RESET_N;



    clk_100 <= CLK_A10_100MHZ_P;

    e_reset_100_n : entity work.reset_sync
    port map ( o_reset_n => reset_100_n, i_reset_n => reset_n, i_clk => clk_100 );

    --! generate and route 125 MHz clock to SMA output
    --! (can be connected to SMA input as global clock)
    e_pll_100to125 : component work.cmp.ip_pll_100to125
    port map (
        outclk_0 => pll_125,
        refclk => clk_100,
        rst => not reset_100_n--,
    );

    A10_SMA_CLK_OUT_P <= pll_125;
    A10_SI53344_FANOUT_CLK_P <= pll_125;

    e_clk_125 : work.cmp.ip_clkctrl
    port map (
        inclk => A10_CUSTOM_CLK_P,
        outclk => clk_125--,
    );

    A10_SI5345_1_JITTER_CLOCK_P <= clk_125;
    A10_SI5345_2_JITTER_CLOCK_P <= clk_125;



    e_reset_125_n : entity work.reset_sync
    port map ( o_reset_n => reset_125_n, i_reset_n => reset_n, i_clk => clk_125 );


    --! A10 block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    a10_block : entity work.a10_block
    generic map (
        g_XCVR0_CHANNELS => 24,
        g_XCVR0_N => 4,
        g_XCVR1_CHANNELS => 24,
        g_XCVR1_N => 4,
        g_PCIE0_X => g_PCIE0_X,
        g_PCIE1_X => g_PCIE1_X,
        g_CLK_MHZ => 100.0--,
    )
    port map (
        -- I2C
        io_i2c_scl(1)                   => A10_SI5345_1_SMB_SCL,
        io_i2c_sda(1)                   => A10_SI5345_1_SMB_SDA,
        io_i2c_scl(2)                   => A10_SI5345_2_SMB_SCL,
        io_i2c_sda(2)                   => A10_SI5345_2_SMB_SDA,

        -- XCVR0 (6250 Mbps @ 156.25 MHz)
        i_xcvr0_rx                      => rx_gbt(47 downto 24),
        o_xcvr0_tx                      => tx_gbt(47 downto 24),
        i_xcvr0_refclk                  =>
            A10_REFCLK_GBT_P_7 & A10_REFCLK_GBT_P_6 & A10_REFCLK_GBT_P_5 & A10_REFCLK_GBT_P_4,
        o_xcvr0_rx_data                 => pod_rx_data(47 downto 24),
        o_xcvr0_rx_datak                => pod_rx_datak(47 downto 24),
        i_xcvr0_tx_data                 => pod_tx_data(47 downto 24),
        i_xcvr0_tx_datak                => pod_tx_datak(47 downto 24),

        -- XCVR1 (10000 Mbps @ 250 MHz)
        i_xcvr1_rx                      => rx_gbt(23 downto 0),
        o_xcvr1_tx                      => tx_gbt(23 downto 0),
        i_xcvr1_refclk                  =>
            A10_REFCLK_GBT_P_3 & A10_REFCLK_GBT_P_2 & A10_REFCLK_GBT_P_1 & A10_REFCLK_GBT_P_0,
        o_xcvr1_rx_data                 => pod_rx_data(23 downto 0),
        o_xcvr1_rx_datak                => pod_rx_datak(23 downto 0),
        i_xcvr1_tx_data                 => pod_tx_data(23 downto 0),
        i_xcvr1_tx_datak                => pod_tx_datak(23 downto 0),

        -- PCIe0
        i_pcie0_rx                      => i_pcie0_rx,
        o_pcie0_tx                      => o_pcie0_tx,
        i_pcie0_perst_n                 => i_pcie0_perst_n,
        i_pcie0_refclk                  => i_pcie0_refclk,
        o_pcie0_clk                     => pcie0_clk,

        -- PCIe0 DMA0
        i_pcie0_dma0_wdata              => dma_data,
        i_pcie0_dma0_we                 => dma_data_wren,
        i_pcie0_dma0_eoe                => dmamem_endofevent,
        o_pcie0_dma0_hfull              => pcie0_dma0_hfull,
        i_pcie0_dma0_clk                => pcie0_clk,

        -- PCIe0 read interface to writable memory
        i_pcie0_wmem_addr               => writememreadaddr,
        o_pcie0_wmem_rdata              => writememreaddata,
        i_pcie0_wmem_clk                => clk_156,

        -- PCIe0 write interface to readable memory
        i_pcie0_rmem_addr               => readmem_writeaddr,
        i_pcie0_rmem_wdata              => readmem_writedata,
        i_pcie0_rmem_we                 => readmem_wren,
        i_pcie0_rmem_clk                => clk_156,

        -- PCIe0 update interface for readable registers
        i_pcie0_rregs_A                 => pcie0_readregs_A,
        i_pcie0_rregs_B                 => pcie0_readregs_B,

        -- PCIe0 read interface for writable registers
        o_pcie0_wregs_A                 => pcie0_writeregs_A,
        i_pcie0_wregs_A_clk             => pcie0_clk,
        o_pcie0_wregs_B                 => pcie0_writeregs_B,
        i_pcie0_wregs_B_clk             => clk_156,
        o_pcie0_wregs_C                 => open,
        i_pcie0_wregs_C_clk             => clk_156,
        o_pcie0_resets_n_A              => pcie0_resets_n_A,
        o_pcie0_resets_n_B              => pcie0_resets_n_B,    

        o_reset_156_n                   => reset_156_n,
        o_clk_156                       => clk_156,
        o_clk_156_hz                    => led(2),

        o_reset_250_n                   => reset_250_n,
        o_clk_250                       => clk_250,

        i_reset_125_n                   => reset_125_n,
        i_clk_125                       => clk_125,
        o_clk_125_hz                    => led(1),

        i_reset_n                       => reset_100_n,
        i_clk                           => clk_100--,
    );


    --! SWB Block
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    --! ------------------------------------------------------------------------
    e_swb_block : entity work.swb_block
    generic map (
        g_NLINKS_FEB_TOTL       => g_NLINKS_FEB_TOTL,
        g_NLINKS_FARM_TOTL      => g_NLINKS_FARM_TOTL,
        g_NLINKS_FARM_PIXEL     => g_NLINKS_FARM_PIXEL,
        g_NLINKS_DATA_PIXEL     => g_NLINKS_DATA_PIXEL,
        SWB_ID                  => SWB_ID--,
    )
    port map (
        i_rx            => rx_data_raw,
        i_rx_k          => rx_datak_raw,
        o_tx            => tx_data,
        o_tx_k          => tx_datak,

        i_writeregs_250 => pcie0_writeregs_A,
        i_writeregs_156 => pcie0_writeregs_B,
    
        o_readregs_250  => pcie0_readregs_A,
        o_readregs_156  => pcie0_readregs_B,

        i_resets_n_250  => pcie0_resets_n_A,
        i_resets_n_156  => pcie0_resets_n_B,

        i_wmem_rdata    => writememreaddata,
        o_wmem_addr     => writememreadaddr,

        o_rmem_wdata    => readmem_writedata,
        o_rmem_addr     => readmem_writeaddr,
        o_rmem_we       => readmem_wren,

        i_dmamemhalffull=> pcie0_dma0_hfull,
        o_dma_wren      => dma_data_wren,
        o_endofevent    => dmamem_endofevent,
        o_dma_data      => dma_data,

        o_farm_data     => open,
        o_farm_datak    => open,

        --! 250 MHz clock / reset_n
        i_reset_n_250   => reset_pcie0_n,
        i_clk_250       => pcie_fastclk_out,

        --! 156 MHz clock / reset_n
        i_reset_n_156   => reset_156_n,
        i_clk_156       => clk_156--,
    );

end architecture;
