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
-- Module Name:    SPI - Behavioral 
-- Create Date:    12:00:00 15/11/2017 
-- Description:    the SPI module of a CPU (SPI Atmega16) - ONLY Master mode.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
-- Registers: 
-- SPCR (0x2D) - Control Register
-- SPSR (0x2E) - Status register
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

use work.common.ALL;
use work.Atmega16_reg.All;

entity spi_master is
    Port ( I_Clk 			: in  STD_LOGIC;									-- max 50MHz for max speed with SD card in SPI mode
           I_Clr 			: in  STD_LOGIC;
           I_MISO 		: in  STD_LOGIC;
           I_ADR_IO  	: in  std_logic_vector( 7 downto 0);
           I_DIN     	: in  std_logic_vector( 7 downto 0);
           I_WE_IO   	: in  std_logic;			  				
			  I_RD_IO		: in  std_logic;
			  I_SPCR			: in  STD_LOGIC_VECTOR( 7 downto 0);
			  I_SPSR			: in  STD_LOGIC;
			  I_Int_Ack		: in  std_logic;									-- int ack
			  I_Int_Vect	: in  std_logic_vector( 4 downto 0);		-- vector for int ack				
			  
			  Q_SPDR			: out  STD_LOGIC_VECTOR( 7 downto 0);
           Q_MOSI 		: out  STD_LOGIC;
           Q_SCK 			: out  STD_LOGIC;
			  Q_SPIF			: out  STD_LOGIC;
			  Q_WCOL			: out  STD_LOGIC;
			  Q_INT_SPI		: out  STD_LOGIC);
end spi_master;

architecture Behavioral of spi_master is

-- constant
constant BitCount_CPH0		: std_logic_vector(3 downto 0) := "1000";
constant BitCount_CPH1		: std_logic_vector(3 downto 0) := "0111";

-- Sequential
type AutomatMaster_type is ( 	ST_INIT,
										ST_WAIT_FOR_SPDR_END,
										ST_EMPTY_EDGE,
										ST_SEND_BIT,
										ST_SHIFT_BIT);
signal AutomatMaster 			: AutomatMaster_type := ST_INIT;


signal L_PrescalerSPI		: std_logic_vector(2 downto 0);
signal L_EmptyClk				: std_logic_vector(5 downto 0);
signal L_DelayClk				: std_logic_vector(5 downto 0);
signal L_DelayClk_next		: std_logic_vector(5 downto 0);
signal L_SPDR_wr				: std_logic;							-- '1' write access to SPDR
signal L_SPDR_rd				: std_logic;							-- '1' SPDR reading in progress
signal L_SPSR_rd				: std_logic;							-- '1' SPSR reading in progress
signal L_SPSR_read			: std_logic;							-- '1' SPSR is read
signal L_MasterReset			: std_logic;
signal L_SCK					: std_logic;
signal L_SCK_next				: std_logic;							-- not SCK
signal L_SPDR					: std_logic_vector(7 downto 0);
signal L_SPDR_next			: std_logic_vector(7 downto 0);	-- DORD='0' => L_SPDR_left; DORD='1' => L_SPDR_right
signal L_SPDR_buf				: std_logic_vector(7 downto 0);
signal L_SPDR_buf_next		: std_logic_vector(7 downto 0);	-- DORD='0' => L_SPDR_buf_left; DORD='1' => L_SPDR_buf_right
signal L_SPDR_left			: std_logic_vector(7 downto 0);
signal L_SPDR_right			: std_logic_vector(7 downto 0);
signal L_SPDR_buf_left		: std_logic_vector(7 downto 0);
signal L_SPDR_buf_right		: std_logic_vector(7 downto 0);
signal L_BitCount				: std_logic_vector(3 downto 0);	-- bit count
signal L_BitCount_next		: std_logic_vector(3 downto 0);	-- bit count + 1
signal L_BitCount_max		: std_logic_vector(3 downto 0);	-- max bit count
signal L_WCOL_err				: std_logic;
signal L_SPIF					: std_logic;
signal L_WCOL					: std_logic;


