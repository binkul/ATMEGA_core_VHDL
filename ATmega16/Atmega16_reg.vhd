-------------------------------------------------------------------------------
-- 
-- Copyright (C) 2021 Jacek Binkul
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
-- Module Name:    common
-- Create Date:    13:51:24 19/08/2021 
-- Description:    constants Atmega16.
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.all;

package Atmega16_reg is

    -----------------------------------------------------------------------
    --
    -- Atmegas register and Bits
    --
	 
	 
	 -- Int vectors
	 constant INT0_int_vec		: std_logic_vector := "00001";		
	 constant INT1_int_vec		: std_logic_vector := "00010";		
	 constant OCF2_int_vec		: std_logic_vector := "00011";		
	 constant TOV2_int_vec		: std_logic_vector := "00100";		
	 constant ICF1_int_vec		: std_logic_vector := "00101";		
	 constant OCF1A_int_vec		: std_logic_vector := "00110";		
	 constant OCF1B_int_vec		: std_logic_vector := "00111";		
	 constant TOV1_int_vec		: std_logic_vector := "01000";		
	 constant TOV0_int_vec		: std_logic_vector := "01001";		
	 constant SPI_int_vec		: std_logic_vector := "01010";		
	 constant RXC_int_vec		: std_logic_vector := "01011";		
	 constant UDRE_int_vec		: std_logic_vector := "01100";		
	 constant TXC_int_vec		: std_logic_vector := "01101";		
	 constant ADC_int_vec		: std_logic_vector := "01110";		
	 constant ERDY_int_vec		: std_logic_vector := "01111";		
	 constant ANCMP_int_vec		: std_logic_vector := "10000";		
	 constant TWI_int_vec		: std_logic_vector := "10001";		
	 constant INT2_int_vec		: std_logic_vector := "10010";		
	 constant OCF0_int_vec		: std_logic_vector := "10011";		
	 constant SPMRD_int_vec		: std_logic_vector := "10100";		

	 -- SPI
	 constant SPCR					: std_logic_vector := x"2D";
	 constant SPSR					: std_logic_vector := x"2E";
	 constant SPDR					: std_logic_vector := x"2F";
	 constant TIFR					: std_logic_vector := x"58";
	 
	 constant SPIF					: integer := 7;
	 constant WCOL					: integer := 6;
	 constant SPI2X				: integer := 0;
	 constant SPIE					: integer := 7;
	 constant SPE					: integer := 6;
	 constant DORD					: integer := 5;
	 constant MSTR					: integer := 4;
	 constant CPOL					: integer := 3;
	 constant CPHA					: integer := 2;
	 constant SPR1					: integer := 1;
	 constant SPR0					: integer := 0;
	 
	 constant SPI_SS				: integer := 4;
	 constant SPI_MOSI			: integer := 5;
	 constant SPI_MISO			: integer := 6;
	 constant SPI_SCK				: integer := 7;
	 
	 -- TCNT0
	 constant TOV0					: integer := 0;
	 constant OCF0					: integer := 1;
	 constant TOV1					: integer := 2;
	 constant OCF1B				: integer := 3;
	 constant OCF1A				: integer := 4;
	 constant ICF1					: integer := 5;
	 constant TOV2					: integer := 6;
	 constant OCF2					: integer := 7;
	 
	 constant FOC0					: integer := 7;
	 constant WGM00				: integer := 6;
	 constant COM01				: integer := 5;
	 constant COM00				: integer := 4;
	 constant WGM01				: integer := 3;
	 constant CS02					: integer := 2;
	 constant CS01					: integer := 1;
	 constant CS00					: integer := 0;

	 constant TOIE0				: integer := 0;
	 constant OCIE0				: integer := 1;
	 constant TOIE1				: integer := 2;
	 constant OCIE1B				: integer := 3;
	 constant OCIE1A				: integer := 4;
	 constant TICIE1				: integer := 5;
	 constant TOIE2				: integer := 6;
	 constant OCIE2				: integer := 7;

	 constant PSR10				: integer := 0;
	 constant OC0					: integer := 3;
	 
	 -- USART
	 constant UDR					: std_logic_vector := x"2C";
	 constant UCSRA				: std_logic_vector := x"2B";
	 constant UCSRB				: std_logic_vector := x"2A";
	 constant UCSRC				: std_logic_vector := x"40";
	 constant UBRRL				: std_logic_vector := x"29";
	 constant UBRRH				: std_logic_vector := x"40";
	 
	 constant MPCM					: integer := 0;
	 constant U2X					: integer := 1;
	 constant PE					: integer := 2;
	 constant DOR					: integer := 3;
	 constant FE					: integer := 4;
	 constant UDRE					: integer := 5;
	 constant TXC					: integer := 6;
	 constant RXC					: integer := 7;
	 
	 constant TXB8					: integer := 0;
	 constant RXB8					: integer := 1;
	 constant UCSZ2				: integer := 2;
	 constant TXEN					: integer := 3;
	 constant RXEN					: integer := 4;
	 constant UDRIE				: integer := 5;
	 constant TXCIE				: integer := 6;
	 constant RXCIE				: integer := 7;

	 constant UCPOL				: integer := 0;
	 constant UCSZ0				: integer := 1;
	 constant UCSZ1				: integer := 2;
	 constant USBS					: integer := 3;
	 constant UPM0					: integer := 4;
	 constant UPM1					: integer := 5;
	 constant UMSEL				: integer := 6;
	 constant URSEL				: integer := 7;
	 
	 constant USART_RX			: integer := 0;
	 constant USART_TX			: integer := 1;

end Atmega16_reg;
