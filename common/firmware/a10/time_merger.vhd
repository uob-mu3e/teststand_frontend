library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.dataflow_components.all;

-- merge packets delimited by SOP and EOP from N input streams
entity time_merger is
generic (
    W : positive := 32;
    TIMEOUT : std_logic_vector(15 downto 0) := x"FFFF";
    N : positive--;
);
port (
    -- input streams
    i_rdata     : in    data_array(N - 1 downto 0);
    i_rsop      : in    std_logic_vector(N-1 downto 0); -- start of packet (SOP)
    i_reop      : in    std_logic_vector(N-1 downto 0); -- end of packet (EOP)
    i_rempty    : in    std_logic_vector(N-1 downto 0);
    i_mask_n    : in    std_logic_vector(N-1 downto 0);
    o_rack      : out   std_logic_vector(N-1 downto 0); -- read ACK

    -- output stream
    o_wdata     : out   std_logic_vector(W-1 downto 0);
    o_wsop      : out   std_logic; -- SOP
    o_weop      : out   std_logic; -- EOP
    i_wfull     : in    std_logic;
    o_we        : out   std_logic; -- write enable

    -- error outputs
    o_error_pre : out std_logic_vector(N - 1 downto 0);
    o_error_sh : out std_logic_vector(N - 1 downto 0);
    o_error_gtime : out std_logic_vector(1 downto 0);
    o_error_shtime : out std_logic;
    
    i_reset_n   : in    std_logic;
    i_clk       : in    std_logic--;
);
end entity;

architecture arch of time_merger is

    type data_array_t is array (N - 1 downto 0) of std_logic_vector(W - 1 downto 0);
    type marker_array_t is array (N - 1 downto 0) of std_logic_vector(1 downto 0);
    type fpga_id_array_t is array (N - 1 downto 0) of std_logic_vector(15 downto 0);
    type sheader_time_array_t is array (N - 1 downto 0) of std_logic_vector(5 downto 0);
    type ram_add_t is array (N - 1 downto 0) of std_logic_vector(7 downto 0);
    type merge_state_type is (wait_for_pre, compare_time1, compare_time2, wait_for_sh, error_state, merge_hits, get_time1, get_time2, trailer);
    
    constant check_zeros : std_logic_vector(N - 1 downto 0) := (others => '0');
    constant check_ones : std_logic_vector(N - 1 downto 0) := (others => '1');
    constant all_zeros : ram_add_t := (others => (others => '0'));

    signal error_gtime1, error_gtime2, error_shtime, w_ack : std_logic;
    signal wait_cnt : std_logic_vector(1 downto 0);
    signal merge_state : merge_state_type;
    signal rack, check_pre, check_sh, check_tr, check_time1, check_time2, error_pre, error_sh, error_tr, cnt_sh_header, cnt_pre_header, cnt_trailer : std_logic_vector(N - 1 downto 0);
    signal saw_marker : marker_array_t;
    signal gtime1, gtime2 : std_logic_vector(31 downto 0);
    signal shtime : std_logic_vector(5 downto 0);
    signal sheader_time : sheader_time_array_t;
    signal fpga_id, wait_cnt_pre, wait_cnt_sh, wait_cnt_tr : fpga_id_array_t;
    signal min_index_reg : integer;
    
    -- ram signals
    signal w_ram_add, r_ram_add : ram_add_t;
    signal w_ram_data, r_ram_data : data_array_t;
    signal w_ram_wren, ram_rack, cnt_ram_wren, r_w_add_equal : std_logic_vector(N - 1 downto 0);
    
    -- merge signals
    signal min_hit : std_logic_vector(37 downto 0);

