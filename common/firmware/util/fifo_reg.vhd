--
-- fifo based on registers
--
-- author : Alexandr Kozlinskiy
-- date : 2021-06-11
--

library ieee;
use ieee.std_logic_1164.all;

--
--
--
entity fifo_reg is
generic (
    g_DATA_WIDTH : positive := 32;
    g_N : positive := 2--;
);
port (
    i_we        : in    std_logic;
    i_wdata     : in    std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_wfull     : out   std_logic;
    o_wfull_n   : out   std_logic;

    i_rack      : in    std_logic;
    o_rdata     : out   std_logic_vector(g_DATA_WIDTH-1 downto 0);
    o_rempty    : out   std_logic;
    o_rempty_n  : out   std_logic;

    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of fifo_reg is

    type cell_array_t is array (natural range <>) of std_logic_vector(g_DATA_WIDTH-1 downto 0);
    signal cell : cell_array_t(0 to g_N+1) := (others => (others => '-'));
    signal empty : std_logic_vector(0 to g_N+1) := (0 => '0', others => '1');
    signal full : std_logic;

begin

    -- empty(0) is used when i_rack = '0' and index is 1
    empty(0) <= '0';
    cell(0) <= (others => '-');
    -- cell(g_N+1) is used when i_rack = '1' and index is g_N
    empty(g_N+1) <= '1';
    cell(g_N+1) <= (others => '-');

    -- cell(1) contains readable data
    o_wfull <= full;
    o_wfull_n <= not full;
    o_rdata <= cell(1);
    o_rempty <= empty(1);
    o_rempty_n <= not empty(1);

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        for i in 1 to g_N loop
            cell(i) <= (others => '-');
            empty(i) <= '1';
        end loop;
        full <= '1';
    elsif rising_edge(i_clk) then
        if ( i_rack = '1' and empty(1) = '0' ) then
            -- read from cell(1) -> shift left
            cell(1 to g_N) <= cell(2 to g_N+1);
            empty(1 to g_N) <= empty(2 to g_N+1);
            full <= '0';
        elsif ( i_we = '1' and empty(g_N-1 to g_N) = "01" ) then
            -- write to last empty cell
            full <= '1';
        else
            full <= not empty(g_N);
        end if;

        if ( i_rack = '1' and empty(1) = '0' ) then
            -- copy wdata into last not empty cell
            -- (but don't touch last cell - full is '1')
            for i in 1 to g_N-1 loop
                if ( empty(i to i+1) = "01" ) then
                    cell(i) <= i_wdata;
                    empty(i) <= not i_we;
                end if;
            end loop;
        else
            -- copy wdata into first empty cell
            for i in 1 to g_N loop
                if ( empty(i-1 to i) = "01" ) then
                    cell(i) <= i_wdata;
                    empty(i) <= not i_we;
                end if;
            end loop;
        end if;
    end if;
    end process;

end architecture;
