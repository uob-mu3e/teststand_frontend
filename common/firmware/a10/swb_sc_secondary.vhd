----------------------------------------------------------------------------
-- Slow Control Secondary Unit for Switching Board
-- Marius Koeppel, Mainz University
-- mkoeppel@uni-mainz.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity swb_sc_secondary is
generic (
    NLINKS : positive := 4;
    skip_init : std_logic := '0'
);
port (
    i_link_enable               : in    std_logic_vector(NLINKS-1 downto 0);
    i_link_data                 : in    work.mu3e.link_array_t(NLINKS-1 downto 0);

    mem_data_out                : out   std_logic_vector(31 downto 0);
    mem_addr_out                : out   std_logic_vector(15 downto 0);
    mem_addr_finished_out       : out   std_logic_vector(15 downto 0);
    mem_wren                    : out   std_logic;
    stateout                    : out   std_logic_vector(3 downto 0);

    i_reset_n                   : in    std_logic;
    i_clk                       : in    std_logic--;
);
end entity;

architecture arch of swb_sc_secondary is

    signal link_data : work.mu3e.link_array_t(NLINKS-1 downto 0);

    signal mem_data_o : std_logic_vector(31 downto 0);
    signal mem_addr_o : std_logic_vector(15 downto 0);
    signal mem_wren_o : std_logic;
    signal current_link : integer range 0 to NLINKS - 1;

    type state_type is (init, waiting, starting);
    signal state : state_type;

begin

    link_data <= i_link_data;

    mem_data_out <= mem_data_o;
    mem_addr_out <= mem_addr_o;
    mem_wren     <= mem_wren_o;

    process(i_reset_n, i_clk)
    begin
    if ( i_reset_n = '0' ) then
        mem_data_o <= (others => '0');
        mem_addr_o <= (others => '1');
        mem_addr_finished_out <= (others => '1');
        stateout <= (others => '0');
        mem_wren_o <= '0';
        current_link <= 0;
        if ( skip_init = '0' ) then
            state <= init;
        else
            state <= waiting;
        end if;

    elsif rising_edge(i_clk) then
        stateout <= (others => '0');
        mem_data_o <= (others => '0');
        mem_wren_o <= '0';
        mem_wren_o <= '0';

        case state is
        when init =>
            stateout(3 downto 0) <= x"1";
            mem_addr_o <= mem_addr_o + '1';
            mem_data_o <= (others => '0');
            mem_wren_o <= '1';
            if ( mem_addr_o = x"FFFE" ) then
                mem_addr_finished_out <= (others => '1');
                state <= waiting;
            end if;
            --
        when waiting =>
            stateout(3 downto 0) <= x"2";
            --LOOP link mux take the last one for prio
            link_mux:
            FOR i in 0 to NLINKS - 1 LOOP
                if ( i_link_enable(i)='1'
                    and link_data(i).data(7 downto 0) = x"BC"
                    and link_data(i).datak = "0001"
                    and link_data(i).data(31 downto 26) = "000111"
                ) then
                    mem_addr_o <= mem_addr_o + '1';
                    mem_data_o <= link_data(i).data;
                    mem_wren_o <= '1';
                    state <= starting;
                    current_link <= i;
                    end if;
            END LOOP;

        when starting =>
            stateout(3 downto 0) <= x"3";
            if ( link_data(current_link).datak = "0000" ) then
                mem_addr_o <= mem_addr_o + '1';
                mem_data_o <= link_data(current_link).data;
                mem_wren_o <= '1';
            elsif ( link_data(current_link).data(7 downto 0) = x"9C" and link_data(current_link).datak = "0001" ) then
                mem_addr_o <= mem_addr_o + '1';
                mem_addr_finished_out <= mem_addr_o + '1';
                mem_data_o <= link_data(current_link).data;
                mem_wren_o <= '1';
                state <= waiting;
            end if;
            --
        when others =>
            stateout(3 downto 0) <= x"E";
            mem_data_o <= (others => '0');
            mem_wren_o <= '0';
            state <= waiting;
            --
        end case;

    end if;
    end process;

end architecture;
