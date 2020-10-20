library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_secondary is
    generic(
        SS      : std_logic ; -- := '1' ;  -- Sensivität bei der der ss reagieren soll
        Del     : integer := 0 ; -- Zeit zwischen gesendeter und empfangenden Daten
        R       : std_logic ;--:= '1'; -- when (r/w = R) => read || when (r/w != R) => write
        lanes   : integer --:= 4 --; -- verfügbare Lanes  nur 2 oder 4 möglich  -- BUG für 4 muss noch etwas manuell einbezogen werden State : Read
        );
    port(
        --LED
        --o_led		: out std_logic_vector(7 downto 0);
        
        --CLK , reset , next , command
        --i_clk_50	: in  std_logic;
        --i_reset_n	: in  std_logic;
        --i_command	: in  std_logic_vector(15 downto 0); --[15-9] empty ,[8-2] cnt , [1] rw , [0] aktiv, 

        ------ Max Data --register interface 
        o_Max_rw    : out   std_logic;
        o_Max_data  : out   std_logic_vector(31 downto 0);
        o_Max_addr_o: out   std_logic_vector(6 downto 0);
        o_b_addr    : out   std_logic_vector (7 downto 0); -- command adrr.
        --o_Ar_done	: out std_logic;
        i_Max_data  : in    std_logic_vector(31 downto 0);

        ------ SPI
        i_SPI_cs    : in    std_logic;
        i_SPI_clk   : in    std_logic;
        io_SPI_mosi : inout std_logic;
        io_SPI_miso : inout std_logic;
        io_SPI_D1   : inout std_logic;
        io_SPI_D2   : inout std_logic;
        io_SPI_D3   : inout std_logic--;
);
end entity;

architecture rtl of spi_secondary is

    type State_type is (Idle, Adrr , W_Data , Deley , R_Data );
    signal State : State_type;

    type s_regs is Array (0 to (lanes-1)) of std_logic_vector(((32/lanes)-1) downto 0);
    signal s_r_reg_16	: s_regs ; --shift register read SPI Slave
    signal s_reg_16		: s_regs ; --shift register write SPI Slave

    type s_addr_regs	is Array (0 to (lanes-1)) of std_logic_vector(((16/lanes)-1) downto 0);
    signal s_addr_reg	:s_addr_regs; -- shift address register

    -- input signal -> vector for 2/4 lanes
    signal io_SPI_D    : std_logic_vector(3 downto 0);
    signal cnt_8		: integer range 0 to (16/lanes) ; -- addr  cnt
    signal cnt_del		: integer range 0 to 64; -- delay cnt
    signal cnt_16		: integer range 0 to (32/lanes)+1 := 0 ; -- read cnt --BUG muss warum kommt er über 16 mit dem cnt ?
    signal cnt_words	: unsigned (6 downto 0):="0000000";
    signal cnt_words_test : std_logic_vector(6 downto 0);
    signal setup 		: std_logic := '1';
	signal addr_offset	: unsigned(6 downto 0);
    
	signal aktiv		: std_logic;
	signal rw 			: std_logic := '0';
	signal ss_del		: std_logic;
	
	------ Aria Register -----
	
    signal i_command	:   std_logic_vector(15 downto 0); --[15-9] empty ,[8-2] cnt , [1] rw , [0] aktiv, 
	 
	 ----- Adrr out ----	
-- 	 signal o_b_addr	: std_logic_vector (7 downto 0); -- command adrr.
	
	------ Max Data --register interface 
-- 	signal o_Max_rw		:  std_logic := R;
-- 	signal o_Max_data	:  std_logic_vector(31 downto 0);
-- 	signal o_Max_addr_o	:  std_logic_vector(6 downto 0);
-- 	signal o_Ar_done	:  std_logic;
-- 	
-- 	signal i_Max_data	:   std_logic_vector(31 downto 0);
	--signal i_Max_addr	:   std_logic_vector(15 downto 0);

