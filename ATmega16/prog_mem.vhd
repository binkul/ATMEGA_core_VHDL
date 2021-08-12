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
-- Module Name:    prog_mem - Behavioral 
-- Create Date:    14:09:04 10/30/2009 
-- Description:    the program memory of a CPU.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- the content of the program memory.
--
--use work.prog_mem_content.all;

entity prog_mem is
    port (  I_CLK       : in  std_logic;

            I_WAIT      : in  std_logic;
            I_PC        : in  std_logic_vector(15 downto 0); -- word address
            I_PM_ADR    : in  std_logic_vector(13 downto 0); -- byte address

				I_LOAD		: in  std_logic;							 		-- '0' - load of rom content via ISP
				Q_DATA_From : out std_logic_vector (15 downto 0);		-- Data Read from Flash
				I_ADR_From	: in std_logic_vector (12 downto 0);		-- ADRess to read from Flash (bit 0 - even/odd)
				I_DATA_To 	: in std_logic_vector (15 downto 0);		-- Data to write to Flash
				I_ADR_To	 	: in std_logic_vector (11 downto 0);		-- Adres to write to Flash
				I_WE_To		: in std_logic_vector (1 downto 0);			-- WE to write '01'-even, '10'-odd, '00'-none
				
            Q_OPC       : out std_logic_vector(31 downto 0);
            Q_PC        : out std_logic_vector(15 downto 0);
            Q_PM_DOUT   : out std_logic_vector( 7 downto 0));
end prog_mem;

architecture Behavioral of prog_mem is


-- PORT ROM Even
component FLASH_even
	PORT (	address_a	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
				address_b	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
				clock_a		: IN STD_LOGIC  := '1';
				clock_b		: IN STD_LOGIC ;
				data_a		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				data_b		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				rden_a		: IN STD_LOGIC  := '1';
				rden_b		: IN STD_LOGIC  := '1';
				wren_a		: IN STD_LOGIC  := '0';
				wren_b		: IN STD_LOGIC  := '0';
				q_a			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
				q_b			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0));
end component;


-- PORT ROM odd
component FLASH_odd
	PORT (	address_a	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
				address_b	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
				clock_a		: IN STD_LOGIC  := '1';
				clock_b		: IN STD_LOGIC ;
				data_a		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				data_b		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
				rden_a		: IN STD_LOGIC  := '1';
				rden_b		: IN STD_LOGIC  := '1';
				wren_a		: IN STD_LOGIC  := '0';
				wren_b		: IN STD_LOGIC  := '0';
				q_a			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
				q_b			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0));
end component;



signal M_OPC_E      : std_logic_vector(15 downto 0);
signal M_OPC_O      : std_logic_vector(15 downto 0);
signal M_PMD_E      : std_logic_vector(15 downto 0);
signal M_PMD_O      : std_logic_vector(15 downto 0);

signal L_WAIT_N     : std_logic;
signal L_PC_0       : std_logic;
signal L_PC_E       : std_logic_vector(12 downto 1);
signal L_PC_O       : std_logic_vector(12 downto 1);
signal L_PMD        : std_logic_vector(15 downto 0);
signal L_PM_ADR_1_0 : std_logic_vector( 1 downto 0);

signal L_Adress_even			: std_logic_vector(11 downto 0);
signal L_Adress_odd			: std_logic_vector(11 downto 0);
signal L_Adress_Rd_even		: std_logic_vector(11 downto 0);
signal L_Adress_Rd_odd		: std_logic_vector(11 downto 0);
signal L_rden					: std_logic;
signal L_wren_eve 			: std_logic;
signal L_wren_odd				: std_logic;


begin

--    pe_0 : FLASH_even ---------------------------------------------------------
--    port map(addra 		=> L_Adress_even,        addrb 		=> L_Adress_Rd_even,
--             clka  		=> I_CLK,	             clkb  		=> I_CLK,
--             ena   		=> L_rden,             	 enb   		=> '1',
--             dina			=>	I_DATA_To,			 	 dinb			=> "0000000000000000",
--				 wea			=>	L_wren_eve,				 web			=> "0",
--				 douta   	=> M_OPC_E,  				 doutb   	=> M_PMD_E);
    pe_0 : FLASH_even ---------------------------------------------------------
    port map(address_a 	=> L_Adress_even,        address_b 	=> L_Adress_Rd_even,
             clock_a  	=> I_CLK,	             clock_b  	=> I_CLK,
             rden_a   	=> L_rden,             	 rden_b   	=> '1',
             data_a		=>	I_DATA_To,			 	 data_b		=> "0000000000000000",
				 wren_a		=>	L_wren_eve,				 wren_b		=> '0',
				 q_a   		=> M_OPC_E,  				 q_b   		=> M_PMD_E);
	 
	 
