library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.a10_counters.all;
use work.a10_pcie_registers.all;


entity swb_readout_counters is
generic (
    g_A_CNT             : positive := 4;
    g_B_CNT             : positive := 4;
    g_NLINKS_DATA_SCIFI : positive := 4;
    g_NLINKS_DATA_PIXEL : positive := 10--;
);
port (
    --! register inputs for pcie0
    i_wregs_add_A   : in    std_logic_vector(31 downto 0);

    --! counters
    i_counter_A     : in    work.util.slv32_array_t(g_A_CNT - 1 downto 0);
    i_counter_B     : in    work.util.slv32_array_t(g_B_CNT - 1 downto 0);

    --! register outputs for pcie0
    o_pcie_data     : out   std_logic_vector(31 downto 0);
    o_pcie_addr     : out   std_logic_vector(31 downto 0);

    --! i_reset
    i_reset_n_A     : in    std_logic;    -- pcie clk

    --! clocks
    i_clk_A         : in    std_logic;    -- pcie clk
    i_clk_B         : in    std_logic--;  -- link clk

);
end entity;

--! @brief arch definition of the a10_readout_counters
--! @details The arch of the a10_readout_counters sync
--! the three clk domains used in the A10 board and outputs
--! the counters for a given input addr
architecture arch of swb_readout_counters is

    constant max_cnt_value                      : positive := 5 + g_NLINKS_DATA_PIXEL * 5;

    signal rdempty_pixel_B                      : std_logic;
    signal data_rregs_pixel_B, q_rregs_pixel_B  : std_logic_vector(g_NLINKS_DATA_PIXEL * 5 * 32 - 1 downto 0);
    signal s_counter_B                          : work.util.slv32_array_t(g_B_CNT - 1 downto 0);
    signal wregs_add_A_reg                      : std_logic_vector(31 downto 0);

begin

    --! sync counters from different blocks
    gen_sync : FOR i in 0 to g_NLINKS_DATA_PIXEL * 5 - 1 GENERATE
        data_rregs_pixel_B(i * 32 + 31 downto i * 32) <= i_counter_B(i);
    END GENERATE gen_sync;

    --! sync FIFOs
    e_sync_fifo_pixel_B : entity work.ip_dcfifo
    generic map(
        ADDR_WIDTH  => 4, DATA_WIDTH  => g_NLINKS_DATA_PIXEL * 5 * 32--,
    ) port map ( data => data_rregs_pixel_B, wrreq => '1',
             rdreq => not rdempty_pixel_B, wrclk => i_clk_B, rdclk => i_clk_A,
             q => q_rregs_pixel_B, rdempty => rdempty_pixel_B, aclr => '0'--,
    );
    
    gen_sync_cnt : FOR i in 0 to g_NLINKS_DATA_PIXEL * 5 - 1 GENERATE
        s_counter_B(i) <= q_rregs_pixel_B(i * 32 + 31 downto i * 32);
    END GENERATE gen_sync_cnt;

    --! map counters pixel
    process(i_clk_A, i_reset_n_A)
        variable link_id : integer;
    begin
    if ( i_reset_n_A = '0' ) then
        o_pcie_data     <= (others => '0');
        o_pcie_addr     <= (others => '0');
        wregs_add_A_reg <= (others => '0');
        --
    elsif ( rising_edge(i_clk_A) ) then
        wregs_add_A_reg <= i_wregs_add_A;
        o_pcie_addr     <= i_wregs_add_A;
        link_id         := to_integer(unsigned(i_wregs_add_A(SWB_LINK_RANGE)));
        if ( i_wregs_add_A /= wregs_add_A_reg ) then
            if ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_STREAM_FIFO_FULL_PIXEL_CNT ) then
                o_pcie_data <= i_counter_A(SWB_STREAM_FIFO_FULL_PIXEL_CNT);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_BANK_BUILDER_IDLE_NOT_HEADER_PIXEL_CNT ) then
                o_pcie_data <= i_counter_A(SWB_BANK_BUILDER_IDLE_NOT_HEADER_PIXEL_CNT);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_BANK_BUILDER_RAM_FULL_PIXEL_CNT ) then
                o_pcie_data <= i_counter_A(SWB_BANK_BUILDER_RAM_FULL_PIXEL_CNT);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_BANK_BUILDER_TAG_FIFO_FULL_PIXEL_CNT ) then
                o_pcie_data <= i_counter_A(SWB_BANK_BUILDER_TAG_FIFO_FULL_PIXEL_CNT);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_LINK_FIFO_ALMOST_FULL_PIXEL_CNT ) then
                o_pcie_data <= s_counter_B(SWB_LINK_FIFO_ALMOST_FULL_PIXEL_CNT + link_id * 5);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_LINK_FIFO_FULL_PIXEL_CNT ) then
                o_pcie_data <= s_counter_B(SWB_LINK_FIFO_FULL_PIXEL_CNT + link_id * 5);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_SKIP_EVENT_PIXEL_CNT ) then
                o_pcie_data <= s_counter_B(SWB_SKIP_EVENT_PIXEL_CNT + link_id * 5);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_EVENT_PIXEL_CNT ) then
                o_pcie_data <= s_counter_B(SWB_EVENT_PIXEL_CNT + link_id * 5);
            elsif ( to_integer(unsigned(i_wregs_add_A(SWB_COUNTER_ADDR_RANGE))) = SWB_SUB_HEADER_PIXEL_CNT ) then
                o_pcie_data <= s_counter_B(SWB_SUB_HEADER_PIXEL_CNT + link_id * 5);
            end if;
        end if;
    end if;
    end process;

end architecture;