begin

    generate_rdata : for i in N - 1 downto 0 generate
        
        e_ram : entity work.ip_ram
        generic map (
            ADDR_WIDTH_A    => 8,
            ADDR_WIDTH_B    => 8,
            DATA_WIDTH_A    => 38,
            DATA_WIDTH_B    => 38,
            DEVICE          => "Arria 10"--,
        )
        port map (
            address_a       => w_ram_add(i),
            address_b       => r_ram_add(i),
            clock_a         => i_clk,
            clock_b         => i_clk,
            data_a          => w_ram_data(i),
            data_b          => (others => '0'),
            wren_a          => w_ram_wren(i),
            wren_b          => '0',
            q_a             => open,
            q_b             => r_ram_data(i)--,
        );
        
        o_rack(i) <= rack(i) or ram_rack(i);
        
    end generate;
    
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n /= '1' ) then
        w_ram_add <= (others => (others => '1'));
        cnt_ram_wren <= (others => '0');
        w_ram_data <= (others => (others => '0'));
        w_ram_wren <= (others => '0');
        ram_rack <= (others => '0');
        saw_marker <= (others => (others => '0'));
    elsif rising_edge(i_clk) then
        w_ram_wren <= (others => '0');
        ram_rack <= (others => '0');
        if ( merge_state = merge_hits) then
            FOR I in N - 1 downto 0 LOOP
                -- not empty and not masked, wirte until marker (header, trailer, sub header)
                if ( (i_rdata(I)(37 downto 36) /= "00" or i_rdata(I)(31 downto 26) = "111111") and saw_marker(I) = "00" ) then
                    saw_marker(I) <= "01";
                end if;
                
                if ( (saw_marker(I) = "00" or saw_marker(I) = "01") and i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                    cnt_ram_wren(I) <= '1';
                    -- toggle bcz of showhead fifo
                    if ( ram_rack(I) = '1' ) then
                        --
                    elsif ( saw_marker(I) = "00" ) then
                        ram_rack(I) <= '1';
                        w_ram_add(I) <= w_ram_add(I) + '1';
                        w_ram_data(I) <= i_rdata(I);
                        w_ram_wren(I) <= '1';
                    elsif ( saw_marker(I) = "01" ) then
                        w_ram_add(I) <= w_ram_add(I) + '1';
                        w_ram_data(I) <= i_rdata(I);
                        w_ram_wren(I) <= '1';
                        saw_marker(I) <= "11";
                    end if;
                end if;
            END LOOP;
        else
            cnt_ram_wren <= (others => '0');
            w_ram_add <= (others => (others => '1'));
            saw_marker <= (others => (others => '0'));
        end if;
    end if;
    end process;
    
    o_error_gtime(0) <= error_gtime1;
    o_error_gtime(1) <= error_gtime2;
    o_error_shtime <= error_shtime;
    o_error_pre <= error_pre;
    o_error_sh <= error_sh;
    
    process(i_clk, i_reset_n)
        variable min_value : std_logic_vector(3 downto 0);
        variable min_index : integer;
        variable found_min : std_logic;
    begin
    if ( i_reset_n /= '1' ) then
        merge_state <= wait_for_pre;
        
        check_pre <= (others => '1');
        check_sh <= (others => '1');
        check_tr <= (others => '1');
        check_time1 <= (others => '1');
        check_time2 <= (others => '1');
        error_pre <= (others => '0');
        error_sh <= (others => '0');
        error_tr <= (others => '0');
        wait_cnt_pre <= (others => (others => '0'));
        wait_cnt_sh <= (others => (others => '0'));
        wait_cnt_tr <= (others => (others => '0'));
        fpga_id <= (others => (others => '0'));
        gtime1 <= (others => '1');
        gtime2 <= (others => '1');
        shtime <= (others => '1');
        sheader_time <= (others => (others => '0'));
        error_gtime1 <= '0';
        error_gtime2 <= '0';
        error_shtime <= '0';
        wait_cnt <= "00";
        min_index_reg <= 0;
        min_index := 0;
        found_min := '0';
        w_ack <= '0';
        min_value := (others => '0');
        min_hit <= (others => '0');
        
        cnt_sh_header <= (others => '1');
        cnt_pre_header <= (others => '1');
        cnt_trailer <= (others => '1');
        
        o_wdata <= (others => '0');
        r_ram_add <= (others => (others => '0'));
        r_w_add_equal <= (others => '0');
        rack <= (others => '0');
        o_wsop <= '0';
        o_weop <= '0';
        o_we <= '0';
        --
    elsif rising_edge(i_clk) then
        
        rack <= (others => '0');
        
        o_we <= '0';
        o_wsop <= '0';
        o_weop <= '0';
        o_wdata <= (others => '0');
    
        case merge_state is
            -- readout until all fifos have preamble
            when wait_for_pre =>
                
                if ( check_pre /= check_zeros ) then
                    FOR I in N - 1 downto 0 LOOP
                        if ( wait_cnt_pre(I) = TIMEOUT ) then
                            error_pre(I) <= '1';
                        end if;
                        
                        if ( i_mask_n(I) = '0' ) then
                            check_pre(I) <= '0';
                        elsif ( i_rempty(I) = '0' and i_rdata(I)(35 downto 30) = "111010" and i_rdata(I)(37 downto 36) = "01" and check_pre(I) = '1' ) then
                            check_pre(I) <= '0';
                            fpga_id(I) <= i_rdata(I)(27 downto 12);
                            rack(I) <= '1';
                        elsif ( check_pre(I) = '1' ) then
                            wait_cnt_pre(I) <= wait_cnt_pre(I) + '1';
                            if ( i_rempty(I) = '0' ) then
                                rack(I) <= '1';
                            end if;
                        end if;
                    END LOOP;
                end if;
                
                -- check if fifo is not full and all links have preamble
                if( check_pre = check_zeros and i_wfull = '0' ) then
                    merge_state <= get_time1;
                    -- reset signals
                    wait_cnt_pre <= (others => (others => '0'));
                    check_pre <= (others => '1');
                    -- send merged data preamble
                    -- sop & preamble & zeros & datak
                    o_wdata(37 downto 36) <= "01";
                    o_wdata(35 downto 30) <= "111010";
                    o_wdata(11 downto 4) <= x"BC";
                    o_wdata(3 downto 0) <= "0001";
                    o_we <= '1';
                end if;
                
            when get_time1 =>
                FOR I in N - 1 downto 0 LOOP
                    if ( i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                        merge_state <= compare_time1;
                        gtime1 <= i_rdata(I)(35 downto 4);
                        -- take one for hit merge later
                        min_index_reg <= I;
                        exit;
                    end if;
                END LOOP;
                
            when compare_time1 =>
                if ( error_pre /= check_zeros ) then
                    merge_state <= error_state;
                end if;
                if ( check_time1 /= check_zeros ) then
                    FOR I in N - 1 downto 0 LOOP
                        if ( i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                            if ( i_rdata(I)(35 downto 4) /= gtime1 ) then
                                error_gtime1 <= '1';
                            elsif ( check_time1(I) = '1' ) then
                                -- check gtime
                                check_time1(I) <= '0';
                                rack(I) <= '1';
                            end if;
                        end if;
                    END LOOP;
                end if;
                
                 -- check if fifo is not full and all links have same time
                if ( check_time1 = check_zeros and i_wfull = '0' ) then
                    merge_state <= get_time2;
                    -- reset signals
                    check_time1 <= (others => '1');
                    gtime1 <= (others => '0');
                    -- send gtime1
                    o_wdata(37 downto 36) <= "00";
                    o_wdata(35 downto 4) <= gtime1;
                    o_wdata(3 downto 0) <= "0000";
                    o_we <= '1';
                end if;
                
            when get_time2 =>
                FOR I in N - 1 downto 0 LOOP
                    if ( i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                        merge_state <= compare_time2;
                        gtime2 <= i_rdata(I)(35 downto 4);
                        exit;
                    end if;
                END LOOP;
                
            when compare_time2 =>
                if ( error_gtime1 = '1' ) then
                    merge_state <= error_state;
                end if;
                if ( error_gtime2 = '1' ) then
                    merge_state <= error_state;
                end if;
                if ( check_time2 /= check_zeros ) then
                    FOR I in N - 1 downto 0 LOOP
                        if ( i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                            if ( i_rdata(I)(35 downto 4) /= gtime2 ) then
                                error_gtime2 <= '1';
                            elsif ( check_time2(I) = '1' ) then
                                -- send gtime
                                check_time2(I) <= '0';
                                rack(I) <= '1';
                            end if;
                        end if;
                    END LOOP;
                end if;
                
                -- check if fifo is not full and all links have same time
                if ( check_time2 = check_zeros and i_wfull = '0' ) then
                    merge_state <= wait_for_sh;
                    -- reset signals
                    check_time2 <= (others => '1');
                    gtime2 <= (others => '0');
                    -- send gtime2
                    o_wdata(37 downto 36) <= "00";
                    o_wdata(35 downto 4) <= gtime2;
                    o_wdata(3 downto 0) <= "0000";
                    o_we <= '1';
                end if;
                
            when wait_for_sh =>
                if ( error_gtime2 = '1' ) then
                    merge_state <= error_state;
                elsif ( check_sh /= check_zeros ) then
                    -- check for sub header
                    FOR I in N - 1 downto 0 LOOP
                        if ( wait_cnt_sh(I) = TIMEOUT ) then
                            error_sh(I) <= '1';
                        end if;
                        
                        if ( i_mask_n(I) = '0' ) then
                            check_sh(I) <= '0';
                        elsif ( i_rempty(I) = '0' and i_rdata(I)(31 downto 26) = "111111" and check_sh(I) = '1' ) then
                            check_sh(I) <= '0';
                            sheader_time(I) <= i_rdata(I)(25 downto 20);
                            shtime <= i_rdata(I)(25 downto 20);
                            rack(I) <= '1';
                        elsif ( check_sh(I) = '1' ) then
                            wait_cnt_sh(I) <= wait_cnt_sh(I) + '1';
                            if ( i_rempty(I) = '0' ) then
                                rack(I) <= '1';
                            end if;
                        end if;
                    END LOOP;
                end if;
                
                -- check if fifo is not full and all links have subheader
                if( check_sh = check_zeros and i_wfull = '0' ) then
                    merge_state <= merge_hits;
                    -- reset signals
                    wait_cnt_sh <= (others => (others => '0'));
                    check_sh <= (others => '1');
                    -- send merged data sub header
                    -- zeros & sub header & zeros & datak
                    o_wdata(37 downto 36) <= "00";
                    o_wdata(35 downto 32) <= "0000";
                    o_wdata(31 downto 26) <= "111111";
                    o_wdata(3 downto 0) <= "0001";
                    o_we <= '1';
                    -- check if sheader time is equal
                    FOR I in N - 1 downto 0 LOOP
                        if ( i_rempty(I) = '0' and i_mask_n(I) = '1' ) then
                            if ( sheader_time(I) /= shtime ) then
                                error_shtime <= '1';
                            else
                                -- send sub header time
                                o_wdata(25 downto 20) <= sheader_time(I);
                            end if;
                        end if;
                    END LOOP;
                end if;
                
            when merge_hits =>
                if ( error_shtime = '1' ) then
                    merge_state <= error_state;
                end if;
                found_min := '0';
                -- now address zero is valid
                if ( cnt_ram_wren = check_ones ) then
                    w_ack <= '0';
                    if ( wait_cnt < "10" ) then
                        if ( is_x(r_ram_data(min_index_reg)) ) then
                            wait_cnt <= wait_cnt;
                        else
                            wait_cnt <= wait_cnt + '1';
                        end if;
                    else
                    
                        wait_cnt <= "10";
                        
                        -- get min value and index, set marker cnt
                        FOR I in N - 1 downto 0 LOOP
                            if ( r_ram_add(I) /= w_ram_add(I) and i_mask_n(I) = '1' ) then
                                min_value := r_ram_data(I)(35 downto 32);
                                min_index := I;
                            end if;
                            
                            if ( r_ram_data(I)(37 downto 36) = "01" or cnt_pre_header(I) = '0' ) then
                                cnt_pre_header(I) <= '0';
                            elsif ( r_ram_data(I)(37 downto 36) = "10" or cnt_trailer(I) = '0' ) then
                                cnt_trailer(I) <= '0';
                            elsif ( r_ram_data(I)(31 downto 26) = "111111" or cnt_sh_header(I) = '0' ) then
                                cnt_sh_header(I) <= '0';
                            end if;
                        END LOOP;

                        FOR I in N - 1 downto 0 LOOP
                            if ( r_ram_add(I) = w_ram_add(I) ) then
                                r_w_add_equal(I) <= '1';
                            elsif ( i_mask_n(I) = '1' ) then
                                r_w_add_equal(I) <= '0';
                            end if;
                                
                            if ( i_wfull = '1' or r_ram_data(I)(37 downto 36) /= "00" or r_ram_data(I)(31 downto 26) = "111111"  ) then
                                --
                            elsif ( r_ram_data(I)(35 downto 32) < min_value and r_w_add_equal(I) = '0' ) then
                                min_value := r_ram_data(I)(35 downto 32);
                                min_index := I;
                                found_min := '1';
                            elsif ( cnt_pre_header(I) = '1' or cnt_trailer(I) = '1' or cnt_sh_header(I) = '1' ) then
                                found_min := '1';
                            end if;
                        END LOOP;
                        
                        if ( found_min = '1' ) then
                            if ( r_ram_add(min_index) + '1' > w_ram_add(min_index) ) then
                                --
                            else
                                r_ram_add(min_index) <= r_ram_add(min_index) + '1';
                            end if;
                            -- wait one cycle for start
                            if ( r_ram_add = all_zeros ) then
                                --
                            else
                                 w_ack <= '1';
                            end if;
                            min_hit <= r_ram_data(min_index);
                            min_index_reg <= min_index;
                        end if;
                    
                        if ( w_ack = '1' and min_hit /= x"00000000" & "000000" and min_hit(37 downto 36) = "00" and min_hit(31 downto 26) /= "111111" ) then
                            o_wdata <= min_hit;
                            o_we <= '1';
                        end if;
                    end if;
                end if;
                
                if ( cnt_sh_header = check_zeros and r_w_add_equal = check_ones ) then
                    merge_state <= wait_for_sh;
                    wait_cnt <= "00";
                    r_w_add_equal <= (others => '0');
                    r_ram_add <= (others => (others => '0'));
                    cnt_sh_header <= (others => '1');
                end if;
                
                if ( cnt_pre_header = check_zeros and r_w_add_equal = check_ones ) then
                    merge_state <= wait_for_pre;
                    wait_cnt <= "00";
                    r_w_add_equal <= (others => '0');
                    r_ram_add <= (others => (others => '0'));
                    cnt_pre_header <= (others => '1');
                end if;
                
                if ( cnt_trailer = check_zeros and r_w_add_equal = check_ones ) then
                    merge_state <= trailer;
                    wait_cnt <= "00";
                    r_w_add_equal <= (others => '0');
                    r_ram_add <= (others => (others => '0'));
                    cnt_trailer <= (others => '1');
                end if;
                
            when trailer =>
                if ( check_tr /= check_zeros ) then
                    -- check for trailer
                    FOR I in N - 1 downto 0 LOOP
                        if ( wait_cnt_tr(I) = TIMEOUT ) then
                            error_tr(I) <= '1';
                        end if;
                        
                        if ( i_mask_n(I) = '0' ) then
                            check_tr(I) <= '0';
                        elsif ( i_rempty(I) = '0' and i_rdata(I)(37 downto 36) = "10" and check_tr(I) = '1' ) then
                            check_tr(I) <= '0';
                            rack(I) <= '1';
                        elsif ( check_tr(I) = '1' ) then
                            wait_cnt_tr(I) <= wait_cnt_tr(I) + '1';
                            if ( i_rempty(I) = '0' ) then
                                rack(I) <= '1';
                            end if;
                        end if;
                    END LOOP;
                end if;
                
                -- check if fifo is not full and all links have subheader
                if( check_tr = check_zeros and i_wfull = '0' ) then
                    merge_state <= wait_for_pre;
                    -- reset signals
                    wait_cnt_tr <= (others => (others => '0'));
                    check_tr <= (others => '1');
                    -- send trailer
                    o_wdata(37 downto 36) <= "10";
                    o_wdata(11 downto 4) <= x"9C";
                    o_wdata(3 downto 0) <= "0000";
                    o_we <= '1';
                end if;
                                
            when error_state =>
                -- send error message xxxxxxDC
                -- 12: error gtime1
                -- 13: error gtime2
                -- 14: error shtime
                -- N+14 downto 14: error wait for pre
                o_wdata(3 downto 0) <= "0001";
                o_wdata(11 downto 4) <= x"DC";
                o_wdata(12) <= error_gtime1;
                o_wdata(13) <= error_gtime2;
                o_wdata(14) <= error_shtime;
                o_wdata(N + 14 downto 15) <= error_pre;
                o_we <= '1';
                o_weop <= '1';
                
            when others =>
                merge_state <= wait_for_pre;
                
        end case;
        --
    end if;
    end process;

end architecture;
