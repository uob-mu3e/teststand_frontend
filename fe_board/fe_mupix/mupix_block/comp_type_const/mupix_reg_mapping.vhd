-- Last Change: M.Mueller, November 2020 (muellem@uni-mainz.de)
-- there are TWO instances of this entity: one in mp_block, one in mp_datapath
-- TODO: check if things are compiled away correctly in 2nd instance_name .. if not --> new file mupix_reg_mapping_datapath.vhd

-- At some point we might want to generate this file automatically from mupix_registers.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.daq_constants.all;
use work.mupix_constants.all;
use work.mupix_registers.all;

entity mupix_reg_mapping is
port (
    i_clk156                    : in  std_logic;
    i_reset_n                   : in  std_logic;

    i_reg_add                   : in  std_logic_vector(7 downto 0);
    i_reg_re                    : in  std_logic;
    o_reg_rdata                 : out std_logic_vector(31 downto 0);
    i_reg_we                    : in  std_logic;
    i_reg_wdata                 : in  std_logic_vector(31 downto 0);

    -- inputs  156--------------------------------------------
    -- ALL INPUTS DEFAULT TO (n*4-1 downto 0 => x"CCC..", others => '1')
    i_lvds_data_valid           : in std_logic_vector(35 downto 0) := x"CCCCCCCCC"; -- lvds alignment to mupix chips ok

    -- outputs 156--------------------------------------------
    o_mp_datagen_control        : out std_logic_vector(31 downto 0)--; -- control register for the mupix data gen 
    
);
end entity;

architecture rtl of mupix_reg_mapping is
    signal mp_datagen_control : std_logic_vector(31 downto 0);

begin

    o_mp_datagen_control <= mp_datagen_control;

    process (i_clk156, i_reset_n)
        variable regaddr : integer;
    begin 
        if (i_reset_n = '0') then 
            mp_datagen_control        <= (others => '0');
            
        elsif(rising_edge(i_clk156)) then
            regaddr             := to_integer(unsigned(i_reg_add(7 downto 0)));
            o_reg_rdata         <= x"CCCCCCCC";

            -- READ regs
            if ( regaddr = MP_LVDS_DATA_VALID_REGISTER_R and i_reg_re = '1' ) then
                o_reg_rdata <= i_lvds_data_valid(31 downto 0);
            end if;
            if ( regaddr = MP_LVDS_DATA_VALID2_REGISTER_R and i_reg_re = '1' ) then
                o_reg_rdata(3 downto 0) <= i_lvds_data_valid(35 downto 32);
            end if;

            -- WRITE regs
            if ( regaddr = MP_DATA_GEN_CONTROL_REGISTER_W and i_reg_we = '1' ) then
                mp_datagen_control <= i_reg_wdata;
            end if;
            if ( regaddr = MP_DATA_GEN_CONTROL_REGISTER_W and i_reg_re = '1' ) then
                o_reg_rdata <= mp_datagen_control;
            end if;

        end if;
    end process;
end architecture;
