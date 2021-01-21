-----------------------------------------------------------------------------
-- Converting merged data to 256 link to farm
--
-- Marius Koeppel, JGU Mainz
-- mkoeppel@uni-mainz.de
--
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.dataflow_components.all;


entity data_merger_swb is
    generic (
        NLINKS : positive := 8;
        -- Data type: x"01" = pixel, x"02" = scifi, x"03" = tiles
        DT     : std_logic_vector(7 downto 0) := x"01"--;
    );
    port (
        i_reset_n   : in std_logic;
        i_clk       : in std_logic;

        i_data      : in std_logic_vector(NLINKS * 38 - 1 downto 0);
        i_empty     : in std_logic;

        i_swb_id    : in std_logic_vector(7 downto 0) := x"01";

        o_ren       : out std_logic;
        o_wen       : out std_logic;
        o_data      : out std_logic_vector(NLINKS * 32 - 1  downto 0);
        o_datak     : out std_logic_vector(NLINKS * 4 - 1  downto 0)--;

);
end entity data_merger_swb;

architecture RTL of data_merger_swb is
         
    type merge_state_type is (wait_for_pre, get_ts_1, get_sh, hit_1, hit2, get_tr);
    signal merge_state : merge_state_type;

    signal o_data_reg : std_logic_vector(71 downto 0);
    signal i_data_arr : fifo_array_38(NLINKS - 1 downto 0);
    
