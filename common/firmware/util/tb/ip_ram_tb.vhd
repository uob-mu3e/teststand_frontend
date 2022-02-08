library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_ram_tb is
generic (
    g_STOP_TIME_US : integer := 1;
    g_SEED : integer := 0;
    g_CLK_MHZ : real := 1000.0--;
);
end entity;

architecture arch of ip_ram_tb is

    signal clk : std_logic := '1';
    signal reset_n : std_logic := '0';
    signal cycle : integer := 0;

    signal random : std_logic_vector(31 downto 0);
    signal DONE : std_logic_vector(0 downto 0) := (others => '0');

    signal addr : std_logic_vector(3 downto 0);
    signal wdata, rdata : std_logic_vector(3 downto 0);
    signal we : std_logic;

begin

    clk <= not clk after (0.5 us / g_CLK_MHZ);
    reset_n <= '0', '1' after (1.0 us / g_CLK_MHZ);
    cycle <= cycle + 1 after (1 us / g_CLK_MHZ);

    process
        variable lfsr : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(g_SEED, 32));
    begin
        for i in random'range loop
            lfsr := work.util.lfsr(lfsr, 31 & 21 & 1 & 0);
            random(i) <= lfsr(0);
        end loop;
        wait until rising_edge(clk);
    end process;

    --e_ram : entity work.ip_ram_2rw
    --generic map (
    --    g_ADDR0_WIDTH => 4,
    --    g_DATA0_WIDTH => 4,
    --    g_ADDR1_WIDTH => 4,
    --    g_DATA1_WIDTH => 4--,
    --)
    --port map (
    --    i_addr0     => random(3 downto 0),
    --    o_rdata0    => rdata,
    --    i_wdata0    => random(7 downto 4),
    --    i_we0       => random(8),
    --    i_clk0      => clk,

    --    i_addr1     => random(19 downto 16),
    --    o_rdata1    => rdata,
    --    i_wdata1    => random(23 downto 20),
    --    i_we1       => random(24),
    --    i_clk1      => clk--,
    --);

    addr <= random(3 downto 0);
    we <= random(7);

    e_ram : entity work.ip_ram_1rw
    generic map (
        g_ADDR_WIDTH => addr'length,
        g_DATA_WIDTH => wdata'length--,
    )
    port map (
        i_addr      => addr,
        o_rdata     => rdata,
        i_wdata     => addr,
        i_we        => we,
        i_clk       => clk--,
    );

    process
        variable n : integer_vector(2**addr'length-1 downto 0) := (others => 0);
        variable addr_v : std_logic_vector(addr'range);
    begin
        wait until rising_edge(clk);

        if ( n(to_integer(unsigned(addr_v))) > 0 and rdata /= addr_v ) then
            report work.util.SGR_FG_RED
                & "[cycle = " & integer'image(cycle) & "]"
                & " rdata = " & to_hstring(rdata)
                & " != " & to_hstring(addr_v)
                & work.util.SGR_RESET
            severity error;
        end if;

        addr_v := addr;
        if ( we = '1' ) then
            n(to_integer(unsigned(addr))) := n(to_integer(unsigned(addr))) + 1;
        end if;

        if ( cycle > g_STOP_TIME_US*integer(g_CLK_MHZ)-2 ) then
            DONE(0) <= '1';
            wait;
        end if;
    end process;

    process
    begin
        wait for g_STOP_TIME_US * 1 us;
        if ( DONE = (DONE'range => '1') ) then
            report work.util.SGR_FG_GREEN & "DONE" & work.util.SGR_RESET;
        else
            report work.util.SGR_FG_RED & "NOT DONE" & work.util.SGR_RESET;
        end if;
        assert ( DONE = (DONE'range => '1') ) severity error;
        wait;
    end process;

end architecture;
