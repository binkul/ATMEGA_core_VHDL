----------------------------------------------------------------------------------
-- Company: 		 Dom
-- Engineer: 		 Jacek Binkul
-- 
-- Create Date:    08:31:40 01/02/2018 
-- Design Name: 
-- Module Name:    Atmega16_core - Behavioral
-- Memory usage:	 139264 bits from 423936 available (33%)
-- Project Name: 	 Atmega16 soft core processor
-- Target Devices: Cyclone IVCE10
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Atmega16_core is
    Port ( I_Clk 			: in  STD_LOGIC;													-- clock 25 MHz
			  I_Clk_per		: in  STD_LOGIC;													-- clock 50 MHz for peripherials
			  I_CLR			: in  STD_LOGIC;													-- main reset - active '0' - loading program during '0'
           I_RESET_pr	: in  STD_LOGIC;													-- Program SPI reset - active '0'
           I_MOSI_pr		: in  STD_LOGIC;													-- Program SPI MOSI
			  I_SCK_pr		: in  STD_LOGIC;													-- Program SPI SCK
			  I_PORTA		: in  STD_LOGIC_VECTOR (7 downto 0);						-- input PORTA
			  I_PORTB		: in  STD_LOGIC_VECTOR (7 downto 0);						-- input PORTB
			  I_PORTC		: in  STD_LOGIC_VECTOR (7 downto 0);						-- input PORTC
			  I_PORTD		: in  STD_LOGIC_VECTOR (7 downto 0);						-- input PORTD
			  	  
           Q_MISO_pr		: out  STD_LOGIC;													-- Program SPI MISO
			  Q_PORTA		: out  STD_LOGIC_VECTOR (7 downto 0);						-- PORTA
			  Q_PORTB		: out  STD_LOGIC_VECTOR (7 downto 0);						-- PORTB
			  Q_PORTC		: out  STD_LOGIC_VECTOR (7 downto 0);						-- PORTC
			  Q_PORTD		: out  STD_LOGIC_VECTOR (7 downto 0)						-- PORTD
			);  		  
end Atmega16_core;



architecture Behavioral of Atmega16_core is


-- ######################################### component definition #####################################################

component ISP_programer
  port (	  I_Clk 					: in  STD_LOGIC;										-- 50 MHz
 			  I_Clr					: in 	STD_LOGIC;										-- main reset (not SPI)
           I_RESET 				: in  STD_LOGIC;										-- SPI RESET
           I_SCK 					: in  STD_LOGIC;										-- SPI SCK
           I_MOSI 				: in  STD_LOGIC;										-- SPI MOSI
			  I_FLASH_from_AVR	: in  STD_LOGIC_VECTOR  (15 downto 0);			-- read data from AVR
			  
           Q_MISO 				: out  STD_LOGIC;										-- SPI MISO
			  Q_ProgEnable			: out  STD_LOGIC;										-- '1' - unblock for programing after 'ProgramEnable' command
			  Q_FLASH_adr_AVR_RD	: out  STD_LOGIC_VECTOR (12 downto 0);			-- read adress particular RAM - 11-0, but bit 0 is even/odd
           Q_FLASH_to_AVR 		: out  STD_LOGIC_VECTOR (15 downto 0);			-- data to write to AVR
			  Q_FLASH_adr_AVR		: out  STD_LOGIC_VECTOR (11 downto 0);			-- read/write adress to AVR for max 16 Kb (8 Kb - two banks, 4 Kbx16bit per bank)
			  Q_FLASH_WE_Load		: out  STD_LOGIC_VECTOR (1 downto 0)			-- "01" Even memory, "10" Odd memory
			);
end component;

signal S_Flash_From_ROM			: std_logic_vector (15 downto 0);
signal S_Flash_From_ROM_adr	: std_logic_vector (12 downto 0);
signal S_Flash_To_ROM_Data		: std_logic_vector (15 downto 0);
signal S_Flash_To_ROM_adr		: std_logic_vector (11 downto 0);
signal S_Flash_To_ROM_WE		: std_logic_vector (1 downto 0);


component cpu_core
    port (  I_CLK       		: in  std_logic;   									-- clock max 25 MHz
            I_CLR       		: in  std_logic;
            I_INTVEC    		: in  std_logic_vector( 5 downto 0);
            I_DIN       		: in  std_logic_vector( 7 downto 0);

				I_LOAD				: in  std_logic;							 			-- '0' - load of rom content via ISP
				Q_DATA_From 		: out std_logic_vector (15 downto 0);			-- Data Read from Flash
				I_ADR_From			: in std_logic_vector (12 downto 0);			-- ADRess to read from Flash (bit 0 - even/odd)
				I_DATA_To 			: in std_logic_vector (15 downto 0);			-- Data to write to Flash
				I_ADR_To	 			: in std_logic_vector (11 downto 0);			-- Adres to write to Flash
				I_WE_To				: in std_logic_vector (1 downto 0);				-- WE to write '01'-even, '10'-odd, '00'-none

            Q_OPC       		: out std_logic_vector(15 downto 0);
            Q_PC        		: out std_logic_vector(15 downto 0);
            Q_DOUT      		: out std_logic_vector( 7 downto 0);
            Q_ADR_IO    		: out std_logic_vector( 7 downto 0);
            Q_RD_IO     		: out std_logic;
            Q_WE_IO     		: out std_logic;
				Q_Int_Ack			: out std_logic;
				Q_Int_Vect			: out std_logic_vector( 4 downto 0));
end component;

