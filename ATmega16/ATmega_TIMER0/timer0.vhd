-------------------------------------------------------------------------------
-- 
-- Copyright (C) 2016 Jacek Binkul
-- 
--  This code is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This code is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this code (see the file named COPYING).
--  If not, see http://www.gnu.org/licenses/.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Module Name:    timer0 - Behavioral 
-- Create Date:    12:46:00 15/07/2016 
-- Description:    the timer of a CPU (Timer0 Atmega16).
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Registers: 
-- TCCRO (0x53) bits 2-0 - prescaler 000 - Stop timer
--												 001 - 1
--												 010 - 8
--												 011 - 64
--												 100 - 256
--												 101 - 1024
--												 110 - T0 falling
--												 111 - T0 rising
-- TCNT0 (0x52) - counter value
-- TIMSK (0x59) bit 0 - TOIE0 OVERFLOW interrupt enable bit
-- TIFR (0x58) bit 0 - TOV0 interrupt - if I-bit and TOIE0-bit are set, then TOVO-bit
-- is set, when interrupt occurs.
-- SFIOR (0x50) bit 0 - Reset the prescaler
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.common.ALL;
use work.Atmega16_reg.All;

entity timer0 is
    port (  I_CLK       : in  std_logic;
				I_CLR			: in  std_logic;
				I_T0			: in  std_logic;									-- external clock

            I_ADR_IO    : in  std_logic_vector( 7 downto 0);		
            I_DIN       : in  std_logic_vector( 7 downto 0);		
            I_WE_IO     : in  std_logic;									
				I_TCCR0		: in  std_logic_vector( 6 downto 0);
				I_TIMSK		: in  std_logic_vector( 1 downto 0);

			   I_Int_Ack	: in  std_logic;									-- int ack
			   I_Int_Vect	: in  std_logic_vector( 4 downto 0);		-- vector for int ack				

				Q_OC0			: out std_logic;									-- OC0 pin for PWM
            Q_TCNT0     : out std_logic_vector( 7 downto 0);
 				Q_OCR0		: out std_logic_vector( 7 downto 0);
				Q_TOV0		: out std_logic;
				Q_OCF0		: out std_logic;
            Q_INT_TOV0 	: out std_logic;
				Q_INT_OCF0	: out std_logic);
end timer0;

architecture Behavioral of timer0 is

component TC0_divider
    port (  I_CLK       : in  std_logic;
				I_CLR			: in  std_logic;
				I_T0			: in  std_logic;

            I_ADR_IO    : in  std_logic_vector( 7 downto 0);
            I_DIN_0     : in  std_logic;
            I_WE_IO     : in  std_logic;
				I_CS			: in  std_logic_vector( 2 downto 0);

            Q_TC0_Clk   : out std_logic);
end component;

signal D_TCO_En				: std_logic;


signal L_TCNT0 				: std_logic_vector( 7 downto 0);		-- TCNT0 register
signal L_TCNT0_old			: std_logic_vector( 7 downto 0);		-- TCNT0 old value
signal L_TCNT0_next			: std_logic_vector( 7 downto 0);		-- TCNT0 next value (combinatory)
signal L_TCNT0_Set			: std_logic;								-- '1' when I_ADR_IO = x"52" and I_WE_IO = '1' else '0'
signal L_TCNTO_Dir			: std_logic; 								-- '1' counting up, '0' counting down
signal L_OCR0_Set				: std_logic;								-- '1' when I_ADR_IO = x"5C" and I_WE_IO = '1' else '0'
signal L_OCR0					: std_logic_vector( 7 downto 0);		-- OCR0 register
signal L_OCR0_bufor			: std_logic_vector( 7 downto 0);		-- double buffering for OCR0 PWM mode
signal L_OCR0_mark			: std_logic;								-- '1' - copy OCR0 value from buffer to register together with L_OCR0_PWM_set
signal L_OCR0_PWM_set		: std_logic;								-- '1' - copy OCR0 value from buffer to register together with L_OCR0_mark
signal L_WaveMode				: std_logic_vector( 1 downto 0); 	-- WGM01 & WGM00
signal L_OCR0_FOC				: std_logic;								-- '1' when I_ADR_IO = x"53" and I_WE_IO = '1'  and I_DIN(FOC0) = '1' else '0'
signal L_OCR0_catch			: std_logic;								-- '1' when L_OCR0 = L_TCNT0 else '0'
signal L_OCR0_mode			: std_logic_vector( 3 downto 0); 	-- WGM01 & WGM00 & COM01 & COM00
signal L_OCR0_com				: std_logic;								-- '1' when L_OCR0 = L_TCNT0_next else '0'
signal L_OCR0_top				: std_logic;								-- '1' when L_OCR0 = 255
signal L_OCR0_bottom			: std_logic;								-- '1' when L_OCR0 = 0
signal L_OC0					: std_logic;								-- pin OC0
signal L_OC0_neg				: std_logic;								-- pin OC0 neg
signal L_TOV0					: std_logic;								-- TIFR TOV0
signal L_OCF0					: std_logic;								-- TIFR OCF0