begin

	-- Prescaler (number of empty clock)
	--
	L_PrescalerSPI		<= I_SPSR & I_SPCR(SPR1) & I_SPCR(SPR0);
	with L_PrescalerSPI select
		L_EmptyClk 		<= 	"000001"	 		when "000",				-- pres = 4
									"000111"	 		when "001",				-- pres = 16
									"011111" 		when "010",				-- pres = 64
									"111111" 		when "011",				-- pres = 128
									"000000" 		when "100",				-- pres = 2
									"000011" 		when "101",				-- pres = 8
									"001111" 		when "110",				-- pres = 32
									"011111" 		when "111",				-- pres = 64								
									"000000"			when others;			-- pres = 2
	
	-- Automat
	--
	L_MasterReset		<= I_Clr or not I_SPCR(SPE) or not I_SPCR(MSTR);
	L_SPDR_wr			<= '1' when I_ADR_IO = SPDR and I_WE_IO = '1' else '0';
	L_SCK_next 			<= not L_SCK;
	L_DelayClk_next	<= L_DelayClk - 1;
	L_SPDR_left			<= L_SPDR(6 downto 0) & '0';
	L_SPDR_right		<= '0' & L_SPDR(7 downto 1);
	L_SPDR_next			<= L_SPDR_left when I_SPCR(DORD) = '0' else L_SPDR_right;				-- DORD depends
	L_SPDR_buf_left	<= L_SPDR_buf(6 downto 0) & I_MISO;
	L_SPDR_buf_right	<= I_MISO & L_SPDR_buf(7 downto 1);
	L_SPDR_buf_next	<= L_SPDR_buf_left when I_SPCR(DORD) = '0' else L_SPDR_buf_right;		-- DORD depends
	L_BitCount_next	<= L_BitCount + 1;
	

	ISP_automat : process(I_Clk)
	begin
		if I_clk'event and I_clk = '1' then
		
			-- dafault values
			L_WCOL_err	<= '0';

			-- reset state
			if L_MasterReset = '1' then
				L_BitCount			<= (others => '0');
				L_SPDR				<= (others => '0');
				L_SPDR_buf			<= (others => '0');
				L_DelayClk			<= (others => '0');
				L_BitCount_max		<= BitCount_CPH0;
				L_SCK					<= I_SPCR(CPOL);
				L_WCOL_err			<= '0';
				AutomatMaster 		<= ST_INIT;
			else
				case AutomatMaster is
				
					-- init state - prepare signal to send
					when ST_INIT =>
						L_SCK						<= I_SPCR(CPOL);
						L_BitCount				<= (others => '0');
						if L_SPDR_wr = '1' then
							L_SPDR				<= I_DIN;
							L_DelayClk			<= L_EmptyClk;
							AutomatMaster		<= ST_WAIT_FOR_SPDR_END;												