begin

    process(i_reset_n, i_reset_n)
    begin
        if ( i_reset_n = '0' ) then
            o_ren       <= '0';
            o_wen       <= '0';
            o_data      <= (others => '0');
            o_data_reg  <= (others => '0');
            o_datak     <= (others => '0');
            hit_reg     <= (others => '0');
            merge_state <= wait_for_pre;
            --
        elsif ( rising_edge(i_clk) ) then

            o_ren       <= '0';
            o_wen       <= '0';
            o_data      <= (others => '0');

            case merge_state is

                when wait_for_pre =>
                    if ( i_data(37 downto 32) = pre_marker and i_data(7 downto 0) = x"BC" and i_empty = '0' ) then
                        merge_state             <= get_ts_1;
                        o_ren                   <= '1';
                        -- reg data
                        o_data_reg(7 downto 0)  <= i_swb_id;
                    end if;
                    FOR I in NLINKS - 1 downto 0 LOOP
                        o_data(I * 32 + 31 downto I * 32)   <= K285;
                        o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        o_wen                               <= '1';
                    END LOOP;

                when get_ts_1 =>
                    if ( i_data(37 downto 32) = ts1_marker ) then
                        merge_state              <= get_ts_2;
                        o_ren                   <= '1';
                        -- reg data
                        o_data_reg(39 downto 8) <= i_data(31 downto 0);
                    end if;
                    FOR I in NLINKS - 1 downto 0 LOOP
                        o_data(I * 32 + 31 downto I * 32)   <= K285;
                        o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        o_wen                               <= '1';
                    END LOOP;

                when get_ts_2 =>
                    -- send out data if ts2 is there
                    -- every link is getting K.28.3 = 7C for pre
                    o_wen <= '1';
                    if ( i_data(37 downto 32) = ts2_marker and i_empty = '0' ) then
                        merge_state              <= get_sh;
                        o_data_reg               <= (others => '0');
                        o_ren                    <= '1';
                        -- 1. link
                        o_data(31 downto 0)      <= o_data_reg(23 downto 0) & x"7C";
                        o_datak(3 downto 0)      <= "0001";
                        -- 2. link
                        o_data(63 downto 40)     <= o_data_reg(47 downto 24)
                        o_data(39 downto 32)     <= x"7C";
                        o_datak(7 downto 4)      <= "0001";
                        -- 3. link
                        o_data(95 downto 72)     <= o_data_reg(71 downto 48);
                        o_data(71 downto 64)     <= x"7C";
                        o_datak(11 downto 8)     <= "0001";
                        -- 4. link
                        o_data(127 downto 104)   <= i_data(23 downto 0);
                        o_data(103 downto 96)    <= x"7C";
                        o_datak(15 downto 12)    <= "0001";
                        -- 5. link
                        o_data(143 downto 136)   <= i_data(31 downto 24);
                        o_data(135 downto 128)   <= x"7C";
                        o_datak(19 downto 16)    <= "0001";
                        -- 6. - 8. link
                        FOR I in NLINKS - 1 downto 5 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K283;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    else
                        FOR I in NLINKS - 1 downto 0 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K285;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    end if;

                when get_sh =>
                    -- send out data if sh is there
                    -- every link is getting K.28.2 = 5C for sh
                    o_wen <= '1';
                    if ( i_data(37 downto 32) = sh_marker and i_empty = '0' ) then
                        merge_state             <= hit_1;
                        o_ren                   <= '1';
                        -- 1. link
                        o_data(31 downto 16)    <= i_data(15 downto 0) & DT & x"5C";
                        -- 2. link
                        o_data(63 downto 32)    <= i_data(31 downto 16) & x"00" & x"5C";
                        -- 3. - 8. link
                        FOR I in NLINKS - 1 downto 2 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K282;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    end if;
                    FOR I in NLINKS - 1 downto 0 LOOP
                        o_data(I * 32 + 31 downto I * 32)   <= K285;
                        o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                    END LOOP;

                -- hits after alignment
                -- 1. hit  =  37 downto   0
                -- 2. hit  =  75 downto  38
                -- 3. hit  = 113 downto  76
                -- 4. hit  = 151 downto 114
                -- 5. hit  = 189 downto 152
                -- 6. hit  = 227 downto 190
                -- 6.5 hit = 246 downto 228
                -- 7. hit  = 265 downto 228
                -- 8. hit  = 303 downto 266
                -- marker => 01 -> 1/2 MSB
                --           10 -> 1/2 LSB
                --           00 -> error
                --           11 -> no 1/2 hits
                when hit_1 =>
                    -- send out hits if fifo is not empty
                    if ( i_empty = '0' ) then
                        if ( i_data(37 downto 32) = pre_marker ) then
                            merge_state <= get_sh;
                        elsif ( i_data(37 downto 32) = sh_marker ) then
                            merge_state <= wait_for_pre;
                        elsif ( i_data(37 downto 32) = tr_marker ) then
                            merge_state <= get_tr;
                        elsif ( i_data(37 downto 32) = err_marker ) then
                            --
                        else
                            merge_state             <= hit_2;
                            o_ren                   <= '1';
                            o_wen                   <= '1';
                            hit_reg                 <= (others => '0');
                            -- 6 hits
                            o_data(227 downto 0)    <= i_data(227 downto 0);
                            -- 1/2 hit
                            o_data(246 downto 228)  <= i_data(246 downto 228);
                            -- marker "01" -> half is MSB
                            o_data(255 downto 254)  <= "01";
                            -- save 1.5 hits
                            hit_reg(56 downto 0)    <= i_data(303 downto 247);
                        end if;

                    else
                        FOR I in NLINKS - 1 downto 0 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K285;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    end if;

                when hit_2 =>
                    -- send out hits if fifo is not empty
                    if ( i_empty = '0' ) then
                        o_wen <= '1';
                        if ( i_data(37 downto 32) = pre_marker ) then
                            merge_state <= get_sh;
                            -- 1/2 hit from reg
                            o_data(18 downto 0)     <= hit_reg(18 downto 0);
                            -- 1 hit from reg
                            o_data(56 downto 19)    <= hit_reg(56 downto 19);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "10" -> half is LSB
                            o_data(255 downto 254)  <= "10";
                        elsif ( i_data(37 downto 32) = sh_marker ) then
                            merge_state <= wait_for_pre;
                            -- 1/2 hit from reg
                            o_data(18 downto 0)     <= hit_reg(18 downto 0);
                            -- 1 hit from reg
                            o_data(56 downto 19)    <= hit_reg(56 downto 19);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "10" -> half is LSB
                            o_data(255 downto 254)  <= "10";
                        elsif ( i_data(37 downto 32) = tr_marker ) then
                            merge_state <= get_tr;
                            -- 1/2 hit from reg
                            o_data(18 downto 0)     <= hit_reg(18 downto 0);
                            -- 1 hit from reg
                            o_data(56 downto 19)    <= hit_reg(56 downto 19);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "10" -> half is LSB
                            o_data(255 downto 254)  <= "10";
                        elsif ( i_data(37 downto 32) = err_marker ) then
                            -- 1/2 hit from reg
                            o_data(18 downto 0)     <= hit_reg(18 downto 0);
                            -- 1 hit from reg
                            o_data(56 downto 19)    <= hit_reg(56 downto 19);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "00" -> half is LSB and error
                            o_data(255 downto 254)  <= "00";
                        else
                            merge_state <= hit_3;
                            o_ren                   <= '1';
                            hit_reg                 <= (others => '0');
                            -- 1/2 hit from reg
                            o_data(18 downto 0)     <= hit_reg(18 downto 0);
                            -- 1 hit from reg
                            o_data(56 downto 19)    <= hit_reg(56 downto 19);
                            -- 5 hits
                            o_data(246 downto 57)   <= i_data(189 downto 0);
                            -- marker "10" -> half is LSB
                            o_data(255 downto 254)  <= "10";
                            -- save 3 hits
                            hit_reg(113 downto 0)   <= i_data(303 downto 190);
                        end if;
                    else
                        FOR I in NLINKS - 1 downto 0 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K285;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    end if;

                when hit_3 =>
                    -- send out hits if fifo is not empty
                    if ( i_empty = '0' ) then
                        o_wen <= '1';
                        if ( i_data(37 downto 32) = pre_marker ) then
                            merge_state             <= get_sh;
                            -- 3 hits from reg
                            o_data(113 downto 0)    <= hit_reg(113 downto 0);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "11" -> no half hits
                            o_data(255 downto 254)  <= "11";
                        elsif ( i_data(37 downto 32) = sh_marker ) then
                            merge_state <= wait_for_pre;
                            -- 3 hits from reg
                            o_data(113 downto 0)    <= hit_reg(113 downto 0);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "11" -> no half hits
                            o_data(255 downto 254)  <= "11";
                        elsif ( i_data(37 downto 32) = tr_marker ) then
                            merge_state <= get_tr;
                            -- 3 hits from reg
                            o_data(113 downto 0)    <= hit_reg(113 downto 0);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "11" -> no half hits
                            o_data(255 downto 254)  <= "11";
                        elsif ( i_data(37 downto 32) = err_marker ) then
                            -- 3 hits from reg
                            o_data(113 downto 0)    <= hit_reg(113 downto 0);
                            -- mark rest of data
                            o_data(253 downto 57)   <= (others => '1');
                            -- marker "00" -> half is LSB and error
                            o_data(255 downto 254)  <= "00";
                        else
                            merge_state <= hit_3;
                            o_ren                   <= '1';
                            hit_reg                 <= (others => '0');
                            -- 3 hits from reg
                            o_data(113 downto 0)    <= hit_reg(113 downto 0);
                            -- 3 hits from data
                            o_data(227 downto 114)  <= i_data(113 downto 0);
                            -- 1/2 hit from data
                            o_data(246 downto 228)  <= i_data(132 downto 114);
                            -- marker "01" -> half is MSB
                            o_data(255 downto 254)  <= "01";
                            -- save 2.5 of the hits
                            hit_reg(94 downto 0)    <= i_data(303 downto 133);
                        end if;
                    else
                        FOR I in NLINKS - 1 downto 0 LOOP
                            o_data(I * 32 + 31 downto I * 32)   <= K285;
                            o_datak(I * 4 + 3 downto I * 4)     <= "0001";
                        END LOOP;
                    end if;
                        

                when others =>
                    merge_state <= wait_for_pre;
                    o_data_reg  <= (others => '0');
                    hit_reg                 <= (others => '0');

            end case;

        end if;
    end process;
    

    end architecture RTL;