begin
	
	-- clock divider component
	--
	TCO_clk : TC0_divider
   port map(  	I_CLK       => I_CLK,
					I_CLR			=> I_CLR,
					I_T0			=> I_T0,

					I_ADR_IO    => I_ADR_IO,
					I_DIN_0     => I_DIN(PSR10),
					I_WE_IO     => I_WE_IO,
					I_CS			=> I_TCCR0(CS02 downto CS00),
				
					Q_TC0_Clk   => D_TCO_En);

	
	-- OCR0 input/refresh - double buffering
	--
	L_WaveMode			<= I_TCCR0(WGM01) & I_TCCR0(WGM00);
	L_OCR0_Set			<= '1' when I_ADR_IO = x"5C" and I_WE_IO = '1' else '0';
	L_OCR0_catch 		<= '1' when L_OCR0 = L_TCNT0 else '0';
	L_OCR0_PWM_set		<= '1' when (L_WaveMode = "01" and L_TCNT0_next = x"FF") or (L_WaveMode = "11" and L_TCNT0_next = x"00") else '0';
	
	process (I_CLK)
	begin
		if (rising_edge(I_CLK)) then
			if (I_CLR = '1') then																	
				L_OCR0			<= (others => '0');
				L_OCR0_bufor	<= (others => '0');
				L_OCR0_mark		<= '0';
			else
				if L_OCR0_Set = '1' then
					if L_WaveMode = "00" or L_WaveMode = "10" or L_OCR0_PWM_set = '1' then			-- MODE 0 and 2 immediately, 1 and 3 only when MAX or Bottom
						L_OCR0			<= I_DIN;
						L_OCR0_mark		<= '0';
					else
						L_OCR0_bufor	<= I_DIN;																	-- in any others condition write to bufor and set marker
						L_OCR0_mark		<= '1';
					end if;
				else
					if L_OCR0_PWM_set = '1' and L_OCR0_mark = '1' then										-- MODE 1 and 3 double buffering
						L_OCR0			<= L_OCR0_bufor;
						L_OCR0_mark		<= '0';
					else
						null;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	
	-- TC0 operation - the clock is synchronized with I_CLK
	--
	L_OCR0_FOC		<= '1' when I_ADR_IO = x"53" and I_WE_IO = '1' and I_DIN(FOC0) = '1' else '0';
	L_TCNT0_Set		<= '1' when I_ADR_IO = x"52" and I_WE_IO = '1' else '0';
	L_OCR0_top		<= '1' when L_OCR0 = x"FF" else '0';
	L_OCR0_bottom	<= '1' when L_OCR0 = x"00" else '0';
	L_OCR0_mode		<= L_WaveMode & I_TCCR0(COM01) & I_TCCR0(COM00);
	L_OCR0_com		<= '1' when L_OCR0 = L_TCNT0_next else '0';
	L_TCNT0_next	<= (others => '0') 	when L_WaveMode = "10" and L_OCR0_catch = '1' else
							L_TCNT0 - 1 		when L_WaveMode = "01" and L_TCNTO_Dir	= '0' else
							L_TCNT0 + 1;

	process (I_CLK, I_CLR)
	begin
		if (I_CLR = '1') then																		-- clr timer
			L_TCNT0			<= (others => '0');
			L_TCNTO_Dir		<= '1';
			L_OC0 			<= '0';
			L_TCNT0_old		<= (others => '0');
			
		else			
			if rising_edge(I_CLK) then
			
				-- to catch TOV and OCR0 interrupts
				L_TCNT0_old <= L_TCNT0;
			
				--refresh timer - new value Highest priority
				if L_TCNT0_Set = '1' then
					L_TCNT0			<= I_DIN;
				else					
					if D_TCO_En = '1' then
					
						-- counter operation
						L_TCNT0			<= L_TCNT0_next;															-- TCNT0 next value
						if L_TCNT0_next = x"FF" then																-- set direction when TCNT0=FF or 00
							L_TCNTO_Dir	<= '0';
						elsif L_TCNT0_next = x"00" then
							L_TCNTO_Dir	<= '1';				
						else
							null;
						end if;
						-- end counter operation
					
						-- OC0 operation and OC0=TCNT0 - WGM01 & WGM00 & COM01 & COM00
						if L_OCR0_mode(3 downto 2) = "00" or L_OCR0_mode(3 downto 2) = "10" then	-- * mode Normal or CTC
							if  L_OCR0_mode(1 downto 0) = "01" and L_OCR0_com = '1' then				-- Toggle
								L_OC0	<= not L_OC0;							
							elsif L_OCR0_mode(1 downto 0) = "10" and L_OCR0_com = '1' then				-- Clr
								L_OC0	<= '0';				
							elsif L_OCR0_mode(1 downto 0) = "11" and L_OCR0_com = '1' then				-- Set
								L_OC0	<= '1';											
							elsif L_OCR0_FOC = '1' then															-- if FOC0=1 the Toggle
								L_OC0	<= not L_OC0;														
							else
								null;
							end if;
						
						elsif L_OCR0_mode(3 downto 2) = "11" then												-- * FAST PWM Clr/Set on compare, Set/Clr on bottom
							if L_OCR0_mode(1) = '1' then															-- both COM10 - "10" and "11"
								if L_OCR0_top = '1' then															-- OCR0=FF => '1'
									L_OC0	<= '1';
								elsif L_OCR0_bottom = '1' then													-- OCR0=00 => '1' on TCNT0=0, else '0'
									if L_TCNT0 = x"00" then
										L_OC0	<= '1';
									else
										L_OC0	<= '0';									
									end if;									
								else																						-- OCR0>00 and <FF
									if L_OCR0_com = '1' then														-- Clr on compare
										L_OC0	<= '0';
									elsif L_TCNT0_next = x"00" then												-- Set on bottom
										L_OC0	<= '1';
									else
										null;
									end if;
								
								end if;
							else
								null;
							end if;
						
						elsif L_OCR0_mode(3 downto 2) = "01" then												-- * Phase Correct PWM Clr/Set on compare UP, Set/Clr on Compare Down
							if L_OCR0_mode(1) = '1' then															-- both COM10 - "10" and "11"
								if L_OCR0_top = '1' then															-- OCR0=FF => '1'
									L_OC0	<= '1';
								elsif L_OCR0_bottom = '1' then													-- OCR0=00 => '0'
									L_OC0	<= '0';									
								else																						-- OCR0>00 and <FF
									if L_OCR0_com = '1' then
										if L_TCNTO_Dir = '1' then													-- if OCR0=TCNT0 UP => '0'
											L_OC0	<= '0';								
										else																				-- if OCR0=TCNT0 Down => '1'
											L_OC0	<= '1';													
										end if;
									else
										null;
									end if;
								end if;
							else
								null;
							end if;

						else
							null;										
						end if;
						-- end of OC0 operation

					else
						
						if L_OCR0_mode(2) = '0' and L_OCR0_FOC = '1' then										-- in any situation CTC/Normal toggle if FOC0=1
							L_OC0	<= not L_OC0;
						else
							null;
						end if;
						
					end if; --if L_TCO_Clk = '0' and D_TCO_Clk = '1' then
				end if; --if L_TCNT0_Set = '1' then
			end if; --if (rising_edge(D_TCO_Clk)) then
		end if;
	end process;


	-- TIFR TOV0 and OCF0 process
	--
   TIFR_proc: process(I_CLK)
   begin
		if (rising_edge(I_CLK)) then
			if (I_CLR = '1') then
				L_TOV0	<= '0';
				L_OCF0	<= '0';
         else
				-- OCF0
				if ((I_Int_Ack = '1' and I_Int_Vect = OCF0_int_vec) or (I_WE_IO = '1' and I_ADR_IO = TIFR and I_DIN(6) = '1')) then
					L_OCF0 <= '0';
				elsif L_OCR0_com = '1' then
					L_OCF0 <= '1';
				end if;

				-- TOV0
				if ((I_Int_Ack = '1' and I_Int_Vect = TOV0_int_vec) or (I_WE_IO = '1' and I_ADR_IO = TIFR and I_DIN(7) = '1')) then
					L_TOV0 <= '0';
				elsif L_TCNT0_old = x"FF" and L_TCNT0 = x"00" then
					L_TOV0 <= '1';
				end if;
			end if;
		end if;
	end process;
	
	
	-- outputs
	--
	L_OC0_neg	<= not L_OC0; -- negative for Fast PWM and Phase correct
	Q_TCNT0 		<= L_TCNT0;
	Q_OCR0		<= L_OCR0;
	Q_OC0			<= L_OC0_neg when L_OCR0_mode(2 downto 0) = "111" else L_OC0;
	Q_TOV0		<= L_TOV0;
	Q_OCF0		<= L_OCF0;
	
	
	-- generate overflow interrupt timer (vector 0x009), when TC0 value change from "FF" to "00" (UP, DOWN)
	--
	Q_INT_TOV0 <= '1' when L_TOV0 = '1' and I_TIMSK(TOIE0) = '1' else '0'; 
	
	
	-- generate output compare interrupt (vector 0x013), when Q_OCR0 is equal to Q_TCNT0
	--
	Q_INT_OCF0 <= '1' when L_OCF0 = '1' and I_TIMSK(OCIE0) = '1' else '0';
	
