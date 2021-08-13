-------------------------------------------------------------------------------
-- 
-- Copyright (C) 2018 Jacek Binkul
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
-- Module Name:    io - Atmega16 
-- Create Date:    13:59:36 01/07/2018 
-- Description:    the I/O of a CPU (uart and general purpose I/O lines).
--
-------------------------------------------------------------------------------
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.common.ALL;
use work.Atmega16_reg.All;

entity io is
    port (  I_CLK       : in  std_logic;
				I_Clk_per	: in  std_logic;
            I_CLR       : in  std_logic;
            I_ADR_IO    : in  std_logic_vector( 7 downto 0);
            I_DIN       : in  std_logic_vector( 7 downto 0);
            I_RD_IO     : in  std_logic;
            I_WE_IO     : in  std_logic;
				I_PORT_A		: in  std_logic_vector( 7 downto 0);
				I_PORT_B		: in  std_logic_vector( 7 downto 0);
				I_PORT_C		: in  std_logic_vector( 7 downto 0);
				I_PORT_D		: in  std_logic_vector( 7 downto 0);
				I_Int_Ack	: in  std_logic;
				I_Int_Vect	: in  std_logic_vector( 4 downto 0);
				
            Q_DOUT      : out std_logic_vector( 7 downto 0);
				Q_PORT_A		: out std_logic_vector( 7 downto 0);
				Q_PORT_B		: out std_logic_vector( 7 downto 0);
				Q_PORT_C		: out std_logic_vector( 7 downto 0);
				Q_PORT_D		: out std_logic_vector( 7 downto 0);
            Q_INTVEC    : out std_logic_vector( 5 downto 0));
end io;

architecture Behavioral of io is

constant T0						: integer := 0;
constant WGM00					: integer := 6;
constant WGM01					: integer := 3;
constant COM00					: integer := 4;
constant COM01					: integer := 5;