--							if I_SPCR(CPHA) = '0' then													-- CPHA='0'
--								L_BitCount_max	<= BitCount_CPH0;
--								AutomatMaster	<= ST_SEND_BIT;
--							else																				-- CPHA='1'
--								L_BitCount_max	<= BitCount_CPH1;
--								AutomatMaster	<= ST_EMPTY_EDGE;							
--							end if;
						else
							AutomatMaster	<= ST_INIT;						
						end if;
					
					
					-- wait for L_SPDR_wr='0'
					when ST_WAIT_FOR_SPDR_END =>
						if L_SPDR_wr = '0' then
							if I_SPCR(CPHA) = '0' then													-- CPHA='0'
								L_BitCount_max	<= BitCount_CPH0;
								AutomatMaster	<= ST_SEND_BIT;
							else																				-- CPHA='1'
								L_BitCount_max	<= BitCount_CPH1;
								AutomatMaster	<= ST_EMPTY_EDGE;							
							end if;						
						else
							AutomatMaster	<= ST_WAIT_FOR_SPDR_END;							
						end if;
					
					
					-- an empty edge for CPHA='1'
					when ST_EMPTY_EDGE =>
						L_SCK 			<= L_SCK_next;
						L_DelayClk		<= L_EmptyClk;
						AutomatMaster	<= ST_SEND_BIT;

					
					-- send byte and recive byte - if byte to SPDR is write then WCOL=1
					when ST_SEND_BIT =>
						if L_SPDR_wr = '0' then																-- no colision
							if L_DelayClk > 0 then
								L_DelayClk			<= L_DelayClk_next;
								AutomatMaster		<= ST_SEND_BIT;
							else
								if L_BitCount < L_BitCount_max then										-- send 8 bits 								
									L_DelayClk		<= L_EmptyClk;
									L_SCK 			<= L_SCK_next;
									L_SPDR_buf		<= L_SPDR_buf_next;
									AutomatMaster	<= ST_SHIFT_BIT;
								else																				-- end
									L_SCK				<= I_SPCR(CPOL);
									AutomatMaster	<= ST_INIT;							
								end if;
							end if;
						else																						-- colision WCOL='1'
							L_SPDR			<= I_DIN;
							L_WCOL_err 		<= '1';
						end if;
				
					-- shift byte to the next bit - if byte to SPDR is write then WCOL=1
					when ST_SHIFT_BIT =>
						if L_SPDR_wr = '0' then																-- no colision
							if L_DelayClk > 0 then
								L_DelayClk		<= L_DelayClk_next;
								AutomatMaster	<= ST_SHIFT_BIT;
							else
								L_SCK 			<= L_SCK_next;
								L_DelayClk		<= L_EmptyClk;
								L_BitCount		<= L_BitCount_next;
								L_SPDR			<= L_SPDR_next;
								AutomatMaster	<= ST_SEND_BIT;						
							end if;
						else																						-- colision WCOL='1'
							L_SPDR			<= I_DIN;
							L_WCOL_err 		<= '1';						
						end if;
				
				end case;
			end if;				
		end if;
	end process;


	-- latch/cancel SPIF and WCOL 
	--
	L_SPSR_rd			<= '1' when I_ADR_IO = SPSR and I_RD_IO = '1' else '0';
	L_SPDR_rd			<= '1' when I_ADR_IO = SPDR and I_RD_IO = '1' else '0';

	SPIF_latch : process(I_Clk)
	begin
		if I_clk'event and I_clk = '1' then
			if L_MasterReset = '1' then
				L_SPIF		<= '0';
				L_WCOL		<= '0';
				L_SPSR_read <= '0';
			else
				-- prepare to cancel SPIF and WCOL
				if (L_SPIF = '1' or L_WCOL = '1') and L_SPSR_rd = '1' then
					L_SPSR_read <= '1';
				else
					null;
				end if;
					
				-- latch/cancel SPIF
				if L_DelayClk = "000000" and L_BitCount = L_BitCount_max then 																					-- latch SPIF
					L_SPIF	<= '1';
				else
					if (L_SPSR_read = '1' and (L_SPDR_rd = '1' or L_SPDR_wr = '1')) or (I_Int_Ack = '1' and I_Int_Vect = SPI_int_vec) then 	-- cancel SPIF
						L_SPIF		<= '0';
						L_SPSR_read <= '0';
					else
						null;
					end if;
				end if;
				
				-- latch/cancel WCOL
				if L_WCOL_err = '1' then																																	-- latch WCOL
					L_WCOL <= '1';
				else
					if (L_SPSR_read = '1' and (L_SPDR_rd = '1' or L_SPDR_wr = '1')) then																		-- cancel WCOL
						L_WCOL		<= '0';
						L_SPSR_read <= '0';						
					else
						null;
					end if;
				end if;
				
				
			end if;
		end if;
	end process;


	-- Outside
	--
	Q_SCK			<= L_SCK;
	Q_MOSI		<= L_SPDR(7) when I_SPCR(DORD) = '0' else L_SPDR(0);
	Q_SPIF		<= L_SPIF;
	Q_WCOL		<= L_WCOL;
	Q_SPDR		<= L_SPDR_buf;
	
	-- generate SPI interrupt (vector 0x00A), when SPI transfer is finished and SPIE is enabled
	--
	Q_INT_SPI	<= '1' when L_SPIF = '1' and I_SPCR(SPIE) = '1' else '0';

end Behavioral;

