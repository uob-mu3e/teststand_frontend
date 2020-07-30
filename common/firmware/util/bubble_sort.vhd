
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity bubblesort is
generic (
    N : integer := 8;
    W : integer := 10--;
);
port (
    i_clk       : in std_logic;
    i_reset_n   : in std_logic;
    i_enable    : in std_logic;
    i_data      : in std_logic_vector(N * W - 1 downto 0);
    o_data      : out std_logic_vector(N * W - 1 downto 0)--; 
);
end entity;

architecture rtl of bubblesort is
   
begin

process (i_clk, i_reset_n)
    variable temp       : std_logic_vector (W - 1 downto 0);
    variable var_array  : std_logic_vector (N * W - 1 downto 0);
begin
    if ( i_reset_n = '0' ) then
        sorted_array <= (others => '0');
    elsif rising_edge(i_clk) then
        var_array := in_array;
        if ( i_enable = '1' ) then
            for j in 0 to N - 1 loop 
                for i in 0 to N - 1 - j loop 
                    if unsigned(var_array((i + 1) * W - 1 downto i * W)) > unsigned(var_array((i + 2) * W - 1 downto (i + 1) * W)) then
                        temp := var_array((i + 1) * W - 1 downto i * W);
                        var_array((i + 1) * W - 1 downto i * W) := var_array((i + 2) * W - 1 downto (i + 1) * W);
                        var_array((i + 2) * W - 1 downto (i + 1) * W) := temp;
                    end if;
                end loop;
            end loop;
        sorted_array <= var_array;
        end if;
    end if;
end process;
end architecture;