component Timer0
    port (  I_CLK       : in  std_logic;
				I_CLR			: in  std_logic;
				I_T0			: in  std_logic;

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
end component;

signal T0_TCNT0			: std_logic_vector( 7 downto 0);
signal T0_INT_TOV0		: std_logic;
signal T0_INT_OCF0		: std_logic;
signal T0_OCR0				: std_logic_vector( 7 downto 0);
signal T0_OC0				: std_logic;
signal T0_TOV0				: std_logic;
signal T0_OCF0				: std_logic;


component spi_master
    Port ( I_Clk 			: in  STD_LOGIC;
           I_Clr 			: in  STD_LOGIC;
           I_MISO 		: in  STD_LOGIC;
           I_ADR_IO  	: in  std_logic_vector( 7 downto 0);
           I_DIN     	: in  std_logic_vector( 7 downto 0);
           I_WE_IO   	: in  std_logic;							
           I_RD_IO   	: in  std_logic;			  				
			  I_SPCR			: in  STD_LOGIC_VECTOR( 7 downto 0);
			  I_SPSR			: in  STD_LOGIC;
			  I_Int_Ack		: in  std_logic;									
			  I_Int_Vect	: in  std_logic_vector( 4 downto 0);				
			  
			  Q_SPDR			: out  STD_LOGIC_VECTOR( 7 downto 0);
           Q_MOSI 		: out  STD_LOGIC;
           Q_SCK 			: out  STD_LOGIC;
			  Q_SPIF			: out  STD_LOGIC;
			  Q_WCOL			: out  STD_LOGIC;
			  Q_INT_SPI		: out  STD_LOGIC);
end component;

signal S_SPIF				: std_logic;
signal S_WCOL				: std_logic;
signal S_MOSI				: std_logic;
signal S_SCK				: std_logic;
signal S_INT_SPI			: std_logic;
signal S_SPDR				: std_logic_vector( 7 downto 0);


component Usart
    Port ( I_Clk 			: in  STD_LOGIC;
           I_Clr 			: in  STD_LOGIC;
           I_ADR_IO  	: in  std_logic_vector( 7 downto 0);
           I_DIN     	: in  std_logic_vector( 7 downto 0);		
           I_RD_IO   	: in  std_logic;									
           I_WE_IO   	: in  std_logic;									
			  I_UCSRB		: in 	STD_LOGIC_VECTOR(7 downto 0);
			  I_UCSRC		: in 	STD_LOGIC_VECTOR(7 downto 0);
			  I_UBRR			: in 	STD_LOGIC_VECTOR(14 downto 0);
			  I_RX			: in  STD_LOGIC;
			  I_TXB8			: in  STD_LOGIC;

			  I_Int_Ack		: in  std_logic;									-- int ack
			  I_Int_Vect	: in  std_logic_vector( 4 downto 0);		-- vector for int ack				
			  
			  Q_RX_buf		: out STD_LOGIC_VECTOR(7 downto 0);
			  Q_RXC			: out STD_LOGIC;
			  Q_INT_RX		: out STD_LOGIC;
			  Q_TXC			: out STD_LOGIC;
			  Q_INT_TXC		: out STD_LOGIC;
			  Q_UDRE			: out STD_LOGIC;
			  Q_INT_UDRE 	: out STD_LOGIC;
			  Q_FE			: out STD_LOGIC;
			  Q_DOR			: out STD_LOGIC;
			  Q_PE			: out STD_LOGIC;
			  Q_RXB8			: out STD_LOGIC;
			  Q_TX			: out STD_LOGIC;
			  Q_TX_inRun	: out STD_LOGIC);
end component;

signal U_TX					: std_logic;
signal U_TX_inRun			: std_logic;
signal U_RXC				: std_logic;
signal U_TXC				: std_logic;
signal U_UDRE				: std_logic;
signal U_FE					: std_logic;
signal U_DOR				: std_logic;
signal U_PE					: std_logic;
signal U_RXB8				: std_logic;
signal U_INT_RX			: std_logic;
signal U_INT_UDRE			: std_logic;
signal U_RX_buf			: std_logic_vector(7 downto 0);
signal U_INT_TXC			: std_logic;


component interrupt
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
end component;



signal L_TCCR0				: std_logic_vector( 6 downto 0);
signal L_TIMSK				: std_logic_vector( 7 downto 0);
signal L_SPCR				: std_logic_vector( 7 downto 0);
signal L_SPSR				: std_logic;
signal L_UCSRB				: std_logic_vector( 7 downto 0);
signal L_UCSRC				: std_logic_vector( 7 downto 0);
signal L_UBRRL				: std_logic_vector( 7 downto 0);
signal L_UBRRH				: std_logic_vector( 7 downto 0);
signal L_UBRR				: std_logic_vector(14 downto 0);
signal L_PORTA				: std_logic_vector( 7 downto 0);
signal L_DDRA				: std_logic_vector( 7 downto 0);
signal L_PINA				: std_logic_vector( 7 downto 0);
signal L_PORTB				: std_logic_vector( 7 downto 0);
signal L_DDRB				: std_logic_vector( 7 downto 0);
signal L_PINB				: std_logic_vector( 7 downto 0);
signal L_PORTC				: std_logic_vector( 7 downto 0);
signal L_DDRC				: std_logic_vector( 7 downto 0);
signal L_PINC				: std_logic_vector( 7 downto 0);
signal L_PORTD				: std_logic_vector( 7 downto 0);
signal L_DDRD				: std_logic_vector( 7 downto 0);
signal L_PIND				: std_logic_vector( 7 downto 0);
signal L_PORTB_OC0		: std_logic;
signal L_PORTB_MOSI		: std_logic;
signal L_PORTB_MISO		: std_logic;
signal L_PORTB_SCK		: std_logic;
signal L_PORTD_TX			: std_logic;
signal L_PORTD_RX			: std_logic;


begin
	 -- Timer0 component port map
	 Tim0 : Timer0
    port map(   I_CLK       => I_CLK,
	 				 I_CLR		 => I_CLR,
					 I_T0			 => I_PORT_B(T0),
					 
					 I_ADR_IO    => I_ADR_IO,
					 I_DIN       => I_DIN,
					 I_WE_IO     => I_WE_IO,
					 I_TCCR0		 => L_TCCR0,
					 I_TIMSK		 => L_TIMSK(1 downto 0),

					 I_Int_Ack	 => I_Int_Ack,
					 I_Int_Vect	 => I_Int_Vect,				

					 Q_OC0		 => T0_OC0,
					 Q_TCNT0     => T0_TCNT0,
					 Q_OCR0		 => T0_OCR0,
					 Q_TOV0		 => T0_TOV0,
					 Q_OCF0		 => T0_OCF0,
					 Q_INT_TOV0	 => T0_INT_TOV0,
					 Q_INT_OCF0	 => T0_INT_OCF0);

	 -- SPI module
	 masterSPI : spi_master
	 port map(	 I_Clk 		 => I_Clk_per,
					 I_Clr 		 => I_CLR,
					 I_MISO 		 => L_PORTB_MISO,
					 I_ADR_IO  	 => I_ADR_IO,
					 I_DIN     	 => I_DIN,
					 I_WE_IO   	 => I_WE_IO,
					 I_RD_IO		 => I_RD_IO,
					 I_SPCR		 => L_SPCR,
					 I_SPSR		 => L_SPSR,
					 I_Int_Ack	 => I_Int_Ack,
					 I_Int_Vect	 => I_Int_Vect,				
			  
					 Q_SPDR		 => S_SPDR,
					 Q_MOSI 		 => S_MOSI,
					 Q_SCK 		 => S_SCK,
					 Q_SPIF		 => S_SPIF,
					 Q_WCOL		 => S_WCOL,
					 Q_INT_SPI	 => S_INT_SPI);

	 -- Usart module
	 usartAsyn : Usart
    port map( 	 I_Clk 		 => I_CLK,
					 I_Clr 		 => I_CLR,
					 I_ADR_IO  	 => I_ADR_IO,
					 I_DIN     	 => I_DIN,		
					 I_RD_IO   	 => I_RD_IO,									
					 I_WE_IO   	 => I_WE_IO,									
					 I_UCSRB		 => L_UCSRB,
					 I_UCSRC		 => L_UCSRC,
					 I_UBRR		 => L_UBRR,
					 I_RX			 => L_PORTD_RX,
					 I_TXB8		 => L_UCSRB(TXB8),			  

					 I_Int_Ack	 => I_Int_Ack,
					 I_Int_Vect	 => I_Int_Vect,				
			  
					 Q_RX_buf	 => U_RX_buf,
					 Q_RXC		 => U_RXC,
					 Q_INT_RX	 => U_INT_RX,
					 Q_TXC		 => U_TXC,
					 Q_INT_TXC	 => U_INT_TXC,
					 Q_UDRE		 => U_UDRE,
					 Q_INT_UDRE  => U_INT_UDRE,
					 Q_FE			 => U_FE,
					 Q_DOR		 => U_DOR,
					 Q_PE			 => U_PE,
					 Q_RXB8		 => U_RXB8,
					 Q_TX			 => U_TX,
					 Q_TX_inRun	 => U_TX_inRun);
	 

	 -- Interrupt component
	 Intr0 : interrupt
	 port map(	 I_INT0vect	 => '0',
					 I_INT1vect	 => '0',
					 I_OC2vect	 => '0', 
					 I_OVFV2vect => '0',
					 I_ICP1vect	 => '0',
					 I_OC1Avect	 => '0',
					 I_OC1Bvect	 => '0',
					 I_OVFV1vect => '0',
					 I_OVFV0vect => T0_INT_TOV0,
					 I_SPIvect	 => S_INT_SPI,
					 I_URXCvect	 => U_INT_RX,
					 I_UDREvect	 => U_INT_UDRE,
					 I_UTXCvect	 => U_INT_TXC,
					 I_ADCCvect	 => '0',
					 I_ERDYvect	 => '0',
					 I_ACIvect	 => '0',
					 I_TWIvect	 => '0',
					 I_INT2vect	 => '0',
					 I_OC0vect	 => T0_INT_OCF0, 
					 I_SPMRvect	 => '0',

					 Q_INTVEC    => Q_INTVEC);

    -- IO read process
    --
    iord: process(I_ADR_IO, L_PIND, L_DDRD, L_PORTD, L_PINC, L_DDRC, L_PORTC, L_PINB, L_DDRB, L_PORTB, L_PINA, L_DDRA, L_PORTA,
						T0_TCNT0, L_TCCR0, L_TIMSK, T0_OCF0, T0_TOV0, T0_OCR0, L_SPCR, S_SPIF, S_WCOL, L_SPSR, S_SPDR, L_UBRRL, L_UCSRB, 
						U_RXB8, U_RXC, U_TXC, U_UDRE, U_FE, U_DOR, U_PE, U_RX_buf, L_UCSRC)
    begin
        -- addresses for mega16 device (use iom16.h or #define __AVR_ATmega16__).
        --
        case I_ADR_IO is
				when X"29"	=> Q_DOUT <= L_UBRRL;										-- UBRRL
				when X"2A"	=> Q_DOUT <= L_UCSRB(7 downto 2) & U_RXB8 & L_UCSRB(0);					-- UCSRB UCSRB(1) from Usrat
				when X"2B"	=> Q_DOUT <= U_RXC & U_TXC & U_UDRE & U_FE & U_DOR & U_PE & "00";		-- UCSRA only for read
				when X"2C"	=> Q_DOUT <= U_RX_buf;										-- UDR reciver RX
				when X"2D"	=> Q_DOUT <= L_SPCR;											-- SPCR
				when X"2E"	=> Q_DOUT <= S_SPIF & S_WCOL & "00000" & L_SPSR;	-- SPSR
				when X"2F"	=> Q_DOUT <= S_SPDR;											-- SPDR
            when X"30"  => Q_DOUT <= L_PIND;            							-- PIND
            when X"31"  => Q_DOUT <= L_DDRD;            							-- DDRD
				when X"32"  => Q_DOUT <= L_PORTD;			  							-- PORTD
            when X"33"  => Q_DOUT <= L_PINC;      									-- PINC
            when X"34"  => Q_DOUT <= L_DDRC;		  									-- DDRC
            when X"35"  => Q_DOUT <= L_PORTC;	  									-- PORTC
            when X"36"  => Q_DOUT <= L_PINB;				  							-- PINB
            when X"37"  => Q_DOUT <= L_DDRB;				  							-- DDRB
            when X"38"  => Q_DOUT <= L_PORTB;			  							-- PORTB
            when X"39"  => Q_DOUT <= L_PINA;				  							-- PINA
            when X"3A"  => Q_DOUT <= L_DDRA;				  							-- DDRA
            when X"3B"  => Q_DOUT <= L_PORTA;			  							-- PORTA
				when X"40" 	=> Q_DOUT <= L_UCSRC;										-- This is shared between UCSRC and UBBRH. Only UCSRC can be read
				when X"50"	=> Q_DOUT <= x"00";											-- SFIOR - ADC is not use, PSR0 and PSR10 always read as 0
            when X"52"  => Q_DOUT <= T0_TCNT0;			  							-- TCNT0
            when X"53"  => Q_DOUT <= '0' & L_TCCR0(6 downto 0);				-- TCCR0 - FOC0 (bit 7) is always read as 0
            when X"58"  => Q_DOUT <= "000000" & T0_OCF0 & T0_TOV0;			-- TIFR
            when X"59"  => Q_DOUT <= L_TIMSK;										-- TIMSK
				when X"5C"	=> Q_DOUT <= T0_OCR0;										-- OCR0
            when others => Q_DOUT <= X"FF";		 									-- In any other 'FF'
        end case;
    end process;

	 -- Alternate port function
	 --
	 -- TCNT0
	 L_PORTB_OC0 	<= T0_OC0 when L_TCCR0(COM01) = '1' 
										or (L_TCCR0(COM01) = '0' and L_TCCR0(COM00) = '1' and L_TCCR0(WGM01) = '1' and L_TCCR0(WGM00) = '0') 
										or (L_TCCR0(COM01) = '0' and L_TCCR0(COM00) = '1' and L_TCCR0(WGM01) = '0' and L_TCCR0(WGM00) = '0')
										else L_PORTB(OC0); 																														-- PORTB(3)=OC0

	 -- SPI
	 L_PORTB_MOSI	<= S_MOSI 			when L_SPCR(SPE) = '1' and L_SPCR(MSTR) = '1' else L_PORTB(SPI_MOSI); 											-- PORTB(5)=MOSI
	 L_PORTB_MISO	<= I_PORT_B(SPI_MISO) when (L_SPCR(SPE) = '1' and L_SPCR(MSTR) = '1') or L_DDRB(SPI_MISO) = '0' else L_PORTB(SPI_MISO); -- PORTB(6)=MISO
	 L_PORTB_SCK	<= S_SCK 			when L_SPCR(SPE) = '1' and L_SPCR(MSTR) = '1' else L_PORTB(SPI_SCK); 											-- PORTB(7)=SCK
	 -- USART
	 L_UBRR			<= L_UBRRH(6 downto 0) & L_UBRRL;
	 L_PORTD_TX		<= U_TX when L_UCSRB(TXEN) = '1' or U_TX_inRun = '1'
								  else I_PORT_D(USART_TX) when L_DDRD(USART_TX) = '0' 
								  else L_PORTD(USART_TX);																														-- PORTD(1)=TX
	 L_PORTD_RX		<= I_PORT_D(USART_RX) when L_UCSRB(RXEN) = '1' or L_DDRD(USART_RX) = '0' else L_PORTD(USART_RX);								-- PORTD(0)=RX

    -- IO write process for simple registers
    --	 
    iowr: process(I_CLK)
    begin
        if (rising_edge(I_CLK)) then
            
				-- From procesor
				--
				if (I_CLR = '1') then
				
					L_DDRA 	<= (others => '0');
					L_PORTA 	<= (others => '0');
					L_DDRB 	<= (others => '0');
					L_PORTB 	<= (others => '0');
					L_DDRC 	<= (others => '0');
					L_PORTC 	<= (others => '0');
					L_DDRD 	<= (others => '0');
					L_PORTD 	<= (others => '0');
					L_TCCR0 	<= (others => '0');
					L_TIMSK 	<= (others => '0');
					L_SPCR	<= (others => '0');
					L_UBRRL	<= (others => '0');
					L_UCSRB	<= (others => '0');
					L_SPSR	<= '0';
					
				elsif (I_WE_IO = '1') then
                case I_ADR_IO is
					 
						when X"29"	=> L_UBRRL	<= I_DIN;								-- UBRRL
						when X"2A"	=> L_UCSRB	<= I_DIN;								-- UCSRB
						when X"2D"	=> L_SPCR	<= I_DIN;								-- SPCR
						when X"2E"	=> L_SPSR	<= I_DIN(SPI2X);						-- SPSR only bit SPI2X
						when X"31"  => L_DDRD 	<= I_DIN;       						-- DDRD
						when X"32"  => L_PORTD 	<= I_DIN;		 						-- PORTD
						when X"34"  => L_DDRC 	<= I_DIN; 								-- DDRC
						when X"35"  => L_PORTC 	<= I_DIN; 								-- PORTC
						when X"37"  => L_DDRB 	<= I_DIN;		 						-- DDRB
						when X"38"  => L_PORTB 	<= I_DIN;		 						-- PORTB
						when X"3A"  => L_DDRA 	<= I_DIN;		 						-- DDRA
						when X"3B"  => L_PORTA 	<= I_DIN;		 						-- PORTA
						when X"53"  => L_TCCR0 	<= I_DIN(6 downto 0);   			-- TCCR0 (FOC0 only for read)
						when X"59"  => L_TIMSK 	<= I_DIN;		 						-- TIMSK
                  when others =>
                end case;
            end if;
        end if;
    end process;
	 
   -- IO write process for shared registers
    --	 
    iowr_shared: process(I_CLK)
    begin
        if (rising_edge(I_CLK)) then
				
				if (I_CLR = '1') then				
					L_UBRRH 	<= (others => '0');
					L_UCSRC 	<= (others => '0');					
				elsif (I_WE_IO = '1') then
                
					 if I_ADR_IO = X"40" and I_DIN(URSEL) = '1' then
						L_UCSRC	<= I_DIN;
					 elsif I_ADR_IO = X"40" and I_DIN(URSEL) = '0' then
						L_UBRRH	<= I_DIN;
					 else
						null;
					 end if;
					 
            end if;
        end if;
    end process;
	 
	 

	 -- PIN read proces (DDR='0' read input; ='1' read PORT)
	 L_PINA(0) <= I_PORT_A(0) when L_DDRA(0) = '0' else L_PORTA(0);
	 L_PINA(1) <= I_PORT_A(1) when L_DDRA(1) = '0' else L_PORTA(1);
	 L_PINA(2) <= I_PORT_A(2) when L_DDRA(2) = '0' else L_PORTA(2);
	 L_PINA(3) <= I_PORT_A(3) when L_DDRA(3) = '0' else L_PORTA(3);
	 L_PINA(4) <= I_PORT_A(4) when L_DDRA(4) = '0' else L_PORTA(4);
	 L_PINA(5) <= I_PORT_A(5) when L_DDRA(5) = '0' else L_PORTA(5);
	 L_PINA(6) <= I_PORT_A(6) when L_DDRA(6) = '0' else L_PORTA(6);
	 L_PINA(7) <= I_PORT_A(7) when L_DDRA(7) = '0' else L_PORTA(7);

	 L_PINB(0) <= I_PORT_B(0) when L_DDRB(0) = '0' else L_PORTB(0);
	 L_PINB(1) <= I_PORT_B(1) when L_DDRB(1) = '0' else L_PORTB(1);
	 L_PINB(2) <= I_PORT_B(2) when L_DDRB(2) = '0' else L_PORTB(2);
	 L_PINB(OC0) <= I_PORT_B(OC0) when L_DDRB(OC0) = '0' else L_PORTB_OC0;							-- OC0
	 L_PINB(SPI_SS) <= I_PORT_B(SPI_SS) when L_DDRB(SPI_SS) = '0' else L_PORTB(4);				-- SPI SS
	 L_PINB(SPI_MOSI) <= I_PORT_B(SPI_MOSI) when L_DDRB(SPI_MOSI) = '0' else L_PORTB_MOSI;		-- SPI MOSI
	 L_PINB(SPI_MISO) <= L_PORTB_MISO;																			-- SPI MISO
	 L_PINB(SPI_SCK) <= I_PORT_B(SPI_SCK) when L_DDRB(SPI_SCK) = '0' else L_PORTB_SCK;			-- SPI SCK
	 
	 L_PINC(0) <= I_PORT_C(0) when L_DDRC(0) = '0' else L_PORTC(0);
	 L_PINC(1) <= I_PORT_C(1) when L_DDRC(1) = '0' else L_PORTC(1);
	 L_PINC(2) <= I_PORT_C(2) when L_DDRC(2) = '0' else L_PORTC(2);
	 L_PINC(3) <= I_PORT_C(3) when L_DDRC(3) = '0' else L_PORTC(3);
	 L_PINC(4) <= I_PORT_C(4) when L_DDRC(4) = '0' else L_PORTC(4);
	 L_PINC(5) <= I_PORT_C(5) when L_DDRC(5) = '0' else L_PORTC(5);
	 L_PINC(6) <= I_PORT_C(6) when L_DDRC(6) = '0' else L_PORTC(6);
	 L_PINC(7) <= I_PORT_C(7) when L_DDRC(7) = '0' else L_PORTC(7);
	 
 	 L_PIND(USART_RX) <= L_PORTD_RX;																				-- RX
	 L_PIND(USART_TX) <= L_PORTD_TX;																				-- TX
	 L_PIND(2) <= I_PORT_D(2) when L_DDRD(2) = '0' else L_PORTD(2);
	 L_PIND(3) <= I_PORT_D(3) when L_DDRD(3) = '0' else L_PORTD(3);
	 L_PIND(4) <= I_PORT_D(4) when L_DDRD(4) = '0' else L_PORTD(4);
	 L_PIND(5) <= I_PORT_D(5) when L_DDRD(5) = '0' else L_PORTD(5);
	 L_PIND(6) <= I_PORT_D(6) when L_DDRD(6) = '0' else L_PORTD(6);
	 L_PIND(7) <= I_PORT_D(7) when L_DDRD(7) = '0' else L_PORTD(7);

	 Q_PORT_A <= L_PORTA;
	 Q_PORT_B <= L_PORTB_SCK & L_PORTB(6) & L_PORTB_MOSI & L_PORTB(4) & L_PORTB_OC0 & L_PORTB(2 downto 0);
	 Q_PORT_C <= L_PORTC;
	 Q_PORT_D <= L_PORTD(7 downto 2) & L_PORTD_TX & L_PORTD(0);


end Behavioral;