--    pe_1 : FLASH_odd ---------------------------------------------------------
--    port map(addra 		=> L_Adress_odd,         addrb 		=> L_Adress_Rd_odd,
--             clka  		=> I_CLK,  	             clkb  		=> I_CLK,
--             ena   		=> L_rden,             	 enb   		=> '1',
--             dina			=>	I_DATA_To,			 	 dinb			=> "0000000000000000",
--				 wea			=>	L_wren_odd,				 web			=> "0",
--             douta   	=> M_OPC_O,  				 doutb   	=> M_PMD_O);
    pe_1 : FLASH_odd ---------------------------------------------------------
    port map(address_a 	=> L_Adress_odd,         address_b 	=> L_Adress_Rd_odd,
             clock_a  	=> I_CLK,  	             clock_b  	=> I_CLK,
             rden_a   	=> L_rden,             	 rden_b   	=> '1',
             data_a		=>	I_DATA_To,			 	 data_b		=> "0000000000000000",
				 wren_a		=>	L_wren_odd,				 wren_b		=> '0',
             q_a   		=> M_OPC_O,  				 q_b   		=> M_PMD_O);

	 
	 -- MUX on PortA - program or work
	 --
	 L_Adress_even		<= L_PC_E 						when I_Load = '1' else I_ADR_To;
	 L_Adress_odd		<= L_PC_O 						when I_Load = '1' else I_ADR_To;
	 L_Adress_Rd_even	<= I_PM_ADR(13 downto 2) 	when I_Load = '1' else I_ADR_From(12 downto 1);
	 L_Adress_Rd_odd	<= I_PM_ADR(13 downto 2) 	when I_Load = '1' else I_ADR_From(12 downto 1);
	 L_rden				<= L_WAIT_N 					when I_Load = '1' else '1';
	 L_wren_eve 		<= '0'							when I_Load = '1' else I_WE_To(0);
	 L_wren_odd			<= '0'							when I_Load = '1' else I_WE_To(1);
	 Q_DATA_From		<= M_PMD_E						when I_ADR_From (0) = '0' else M_PMD_O;
	
    -- remember I_PC0 and I_PM_ADR for the output mux.
    --
    pc0: process(I_CLK)
    begin
        if (rising_edge(I_CLK)) then
            Q_PC <= I_PC;
            L_PM_ADR_1_0 <= I_PM_ADR(1 downto 0);
            if ((I_WAIT = '0')) then
                L_PC_0 <= I_PC(0);
            end if;
        end if;
    end process;

    L_WAIT_N <= not I_WAIT;

    -- we use two memory blocks _E and _O (even and odd).
    -- This gives us a quad-port memory so that we can access
    -- I_PC, I_PC + 1, and PM simultaneously.
    --
    -- I_PC and I_PC + 1 are handled by port A of the memory while PM
    -- is handled by port B.
    --
    -- Q_OPC(15 ... 0) shall contain the word addressed by I_PC, while
    -- Q_OPC(31 ... 16) shall contain the word addressed by I_PC + 1.
    --
    -- There are two cases:
    --
    -- case A: I_PC     is even, thus I_PC + 1 is odd
    -- case B: I_PC + 1 is odd , thus I_PC is even
    --
    L_PC_O <= I_PC(12 downto 1);
    L_PC_E <= I_PC(12 downto 1) + ("00000000000" & I_PC(0));
    Q_OPC(15 downto  0) <= M_OPC_E when L_PC_0 = '0' else M_OPC_O;
    Q_OPC(31 downto 16) <= M_OPC_E when L_PC_0 = '1' else M_OPC_O;

    L_PMD <= M_PMD_E               when (L_PM_ADR_1_0(1) = '0') else M_PMD_O;
    Q_PM_DOUT <= L_PMD(7 downto 0) when (L_PM_ADR_1_0(0) = '0')
            else L_PMD(15 downto 8);
    
end Behavioral;
