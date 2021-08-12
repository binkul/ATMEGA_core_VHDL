-------------------------------------------------------------------------------
-- 
-- Copyright (C) 2009, 2010 Dr. Juergen Sauermann, modified by Jacek Binkul
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
-- Module Name:    data_mem - Behavioral 
-- Create Date:    14:09:04 10/30/2009 
-- Description:    the data mempry of a CPU.
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity data_mem is
    port (  I_CLK       : in  std_logic;

            I_ADR       : in  std_logic_vector(9 downto 0);
            I_DIN       : in  std_logic_vector(15 downto 0);
            I_WE        : in  std_logic_vector( 1 downto 0);

            Q_DOUT      : out std_logic_vector(15 downto 0));
end data_mem;

architecture Behavioral of data_mem is


component Sram
	 PORT(	
				address	: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
				clock		: IN STD_LOGIC  := '1';
				data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
				wren		: IN STD_LOGIC ;
				q			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
			);
end component;

signal L_ADR_0      : std_logic;
signal L_ADR_E      : std_logic_vector(9 downto 1);
signal L_ADR_O      : std_logic_vector(9 downto 1);
signal L_DIN_E      : std_logic_vector( 7 downto 0);
signal L_DIN_O      : std_logic_vector( 7 downto 0);
signal L_DOUT_E     : std_logic_vector( 7 downto 0);
signal L_DOUT_O     : std_logic_vector( 7 downto 0);
signal L_WE_E       : std_logic;
signal L_WE_O       : std_logic;
 
begin


    sr_0 : Sram ---------------------------------------------------------
    port map(   
					address	=> L_ADR_E,
					clock		=> I_CLK,
					data		=> L_DIN_E,
					wren		=> L_WE_E,
					q			=> L_DOUT_E
				);
				
    sr_1 : Sram ---------------------------------------------------------
    port map(   
					address	=> L_ADR_O,
					clock		=> I_CLK,
					data		=> L_DIN_O,
					wren		=> L_WE_O,
					q			=> L_DOUT_O
				);
 

    -- remember ADR(0)
    --
    adr0: process(I_CLK)
    begin
        if (rising_edge(I_CLK)) then
            L_ADR_0 <= I_ADR(0);
        end if;
    end process;

    -- we use two memory blocks _E and _O (even and odd).
    -- This gives us a memory with ADR and ADR + 1 at th same time.
    -- The second port is currently unused, but may be used later,
    -- e.g. for DMA.
    --

    L_ADR_O <= I_ADR(9 downto 1);
    L_ADR_E <= I_ADR(9 downto 1) + ("00000000" & I_ADR(0));

    L_DIN_E <= I_DIN( 7 downto 0) when (I_ADR(0) = '0') else I_DIN(15 downto 8);
    L_DIN_O <= I_DIN( 7 downto 0) when (I_ADR(0) = '1') else I_DIN(15 downto 8);

    L_WE_E <= I_WE(1) or (I_WE(0) and not I_ADR(0));
    L_WE_O <= I_WE(1) or (I_WE(0) and     I_ADR(0));

    Q_DOUT( 7 downto 0) <= L_DOUT_E when (L_ADR_0 = '0') else L_DOUT_O;
    Q_DOUT(15 downto 8) <= L_DOUT_E when (L_ADR_0 = '1') else L_DOUT_O;
 
end Behavioral;