end Behavioral;




-- ***************************************** Clock divider, clock synchronisation **************************************************
-------------------------------------------------------------------------------
--
-- Registers: 
-- TCCRO (0x53) bits 2-0 - prescaler 000 - Stop timer
--												 001 - 1
--												 010 - 8
--												 011 - 64
--												 100 - 256
--												 101 - 1024
--												 110 - T0 falling
--												 111 - T0 rising
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity TC0_divider is 
    port (  I_CLK       : in  std_logic;
				I_CLR			: in  std_logic;
				I_T0			: in  std_logic;									-- external clock

            I_ADR_IO    : in  std_logic_vector( 7 downto 0);		--
            I_DIN_0     : in  std_logic;									-- only for SFIOR(0) Input
            I_WE_IO     : in  std_logic;									--
				I_CS			: in  std_logic_vector( 2 downto 0);		-- only CS02-CS00

            Q_TC0_Clk   : out std_logic);
end TC0_divider;

architecture Behavioral of TC0_divider is

signal L_Count					: std_logic_vector( 9 downto 0);		-- counter
signal L_Timer0_div			: std_logic_vector( 9 downto 0);		-- divider
signal L_Timer0_en			: std_logic;								-- TC0 Enable signal after prescaler
signal L_T0_Shift				: std_logic_vector( 2 downto 0);		-- IT0 synchronisation
signal L_T0_Ris				: std_logic;								--
signal L_T0_Fall				: std_logic;								--