begin
	
	--commands
    rw_Max_2 : if lanes = 2 generate
        rw <= s_addr_reg(1)(0) ;
        o_b_addr <= s_addr_reg(1)(7 downto 0);
        io_SPI_D2  <= 'Z';
        io_SPI_mosi <= 'Z';
	end generate;
    rw_Max : if lanes = 4 generate
        o_b_addr(7 downto 4) <= s_addr_reg(2)(3 downto 0) ;
        o_b_addr(3 downto 0) <= s_addr_reg(3)(3 downto 0) ;
        rw <= s_addr_reg(3)(0) ;
    end generate;

    -- 2/4 lane Imput
	io_SPI_D(0)	<= io_SPI_mosi;
	io_SPI_D(1) <= io_SPI_D1; -- when State /= R_Data;  --BUG Synetesiert das als Flipflop
	io_SPI_D(2) <= io_SPI_D2; --when State /= R_Data;
	io_SPI_D(3) <= io_SPI_miso; --when State /= R_Data;
	
	
	
	io_SPI_mosi 	<= s_r_reg_16(0)((32/lanes)-1) when State = R_Data else 'Z';
	io_SPI_D1		<= s_r_reg_16(1)((32/lanes)-1) when State = R_Data else 'Z';
	quad : if lanes = 4 generate
		io_SPI_D2	<= s_r_reg_16(2)((32/lanes)-1) when State = R_Data else 'Z';
--    io_SPI_miso <= s_r_reg_16(3)((32/lanes)-1) when State = R_Data else 'Z';
	end generate;
	
	
