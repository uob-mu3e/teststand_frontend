library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.pcie_components.all;

entity a10_block is
generic (
    g_XCVR0_CHANNELS    : integer := 16;
    g_XCVR0_N           : integer := 4;
    g_XCVR1_CHANNELS    : integer := 0;
    g_XCVR1_N           : integer := 0;
    g_PCIE0_X           : integer := 8;
    g_PCIE1_X           : integer := 0;
    g_CLK_MHZ           : real := 50.0--;
);
port (
    -- flash interface
    o_flash_address     : out   std_logic_vector(31 downto 0);
    io_flash_data       : inout std_logic_vector(31 downto 0);
    o_flash_read_n      : out   std_logic;
    o_flash_write_n     : out   std_logic;
    o_flash_cs_n        : out   std_logic;
    o_flash_reset_n     : out   std_logic;

    -- I2C
    io_i2c_scl          : inout std_logic_vector(31 downto 0);
    io_i2c_sda          : inout std_logic_vector(31 downto 0);

    -- SPI
    i_spi_miso          : in    std_logic_vector(31 downto 0) := (others => '0');
    o_spi_mosi          : out   std_logic_vector(31 downto 0);
    o_spi_sclk          : out   std_logic_vector(31 downto 0);
    o_spi_ss_n          : out   std_logic_vector(31 downto 0);

    o_nios_hz           : out   std_logic;



    -- XCVR0 (6250 Mbps @ 156.25 MHz)
    i_xcvr0_rx          : in    std_logic_vector(g_XCVR0_CHANNELS-1 downto 0) := (others => '0');
    o_xcvr0_tx          : out   std_logic_vector(g_XCVR0_CHANNELS-1 downto 0);
    i_xcvr0_refclk      : in    std_logic_vector(g_XCVR0_N-1 downto 0) := (others => '0');

    o_xcvr0_rx_data     : out   work.util.slv32_array_t(g_XCVR0_CHANNELS-1 downto 0);
    o_xcvr0_rx_datak    : out   work.util.slv4_array_t(g_XCVR0_CHANNELS-1 downto 0);
    i_xcvr0_tx_data     : in    work.util.slv32_array_t(g_XCVR0_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr0_tx_datak    : in    work.util.slv4_array_t(g_XCVR0_CHANNELS-1 downto 0) := (others => (others => '0'));



    -- XCVR1 (10000 Mbps @ 250 MHz)
    i_xcvr1_rx          : in    std_logic_vector(g_XCVR1_CHANNELS-1 downto 0) := (others => '0');
    o_xcvr1_tx          : out   std_logic_vector(g_XCVR1_CHANNELS-1 downto 0);
    i_xcvr1_refclk      : in    std_logic_vector(g_XCVR1_N-1 downto 0) := (others => '0');

    o_xcvr1_rx_data     : out   work.util.slv32_array_t(g_XCVR1_CHANNELS-1 downto 0);
    o_xcvr1_rx_datak    : out   work.util.slv4_array_t(g_XCVR1_CHANNELS-1 downto 0);
    i_xcvr1_tx_data     : in    work.util.slv32_array_t(g_XCVR1_CHANNELS-1 downto 0) := (others => (others => '0'));
    i_xcvr1_tx_datak    : in    work.util.slv4_array_t(g_XCVR1_CHANNELS-1 downto 0) := (others => (others => '0'));



    -- PCIe0
    i_pcie0_rx          : in    std_logic_vector(g_PCIE0_X-1 downto 0) := (others => '0');
    o_pcie0_tx          : out   std_logic_vector(g_PCIE0_X-1 downto 0);
    i_pcie0_perst_n     : in    std_logic := '0';
    i_pcie0_refclk      : in    std_logic := '0'; -- ref 100 MHz clock
    o_pcie0_clk         : out   std_logic;

    -- PCIe0 DMA0
    i_pcie0_dma0_wdata  : in    std_logic_vector(255 downto 0) := (others => '0');
    i_pcie0_dma0_we     : in    std_logic := '0'; -- write enable
    i_pcie0_dma0_eoe    : in    std_logic := '0'; -- end of event
    o_pcie0_dma0_hfull  : out   std_logic; -- half full
    i_pcie0_dma0_clk    : in    std_logic := '0';

    -- PCIe0 read interface to writable memory
    i_pcie0_wmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    o_pcie0_wmem_rdata  : out   std_logic_vector(31 downto 0);
    i_pcie0_wmem_clk    : in    std_logic := '0';

    -- PCIe0 write interface to readable memory
    i_pcie0_rmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    i_pcie0_rmem_wdata  : in    std_logic_vector(31 downto 0) := (others => '0');
    i_pcie0_rmem_we     : in    std_logic := '0';
    i_pcie0_rmem_clk    : in    std_logic := '0';

    -- PCIe0 update interface for readable registers
    i_pcie0_rregs       : in    reg32array := (others => (others => '0'));

    -- PCIe0 read interface for writable registers
    o_pcie0_wregs_A     : out   reg32array;
    i_pcie0_wregs_A_clk : in    std_logic := '0';
    o_pcie0_wregs_B     : out   reg32array;
    i_pcie0_wregs_B_clk : in    std_logic := '0';



    -- PCIe1
    i_pcie1_rx          : in    std_logic_vector(g_PCIE1_X-1 downto 0) := (others => '0');
    o_pcie1_tx          : out   std_logic_vector(g_PCIE1_X-1 downto 0);
    i_pcie1_perst_n     : in    std_logic := '0';
    i_pcie1_refclk      : in    std_logic := '0'; -- ref 100 MHz clock
    o_pcie1_clk         : out   std_logic;

    -- PCIe1 DMA0
    i_pcie1_dma0_wdata  : in    std_logic_vector(255 downto 0) := (others => '0');
    i_pcie1_dma0_we     : in    std_logic := '0'; -- write enable
    i_pcie1_dma0_eoe    : in    std_logic := '0'; -- end of event
    o_pcie1_dma0_hfull  : out   std_logic; -- half full
    i_pcie1_dma0_clk    : in    std_logic := '0';

    -- PCIe1 read interface to writable memory
    i_pcie1_wmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    o_pcie1_wmem_rdata  : out   std_logic_vector(31 downto 0);
    i_pcie1_wmem_clk    : in    std_logic := '0';

    -- PCIe1 write interface to readable memory
    i_pcie1_rmem_addr   : in    std_logic_vector(15 downto 0) := (others => '0');
    i_pcie1_rmem_wdata  : in    std_logic_vector(31 downto 0) := (others => '0');
    i_pcie1_rmem_we     : in    std_logic := '0';
    i_pcie1_rmem_clk    : in    std_logic := '0';

    -- PCIe1 update interface for readable registers
    i_pcie1_rregs       : in    reg32array := (others => (others => '0'));

    -- PCIe1 read interface for writable registers
    o_pcie1_wregs_A     : out   reg32array;
    i_pcie1_wregs_A_clk : in    std_logic := '0';
    o_pcie1_wregs_B     : out   reg32array;
    i_pcie1_wregs_B_clk : in    std_logic := '0';



    o_reset_156_n       : out   std_logic;
    o_clk_156           : out   std_logic;

    o_reset_250_n       : out   std_logic;
    o_clk_250           : out   std_logic;

    -- global 125 MHz clock
    i_reset_125_n       : in    std_logic;
    i_clk_125           : in    std_logic;

    -- local clock
    i_reset_n           : in    std_logic;
    i_clk               : in    std_logic--;
);
end entity;

architecture arch of a10_block is

    signal flash_reset_n    : std_logic;
    signal nios_reset_n     : std_logic;

    signal reset_156_n      : std_logic;
    signal clk_156          : std_logic;
    signal reset_250_n      : std_logic;
    signal clk_250          : std_logic;

    signal flash_address    : std_logic_vector(o_flash_address'range) := (others => '0');

    signal nios_i2c_scl     : std_logic;
    signal nios_i2c_scl_oe  : std_logic;
    signal nios_i2c_sda     : std_logic;
    signal nios_i2c_sda_oe  : std_logic;
    signal nios_i2c_mask    : std_logic_vector(31 downto 0);

    signal nios_spi_miso    : std_logic;
    signal nios_spi_mosi    : std_logic;
    signal nios_spi_sclk    : std_logic;
    signal nios_spi_ss_n    : std_logic_vector(31 downto 0);

    signal nios_pio         : std_logic_vector(31 downto 0);

    signal av_xcvr0         : work.util.avalon_t;
    signal av_xcvr1         : work.util.avalon_t;

    signal pcie0_clk        : std_logic;
    signal pcie1_clk        : std_logic;

begin

    o_flash_reset_n <= flash_reset_n;

    o_flash_address <= flash_address;

    o_nios_hz <= nios_pio(7);

    o_reset_156_n <= reset_156_n;
    o_clk_156 <= clk_156;

    o_reset_250_n <= reset_250_n;
    o_clk_250 <= clk_250;

    -- 156.25 MHz data clock (reference is 125 MHz global clock)
    e_clk_156 : component work.cmp.ip_pll_125to156
    port map (
        outclk_0 => clk_156,
        refclk => i_clk_125,
        rst => not i_reset_125_n--,
    );

    e_reset_156_n : entity work.reset_sync
    port map ( o_reset_n => reset_156_n, i_reset_n => i_reset_125_n, i_clk => clk_156 );

    -- 250 MHz data clock (reference is 125 MHz global clock)
    e_clk_250 : component work.cmp.ip_pll_125to250
    port map (
        outclk_0 => clk_250,
        refclk => i_clk_125,
        rst => not i_reset_125_n--,
    );

    e_reset_250_n : entity work.reset_sync
    port map ( o_reset_n => reset_250_n, i_reset_n => i_reset_125_n, i_clk => clk_250 );

    o_pcie0_clk <= pcie0_clk;



    -- nios reset sequence
    e_nios_reset_n : entity work.debouncer
    generic map (
        W => 2,
        N => integer(g_CLK_MHZ * 1000000.0 * 0.200) -- 200ms
    )
    port map (
        i_d(0) => '1',
        o_q(0) => flash_reset_n,

        i_d(1) => flash_reset_n,
        o_q(1) => nios_reset_n,

        i_reset_n => i_reset_n,
        i_clk => i_clk--,
    );

    -- nios
    e_nios : work.cmp.nios
    port map (
        flash_tcm_address_out           => flash_address(27 downto 0),
        flash_tcm_data_out              => io_flash_data,
        flash_tcm_read_n_out(0)         => o_flash_read_n,
        flash_tcm_write_n_out(0)        => o_flash_write_n,
        flash_tcm_chipselect_n_out(0)   => o_flash_cs_n,

        i2c_scl_in                      => nios_i2c_scl,
        i2c_scl_oe                      => nios_i2c_scl_oe,
        i2c_sda_in                      => nios_i2c_sda,
        i2c_sda_oe                      => nios_i2c_sda_oe,
        i2c_mask_export                 => nios_i2c_mask,

        spi_MISO                        => nios_spi_miso,
        spi_MOSI                        => nios_spi_mosi,
        spi_SCLK                        => nios_spi_sclk,
        spi_SS_n                        => nios_spi_ss_n,

        pio_export                      => nios_pio,

        avm_xcvr_address                => av_xcvr0.address(17 downto 0),
        avm_xcvr_read                   => av_xcvr0.read,
        avm_xcvr_readdata               => av_xcvr0.readdata,
        avm_xcvr_write                  => av_xcvr0.write,
        avm_xcvr_writedata              => av_xcvr0.writedata,
        avm_xcvr_waitrequest            => av_xcvr0.waitrequest,

        avm_reset_reset_n               => i_reset_125_n,
        avm_clock_clk                   => i_clk_125,

        rst_reset_n                     => nios_reset_n,
        clk_clk                         => i_clk--,
    );



    -- i2c mux
    e_i2c_mux : entity work.i2c_mux
    port map (
        io_scl      => io_i2c_scl,
        io_sda      => io_i2c_sda,

        o_scl       => nios_i2c_scl,
        i_scl_oe    => nios_i2c_scl_oe,
        o_sda       => nios_i2c_sda,
        i_sda_oe    => nios_i2c_sda_oe,

        i_mask      => nios_i2c_mask--,
    );



    -- spi mux
    o_spi_mosi <= (others => nios_spi_mosi);
    o_spi_sclk <= (others => nios_spi_sclk);
    o_spi_ss_n <= nios_spi_ss_n;
    -- TODO: implement mux



    -- xcvr_block 6250 Mbps @ 156.25 MHz
    generate_xcvr0_block : if ( g_XCVR0_CHANNELS > 0 ) generate
    e_xcvr0_block : entity work.xcvr_block
    generic map (
        N_XCVR_g => g_XCVR0_N,
        N_CHANNELS_g => g_XCVR0_CHANNELS / g_XCVR0_N--,
    )
    port map (
        o_rx_data           => o_xcvr0_rx_data,
        o_rx_datak          => o_xcvr0_rx_datak,

        i_tx_data           => i_xcvr0_tx_data,
        i_tx_datak          => i_xcvr0_tx_datak,

        i_tx_clk            => (others => clk_156),
        i_rx_clk            => (others => clk_156),

        i_rx_serial         => i_xcvr0_rx,
        o_tx_serial         => o_xcvr0_tx,

        i_refclk            => i_xcvr0_refclk,

        i_avs_address       => av_xcvr0.address(17 downto 0),
        i_avs_read          => av_xcvr0.read,
        o_avs_readdata      => av_xcvr0.readdata,
        i_avs_write         => av_xcvr0.write,
        i_avs_writedata     => av_xcvr0.writedata,
        o_avs_waitrequest   => av_xcvr0.waitrequest,

        i_reset_n           => i_reset_125_n,
        i_clk               => i_clk_125--, -- TODO: use clk_156
    );
    end generate;



    -- xcvr_block 10000 Mbps @ 250 MHz
    generate_xcvr1_block : if ( g_XCVR1_CHANNELS > 0 ) generate
    e_xcvr1_block : entity work.xcvr_block
    generic map (
        N_XCVR_g => g_XCVR1_N,
        N_CHANNELS_g => g_XCVR1_CHANNELS / g_XCVR1_N--,
    )
    port map (
        o_rx_data           => o_xcvr1_rx_data,
        o_rx_datak          => o_xcvr1_rx_datak,

        i_tx_data           => i_xcvr1_tx_data,
        i_tx_datak          => i_xcvr1_tx_datak,

        i_rx_clk            => (others => clk_156),
        i_tx_clk            => (others => clk_156),

        i_rx_serial         => i_xcvr1_rx,
        o_tx_serial         => o_xcvr1_tx,

        i_refclk            => i_xcvr1_refclk,

        i_avs_address       => av_xcvr1.address(15 downto 0),
        i_avs_read          => av_xcvr1.read,
        o_avs_readdata      => av_xcvr1.readdata,
        i_avs_write         => av_xcvr1.write,
        i_avs_writedata     => av_xcvr1.writedata,
        o_avs_waitrequest   => av_xcvr1.waitrequest,

        i_reset_n           => reset_156_n,
        i_clk               => clk_156--,
    );
    end generate;



    -- PCIe0
    generate_pcie0 : if ( g_PCIE0_X > 0 ) generate
    e_pcie0_block : entity work.pcie_block
    generic map (
        DMAMEMWRITEADDRSIZE     => 11,
        DMAMEMREADADDRSIZE      => 11,
        DMAMEMWRITEWIDTH        => 256,
        g_PCIE_X => g_PCIE0_X--,
    )
    port map (
        local_rstn              => '1',
        appl_rstn               => '1',
        refclk                  => i_pcie0_refclk,
        pcie_fastclk_out        => pcie0_clk,

        pcie_rx_p               => i_pcie0_rx,
        pcie_tx_p               => o_pcie0_tx,
        pcie_refclk_p           => i_pcie0_refclk,
        pcie_perstn             => i_pcie0_perst_n,
        pcie_smbclk             => '0',
        pcie_smbdat             => '0',
        pcie_waken              => open,

        readregs                => i_pcie0_rregs,
        writeregs               => o_pcie0_wregs_A,

        writememreadaddr        => i_pcie0_wmem_addr,
        writememreaddata        => o_pcie0_wmem_rdata,
        writememclk             => i_pcie0_wmem_clk,

        readmem_addr            => i_pcie0_rmem_addr,
        readmem_data            => i_pcie0_rmem_wdata,
        readmem_wren            => i_pcie0_rmem_we,
        readmemclk              => i_pcie0_rmem_clk,
        readmem_endofevent      => '0',

        dma_data                => i_pcie0_dma0_wdata,
        dmamem_wren             => i_pcie0_dma0_we,
        dmamem_endofevent       => i_pcie0_dma0_eoe,
        dmamemhalffull          => o_pcie0_dma0_hfull,
        dmamemclk               => i_pcie0_dma0_clk,

        dma2memclk              => i_pcie0_dma0_clk--,
    );
    end generate;



    -- PCIe1
    generate_pcie1 : if ( g_PCIE1_X > 0 ) generate
    e_pcie1_block : entity work.pcie_block
    generic map (
        DMAMEMWRITEADDRSIZE     => 11,
        DMAMEMREADADDRSIZE      => 11,
        DMAMEMWRITEWIDTH        => 256,
        g_PCIE_X => g_PCIE1_X--,
    )
    port map (
        local_rstn              => '1',
        appl_rstn               => '1',
        refclk                  => i_pcie1_refclk,
        pcie_fastclk_out        => pcie1_clk,

        pcie_rx_p               => i_pcie1_rx,
        pcie_tx_p               => o_pcie1_tx,
        pcie_refclk_p           => i_pcie1_refclk,
        pcie_perstn             => i_pcie1_perst_n,
        pcie_smbclk             => '0',
        pcie_smbdat             => '0',
        pcie_waken              => open,

        readregs                => i_pcie1_rregs,
        writeregs               => o_pcie1_wregs_A,

        writememreadaddr        => i_pcie1_wmem_addr,
        writememreaddata        => o_pcie1_wmem_rdata,
        writememclk             => i_pcie1_wmem_clk,

        readmem_addr            => i_pcie1_rmem_addr,
        readmem_data            => i_pcie1_rmem_wdata,
        readmem_wren            => i_pcie1_rmem_we,
        readmemclk              => i_pcie1_rmem_clk,
        readmem_endofevent      => '0',

        dma_data                => i_pcie1_dma0_wdata,
        dmamem_wren             => i_pcie1_dma0_we,
        dmamem_endofevent       => i_pcie1_dma0_eoe,
        dmamemhalffull          => o_pcie1_dma0_hfull,
        dmamemclk               => i_pcie1_dma0_clk,

        dma2memclk              => i_pcie1_dma0_clk--,
    );
    end generate;

end architecture;