begin

	-- Prescaler and synchronisation process
	--
	process (I_CLK)
	begin
		if (rising_edge(I_CLK)) then
			if (I_CLR = '1') then			
				L_Count					<= (others => '0');
				L_T0_Shift				<= (others => '0');
				L_Timer0_en				<= '0';
			else
				-- default value
				L_Timer0_en				<= '0';
				
				-- increase prescaler or prescaler reset
				if I_ADR_IO = x"50" and I_WE_IO = '1' and I_DIN_0 = '1' then					-- SFIOR(0) - PSR10 prescaler reset
					L_Count 				<= (others => '0');
				else
					if L_Count >= L_Timer0_div then
						L_Count 			<= (others => '0');
						L_Timer0_en		<= '1';
					else
						L_Count			<= L_Count + 1;
					end if;
				end if;
								
				-- synchronise I_T0
				L_T0_Shift	<= L_T0_Shift(1 downto 0) & I_T0;
				
			end if;
		end if;
	end process;
	
	L_T0_Ris		<= '1' when L_T0_Shift = "011" else '0';
	L_T0_Fall	<= not L_T0_Ris;

	-- MUX for prescalers
	--
	with I_CS select
		L_Timer0_div <= 	"0000000111"	 	when "010",				-- pres = 8
								"0000111111"	 	when "011",				-- pres = 64
								"0011111111" 		when "100",				-- pres = 256
								"1111111111" 		when "101",				-- pres = 1024
								"0000000000"		when others;			-- w pozosta�ych '0'

	-- MUX for clock source
	--
	with I_CS select
		Q_TC0_Clk 	<= '0' 						when "000",				-- stop clock
							'1' 						when "001",				-- prescaler 1
							L_T0_Fall				when "110",				-- falling T0
							L_T0_Ris					when "111",				-- rising T0
							L_Timer0_en				when others;			-- prescalers 8-1024
	
	
end Behavioral;