signal  C_PC            		: std_logic_vector(15 downto 0);
signal  C_OPC           		: std_logic_vector(15 downto 0);
signal  C_ADR_IO        		: std_logic_vector( 7 downto 0);
signal  C_DOUT          		: std_logic_vector( 7 downto 0);
signal  C_RD_IO         		: std_logic;
signal  C_WE_IO         		: std_logic;
signal  C_Int_Ack					: std_logic;
signal  C_Int_Vect				: std_logic_vector( 4 downto 0);


component io
    port (  I_CLK       		: in  std_logic;
				I_Clk_per			: in  std_logic;
            I_CLR       		: in  std_logic;
            I_ADR_IO    		: in  std_logic_vector( 7 downto 0);
            I_DIN       		: in  std_logic_vector( 7 downto 0);
            I_RD_IO     		: in  std_logic;
            I_WE_IO     		: in  std_logic;
				I_PORT_A				: in  std_logic_vector( 7 downto 0);
				I_PORT_B				: in  std_logic_vector( 7 downto 0);
				I_PORT_C				: in  std_logic_vector( 7 downto 0);
				I_PORT_D				: in  std_logic_vector( 7 downto 0);
				I_Int_Ack			: in  std_logic;
				I_Int_Vect			: in  std_logic_vector( 4 downto 0);

            Q_DOUT      		: out std_logic_vector( 7 downto 0);
				Q_PORT_A				: out std_logic_vector( 7 downto 0);
				Q_PORT_B				: out std_logic_vector( 7 downto 0);
				Q_PORT_C				: out std_logic_vector( 7 downto 0);
				Q_PORT_D				: out std_logic_vector( 7 downto 0);
            Q_INTVEC    		: out std_logic_vector( 5 downto 0));

end component;

signal IO_DOUT			   		: std_logic_vector( 7 downto 0);
signal IO_INTVEC					: std_logic_vector( 5 downto 0);

signal L_ProgramReset			: std_logic := '0';
signal L_ResetDeb					: std_logic_vector( 5 downto 0) := (others => '0');
signal L_Clr						: std_logic;
signal L_ProgEnable				: std_logic;
signal L_Load						: std_logic;


begin


-- ######################################### reset procedure ###########################################################
	L_ProgramReset <= I_CLR and I_RESET_pr;
	process(I_Clk)
		begin
			if I_Clk'event and I_Clk = '1' then
				L_ResetDeb	<= L_ResetDeb(4 downto 0) & L_ProgramReset;
			end if;
	end process;
	-- total reset after 6 clock of the end of programing cycle
	L_Clr		<= '0' when L_ResetDeb = "111111" else '1';
	L_Load	<= not L_ProgEnable;
-- ################################################## end ##############################################################




-- ######################################### component connection #####################################################

	 -- memory program
	 --
	 ISP_prog : ISP_programer  
	 port map( 	I_Clk 					=> I_Clk,
					I_Clr						=> I_CLR,
					I_RESET 					=> I_RESET_pr,
					I_SCK 					=> I_SCK_pr,
					I_MOSI 					=> I_MOSI_pr,
					I_FLASH_from_AVR		=> S_Flash_From_ROM,
			  
					Q_MISO 					=> Q_MISO_pr,
					Q_ProgEnable			=> L_ProgEnable,
					Q_FLASH_adr_AVR_RD	=> S_Flash_From_ROM_adr,
					Q_FLASH_to_AVR 		=> S_Flash_To_ROM_Data,
					Q_FLASH_adr_AVR		=> S_Flash_To_ROM_adr,
					Q_FLASH_WE_Load		=> S_Flash_To_ROM_WE);													
	 

	 -- cpu procesor
	 --
    cpu : cpu_core
    port map(   I_CLK       			=> I_Clk,
                I_CLR       			=> L_Clr,
                I_DIN       			=> IO_DOUT,
                I_INTVEC    			=> IO_INTVEC,

					 I_LOAD		 			=> L_Load,
					 Q_DATA_From 			=> S_Flash_From_ROM,
					 I_ADR_From	 			=> S_Flash_From_ROM_adr,
					 I_DATA_To 	 			=> S_Flash_To_ROM_Data,
					 I_ADR_To	 			=> S_Flash_To_ROM_adr,
					 I_WE_To		 			=> S_Flash_To_ROM_WE,

					 Q_ADR_IO    			=> C_ADR_IO,
                Q_DOUT      			=> C_DOUT,
                Q_OPC       			=> C_OPC,
                Q_PC        			=> C_PC,
                Q_RD_IO     			=> C_RD_IO,
                Q_WE_IO     			=> C_WE_IO,
					 Q_Int_Ack				=> C_Int_Ack,
					 Q_Int_Vect	 			=> C_Int_Vect);


	-- IO
	--
	IO_map : IO
   port map(	 I_CLK       			=> I_Clk,
					 I_Clk_per				=> I_Clk_per,
					 I_CLR       			=> L_Clr,
					 I_ADR_IO    			=> C_ADR_IO,
					 I_DIN       			=> C_DOUT,
					 I_RD_IO     			=> C_RD_IO,
					 I_WE_IO     			=> C_WE_IO,
					 I_PORT_A				=> I_PORTA,
					 I_PORT_B				=> I_PORTB,
					 I_PORT_C				=> I_PORTC,
					 I_PORT_D				=> I_PORTD,
					 I_Int_Ack				=> C_Int_Ack,
					 I_Int_Vect				=> C_Int_Vect,
					 
					 Q_DOUT      			=> IO_DOUT,
					 Q_PORT_A				=> Q_PORTA,
					 Q_PORT_B				=> Q_PORTB,
					 Q_PORT_C				=> Q_PORTC,
					 Q_PORT_D				=> Q_PORTD,
					 Q_INTVEC    			=> IO_INTVEC);




end Behavioral;