process(i_SPI_clk  , i_SPI_cs)
begin

	if (i_SPI_cs = not SS) then
		State <= Idle;
	
	elsif(rising_edge(i_SPI_clk)) then
	
	o_Max_addr_o <= std_logic_vector(addr_offset);
	
		CASE State is
			
			When Idle =>
				setup <= '0';
				
                for i in 0 to lanes-1 loop
                    --s_reg_16(i)(0) <= io_SPI_D(i);
                    s_addr_reg(i)(0) <= io_SPI_D(i);
                end loop;
				
				if setup = '0' then
				
                    for i in  0 to (lanes -1) loop                 --schiebe regeister von 0->15
                        for j in  1 to (16/lanes)-1 loop
                            s_addr_reg(i)(j) <= s_addr_reg(i)(j-1);
                        end loop;
                    end loop;
				
					setup <= '1' ;
					State   <= Adrr;
					--s_reg_16(0)(0) <= i_SPI_mosi;                   --input
				end if;
				
				cnt_16 	<= 1;
				cnt_8 	<= 2;
				cnt_del <= 0;
				o_Max_data      <= X"00000000";
				addr_offset     <= "0000000";
				o_Max_rw        <= R;		
				--o_b_addr			 <= X"00";
                
			When Adrr => 
				
                if cnt_8 /= (16/lanes) then
                    cnt_8 <= cnt_8 + 1;
                    
                    --s_reg_16(0)(0) <= i_SPI_mosi;                   --input
                    for i in 0 to lanes-1 loop
                        --s_reg_16(i)(0) <= io_SPI_D(i);
                        s_addr_reg(i)(0) <= io_SPI_D(i);
                    end loop;
              
                    for i in  0 to (lanes -1) loop                 --schiebe regeister von 0->15
                        --for j in  1 to (32/lanes)-1 loop
                        --s_reg_16(i)(j) <= s_reg_16(i)(j-1);
                        for j in  1 to (16/lanes)-1 loop
                            s_addr_reg(i)(j) <= s_addr_reg(i)(j-1);
                        end loop;
                    end loop;
                
                elsif rw = R then
                    
                    --for i in 0 to (lanes -1) loop
                    --    s_r_reg_16(i) <= i_Max_data((32-32/lanes*i)-1 downto (32-32/lanes*(i+1)));
                    --end loop;
                
                    State <= Deley;
                    --addr_offset <= addr_offset + 1 ;
                else
                    State <= W_Data;
                    --s_reg_16(0)(0) <= i_SPI_mosi;
                    for i in 0 to lanes-1 loop
                            s_reg_16(i)(0) <= io_SPI_D(i);
                    end loop;
                end if;	
                
                if i_SPI_cs = not SS then
                    State <= Idle;
                    cnt_16 	<= 1;
                    cnt_8 	<= 0;
                    cnt_del <= 0;
                    o_Max_data      <= X"00000000";
                    addr_offset     <= "0000000";
                    o_Max_rw        <= R;
                end if;
				
			When W_Data =>
				cnt_16 <= cnt_16 +1;
				o_Max_rw <= R;
				
				--s_reg_16(0)(0) <= i_SPI_mosi;               --input
				for i in 0 to lanes-1 loop
					s_reg_16(i)(0) <= io_SPI_D(i);
            end loop;
                
				for i in  0 to (lanes -1) loop              --schiebe register 0->15
					for j in  1 to (32/lanes)-1 loop
						s_reg_16(i)(j) <= s_reg_16(i)(j-1);
					end loop;
				end loop;
				
				if cnt_16 = (32/lanes) then
					cnt_16 <= 1;
					addr_offset <= addr_offset + 1 ;
					o_Max_rw <= not R;
					for i in  0 to (lanes -1) loop
						o_Max_data((31-32/lanes*i) downto (32-32/lanes*(i+1))) <= s_reg_16(i);
					end loop;			
				end if;
				
				if i_SPI_cs = not SS then
					State <= Idle;
					cnt_16 	<= 1;
					cnt_8 	<= 0;
					cnt_del <= 0;
					o_Max_data      <= X"00000000";
					addr_offset     <= "0000000";
					o_Max_rw        <= R;
				end if;
			
			When Deley =>
				if cnt_del /= Del then
					cnt_del <= cnt_del +1;
				else
					State <= R_Data;
                    for i in  0 to (lanes -1) loop
                        s_r_reg_16(i) <= i_Max_data((31-32/lanes*i) downto (32-32/lanes*(i+1))) ;
					end loop;
					addr_offset <= addr_offset +1;
				end if;
				
            if i_SPI_cs = not SS then
                    State <= Idle;
						  cnt_16 	<= 1;
							cnt_8 	<= 0;
							cnt_del <= 0;
							o_Max_data      <= X"00000000";
							addr_offset     <= "0000000";
							o_Max_rw        <= R;
				end if;
				
			When R_Data =>
				cnt_16 <= cnt_16 +1;
				for i in  0 to (lanes -1) loop
					for j in  1 to (32/lanes)-1 loop
						s_r_reg_16(i)(j) <= s_r_reg_16(i)(j-1);
					end loop;
				end loop;
				if cnt_16 = (32/lanes) then
                    for i in  0 to (lanes -1) loop
                        s_r_reg_16(i) <= i_Max_data((31-32/lanes*i) downto (32-32/lanes*(i+1))) ;
					end loop;
					addr_offset <= addr_offset + 1 ;
					cnt_16 <= 1;
             end if;
					
				if i_SPI_cs = not SS then
					  State <= Idle;
					  cnt_16 	<= 1;
						cnt_8 	<= 0;
						cnt_del <= 0;
						o_Max_data      <= X"00000000";
						addr_offset     <= "0000000";
						o_Max_rw        <= R;
				 end if;
					 
			When others =>
				State <= Idle;
				
		end CASE;
	end if;
end process;


---- SPI TEST ----

-- 	Speicher : work.Max10_Speicher
-- 	generic map( R 	=> R )
-- 	port map (
				--imput
-- 		i_rom_b_addr	=> o_b_addr,
-- 		i_rom_raddr	 	=> o_Max_addr_o,
-- 		i_rom_rdata 	=> o_Max_data,
-- 		i_rw				=> o_Max_rw,
		
		--output 
--		o_rom_rdata		=> i_Max_data,
		
		--clock
--		i_clock 			=> i_SPI_clk--,
		--i_reset_n	: in 	std_logic--;
--	);
	
---- SPI TEST ----


end rtl;
