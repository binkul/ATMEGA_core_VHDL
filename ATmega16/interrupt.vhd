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
-- Module Name:    io - Behavioral 
-- Create Date:    13:59:36 11/07/2009 
-- Description:    the I/O of a CPU (uart and general purpose I/O lines).
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity interrupt is
    port (	I_INT0vect	: in  std_logic;
				I_INT1vect	: in  std_logic;
				I_OC2vect	: in  std_logic;
				I_OVFV2vect	: in  std_logic;
				I_ICP1vect	: in  std_logic;
				I_OC1Avect	: in  std_logic;
				I_OC1Bvect	: in  std_logic;
				I_OVFV1vect	: in  std_logic;
				I_OVFV0vect	: in  std_logic;
				I_SPIvect	: in  std_logic;
				I_URXCvect	: in  std_logic;
				I_UDREvect	: in  std_logic;
				I_UTXCvect	: in  std_logic;
				I_ADCCvect	: in  std_logic;
				I_ERDYvect	: in  std_logic;
				I_ACIvect	: in  std_logic;
				I_TWIvect	: in  std_logic;
				I_INT2vect	: in  std_logic;
				I_OC0vect	: in  std_logic;
				I_SPMRvect	: in  std_logic;

            Q_INTVEC    : out std_logic_vector( 5 downto 0));
end interrupt;

architecture Behavioral of interrupt is


signal L_Interrupts_nr	: std_logic_vector(19 downto 0);								-- 20 interrupts vectors in vectors table of Atmega16
signal L_Interrupt		: std_logic_vector( 5 downto 0);								-- interrupt


begin
	 Q_INTVEC			<= L_Interrupt;															-- INTVEC return
	 
	 L_Interrupts_nr 	<= I_SPMRvect & I_OC0vect & I_INT2vect & I_TWIvect & I_ACIvect & I_ERDYvect & I_ADCCvect &
								I_UTXCvect & I_UDREvect & I_URXCvect & I_SPIvect & I_OVFV0vect & I_OVFV1vect & 
								I_OC1Bvect & I_OC1Avect & I_ICP1vect & I_OVFV2vect & 
								I_OC2vect & I_INT1vect & I_INT0vect;						-- ALL Interrupts nr (according to vector in Atmega16) in progres
	
	
	 -- Vectors table - set interrupts vector for Atmega16 (total 20 interrupts) - Atention! - this vector must be mult *2
	 --
	 L_Interrupt <= "100001" when L_Interrupts_nr(0) = '1' else
						 "100010" when L_Interrupts_nr(1) = '1' else
						 "100011" when L_Interrupts_nr(2) = '1' else
						 "100100" when L_Interrupts_nr(3) = '1' else
						 "100101" when L_Interrupts_nr(4) = '1' else
						 "100110" when L_Interrupts_nr(5) = '1' else
						 "100111" when L_Interrupts_nr(6) = '1' else
						 "101000" when L_Interrupts_nr(7) = '1' else
						 "101001" when L_Interrupts_nr(8) = '1' else
						 "101010" when L_Interrupts_nr(9) = '1' else
						 "101011" when L_Interrupts_nr(10) = '1' else
						 "101100" when L_Interrupts_nr(11) = '1' else
						 "101101" when L_Interrupts_nr(12) = '1' else
						 "101110" when L_Interrupts_nr(13) = '1' else
						 "101111" when L_Interrupts_nr(14) = '1' else
						 "110000" when L_Interrupts_nr(15) = '1' else
						 "110001" when L_Interrupts_nr(16) = '1' else
						 "110010" when L_Interrupts_nr(17) = '1' else
						 "110011" when L_Interrupts_nr(18) = '1' else
						 "110100" when L_Interrupts_nr(19) = '1' else "000000";
						 
	 
end Behavioral;
