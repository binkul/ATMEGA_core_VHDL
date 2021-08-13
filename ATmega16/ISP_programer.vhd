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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity ISP_Programer is
    Port ( I_Clk 					: in  STD_LOGIC;										-- 50 MHz
			  I_Clr					: in 	STD_LOGIC;										-- main reset (not SPI reset)
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
end ISP_Programer;

architecture Behavioral of ISP_Programer is


-- ################################################ components ##########################################
component SPI_driver
  PORT (
			  I_Clk 					: in  STD_LOGIC;										-- 50 MHz
			  I_Clr					: in  STD_LOGIC;										-- main reset (not SPI reset)
			  I_RESET 				: in  STD_LOGIC;										-- SPI RESET
           I_MOSI 				: in  STD_LOGIC;										-- SPI MOSI
           I_SCK 					: in  STD_LOGIC;										-- SPI SCK
			  I_Busy					: in  STD_LOGIC;										-- busy for zeroing or programing
			  I_FuseLock 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse Lock
			  I_FuseBitsL 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse low
			  I_FuseBitsH 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse high
			  I_FLASH_from_AVR	: in  STD_LOGIC_VECTOR (15 downto 0);			-- read data from AVR

           Q_MISO 				: out STD_LOGIC;										-- SPI MISO
			  Q_ProgEnable			: out STD_LOGIC;										-- '1' - unblock for programing after 'ProgramEnable' command
			  Q_FLASH_adr_AVR_RD	: out  STD_LOGIC_VECTOR (12 downto 0);			-- read adress particular RAM - 11-0, but bit 0 is even/odd
			  Q_Command				: out STD_LOGIC_VECTOR (31 downto 0);			-- read command
			  Q_CommandReady		: out STD_LOGIC										-- signal commend read of particular byte, active '1'
			);
end component;


-- ################################################ sta�e i zmienne ###############################################

-- const
constant MainModeOperation	: std_logic_vector (7 downto 0) := x"AC"; -- I-st byte
constant LoadMemPage_H		: std_logic_vector (7 downto 0) := x"48";
constant LoadMemPage_L		: std_logic_vector (7 downto 0) := x"40";
constant WriteMemPage		: std_logic_vector (7 downto 0) := x"4C";
constant ReadEepromMem		: std_logic_vector (7 downto 0) := x"A0";
constant WriteEepromMem		: std_logic_vector (7 downto 0) := x"C0";

constant StartProgramISP	: std_logic_vector (7 downto 0) := x"53"; -- II-ond byte
constant ChipErase			: std_logic_vector (7 downto 0) := x"80";
constant WriteLockBits		: std_logic_vector (7 downto 0) := x"E0";
constant WriteFuseBits		: std_logic_vector (7 downto 0) := x"A0";
constant WriteFuseBitsHigh	: std_logic_vector (7 downto 0) := x"A8";

constant Memory_area			: std_logic_vector (11 downto 0) := x"FFF"; 		-- max capacity of mempry (word, not byte) to clear Atmega16 - 8 KW
constant Page_area			: std_logic_vector (5 downto 0) := "111111"; 	-- size page area - 64 word

-- automat
type AutomatMaster_type is ( 	ST_INIT,
										ST_WAIT_FOR_COMMAND,
										ST_COMM_ANALIZE,
										ST_ERASE_MEMORY,
										ST_LOAD_PAGE);
signal AutomatMaster 			: AutomatMaster_type := ST_INIT;

-- tablica Program Memory Page
type MemoryType is array (0 to 63) of std_logic_vector (7 downto 0);			-- Program Memory Page
signal ProgramMemoryPage_H : MemoryType := (others => (others => '1'));		-- set on 'FFFF'
signal ProgramMemoryPage_L : MemoryType := (others => (others => '1'));		-- set on 'FFFF'
signal P_AdrMemoryPage : std_logic_vector (5 downto 0);							-- counter of page adress (64 word)

-- zmienne
signal P_FuseLock 		: std_logic_vector (7 downto 0) := "11111111";		-- Fuse Lock						
signal P_FuseBitsL 		: std_logic_vector (7 downto 0) := "11100001";		-- Fuse Bits Low					
signal P_FuseBitsH 		: std_logic_vector (7 downto 0) := "10011001";		-- Fuse Bits High					
signal P_Command			: std_logic_vector (31 downto 0);						-- command read from ISP
signal P_Busy				: std_logic;													-- '1' - busy Erase or program memory
signal P_CommandReady	: std_logic;													-- enter, command was read, active '1'
signal P_AVRData			: std_logic_vector (15 downto 0);						-- data to write to AVR
signal P_AVRAdr			: std_logic_vector (12 downto 0);						-- adress in AVR
signal P_RW					: std_logic;													-- '0' - read, '1' - write to AVR during programming
signal P_Del				: std_logic;													-- '1' - erase of memory
signal P_WriteCounter 	: std_logic_vector (5 downto 0);							-- counter for write to Memory Page 0-64 word
signal P_Counter			: std_logic_vector (11 downto 0);						-- counter to erase memory



begin

-- ########################################## main automat ##############################################
P_AdrMemoryPage <= P_Command (13 downto 8);

ISP_automat : process(I_clk, I_Clr)
begin
	if I_Clr = '0' then	
		P_Busy					<= '0';
		P_RW						<= '0';
		P_Del						<= '0';
		P_AVRAdr					<= (others => '0');
		P_WriteCounter			<= (others => '0');
		P_Counter				<= (others => '0');
		P_AVRData				<= (others => '0');
		AutomatMaster 			<= ST_INIT;
	else
		if I_clk'event and I_clk = '1' then
		
			-- ## default value
			P_RW					<= '0';
			P_Del					<= '0';
			P_Busy				<= '0';

			-- ## automat
			case AutomatMaster is

				-- # prepare signals
				when ST_INIT =>
					AutomatMaster 	<= ST_WAIT_FOR_COMMAND;					
				
				
				-- # wait for full command
				when ST_WAIT_FOR_COMMAND =>
					if P_CommandReady = '0' then
						AutomatMaster <= ST_WAIT_FOR_COMMAND;
					else
						AutomatMaster 	<= ST_COMM_ANALIZE;						
					end if;


				-- # analize command
				when ST_COMM_ANALIZE =>
				
					-- caommand x"AC"
					if P_Command (31 downto 24) = MainModeOperation then
						
						-- erase memeory
						if P_Command (23 downto 16) = ChipErase then
							P_AVRAdr			<= (others => '0');
							P_Counter		<= (others => '0');
							P_AVRData		<= x"FFFF";
							P_Busy			<= '1';
							P_Del				<= '1';
							AutomatMaster 	<= ST_ERASE_MEMORY;	

						-- write fuse lock
						elsif P_Command (23 downto 16) = WriteLockBits then
							P_FuseLock			<= P_Command (7 downto 0);
							AutomatMaster 		<= ST_INIT;	
							
						-- write fuse Low
						elsif P_Command (23 downto 16) = WriteFuseBits then
							P_FuseBitsL			<= P_Command (7 downto 0);
							AutomatMaster 		<= ST_INIT;	
					
						-- write fuse High
						elsif P_Command (23 downto 16) = WriteFuseBitsHigh then
							P_FuseBitsH			<= P_Command (7 downto 0);
							AutomatMaster 		<= ST_INIT;	
						
						-- in other case do nothing
						else
							null;
						end if;
						
					-- load memory page with MSB
					elsif P_Command (31 downto 24) = LoadMemPage_H then
						ProgramMemoryPage_H (conv_integer(P_AdrMemoryPage)) <= P_Command (7 downto 0);
						AutomatMaster 		<= ST_INIT;	
						
					-- load memory page with LSB
					elsif P_Command (31 downto 24) = LoadMemPage_L then
						ProgramMemoryPage_L (conv_integer(P_AdrMemoryPage)) <= P_Command (7 downto 0);
						AutomatMaster 		<= ST_INIT;	

					-- write memory page to memory
					elsif P_Command (31 downto 24) = WriteMemPage then
						P_AVRAdr			<= P_Command (20 downto 14) & "000000";
						P_WriteCounter	<= "000001"; -- zaczynaj od 1, bo odczyt pami�ci jest opu�niony o 1 cykl
						P_AVRData		<= ProgramMemoryPage_H (0) & ProgramMemoryPage_L (0);
						P_Busy			<= '1';
						P_RW				<= '1';
						AutomatMaster 	<= ST_LOAD_PAGE;	

					-- in other case do nothing
					else
						AutomatMaster 		<= ST_INIT;					
					end if;


				-- # erase memory
				when ST_ERASE_MEMORY =>
					P_Counter 	<= P_Counter + 1;
					P_AVRAdr 	<= P_AVRAdr + 1;
					P_AVRData	<= x"FFFF";
					if P_Counter < Memory_area then
						P_Busy		<= '1';
						P_Del			<= '1';
						AutomatMaster 	<= ST_ERASE_MEMORY;											
					else
						P_Busy		<= '0';
						P_Del			<= '0';
						AutomatMaster 	<= ST_INIT;																	
					end if;


				-- # write Memory Page do memory
				when ST_LOAD_PAGE =>
					P_RW				<= '1';
					P_WriteCounter <= P_WriteCounter + 1;
					P_AVRAdr 		<= P_AVRAdr + 1;
					P_AVRData		<= ProgramMemoryPage_H (conv_integer(P_WriteCounter)) & ProgramMemoryPage_L (conv_integer(P_WriteCounter));
					if P_WriteCounter < Page_area then
						P_Busy		<= '1';
						AutomatMaster 	<= ST_LOAD_PAGE;											
					else
						P_Busy		<= '0';
						AutomatMaster 	<= ST_INIT;																	
					end if;

			end case;
			
		end if; -- if I_clk'event and I_clk = '1' then
	end if; -- if I_RESET = '1' then

end process;
-- #####################################################  end #################################################



-- ############################################ outside signals ##############################################
Q_FLASH_to_AVR			<= P_AVRData;
Q_FLASH_adr_AVR 		<= P_AVRAdr (12 downto 1) when P_Del = '0' else P_AVRAdr (11 downto 0);				-- P_Del='1' erase both memry at once
Q_FLASH_WE_Load(1)	<= (P_AVRAdr(0) and P_RW) when P_Del = '0' else '1';
Q_FLASH_WE_Load(0)	<= ((not P_AVRAdr(0)) and P_RW) when P_Del = '0' else '1';
-- #####################################################  end #################################################



-- ####################################### port map ###########################################################
SPI_read : SPI_driver PORT MAP
			(
			  I_Clk 					=> I_Clk,
			  I_Clr					=> I_Clr,
			  I_RESET 				=> I_RESET,
           I_MOSI 				=> I_MOSI,
           I_SCK 					=> I_SCK,
			  I_Busy					=> P_Busy,
			  I_FuseLock 			=> P_FuseLock,
			  I_FuseBitsL 			=> P_FuseBitsL,
			  I_FuseBitsH 			=> P_FuseBitsH,
			  I_FLASH_from_AVR	=> I_FLASH_from_AVR,

           Q_MISO 				=> Q_MISO,
			  Q_ProgEnable			=> Q_ProgEnable,
			  Q_FLASH_adr_AVR_RD	=> Q_FLASH_adr_AVR_RD,
			  Q_Command				=> P_Command,
			  Q_CommandReady		=> P_CommandReady
			);
-- #####################################################  end #####################################################

end Behavioral;





-- ***************************************** Module SPI register **************************************************
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SPI_driver is 
	 Port ( I_Clk 					: in  STD_LOGIC;										-- 50 MHz
			  I_Clr					: in  STD_LOGIC;										-- main reset (not SPI reset)
			  I_RESET 				: in  STD_LOGIC;										-- SPI RESET
           I_MOSI 				: in  STD_LOGIC;										-- SPI MOSI
           I_SCK 					: in  STD_LOGIC;										-- SPI SCK
			  I_Busy					: in  STD_LOGIC;										-- busy for zeroing or programing
			  I_FuseLock 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse Lock
			  I_FuseBitsL 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse low
			  I_FuseBitsH 			: in  STD_LOGIC_VECTOR (7 downto 0);			-- fuse high
			  I_FLASH_from_AVR	: in  STD_LOGIC_VECTOR (15 downto 0);			-- read data from AVR

           Q_MISO 				: out STD_LOGIC;										-- SPI MISO
			  Q_ProgEnable			: out STD_LOGIC;										-- '1' - unblock for programing after 'ProgramEnable' command
			  Q_FLASH_adr_AVR_RD	: out  STD_LOGIC_VECTOR (12 downto 0);			-- read adress particular RAM - 11-0, but bit 0 is even/odd
			  Q_Command				: out STD_LOGIC_VECTOR (31 downto 0);			-- read command
			  Q_CommandReady		: out STD_LOGIC										-- signal commend read of particular byte, active '1'
			 );
end SPI_driver;

architecture Behavioral of SPI_driver is

-- sta�e
constant ProgramEnable		: std_logic_vector (31 downto 0) := x"AC530000";

constant SignatureByteRead	: std_logic_vector (7 downto 0) := x"30";
constant ReadLockBits		: std_logic_vector (7 downto 0) := x"58";
constant ReadFuseBitsH_1	: std_logic_vector (7 downto 0) := x"08";
constant ReadFuseBits		: std_logic_vector (7 downto 0) := x"50";
constant ReadCalibBits		: std_logic_vector (7 downto 0) := x"38";
constant ReadProgramMem_H	: std_logic_vector (7 downto 0) := x"28";
constant ReadProgramMem_L	: std_logic_vector (7 downto 0) := x"20";
constant Busy					: std_logic_vector (7 downto 0) := x"F0";

constant SignatureByte_0	: std_logic_vector (7 downto 0) := x"1E"; 		-- Atmega16 signature bytes
constant SignatureByte_1	: std_logic_vector (7 downto 0) := x"94";
constant SignatureByte_2	: std_logic_vector (7 downto 0) := x"03";
constant CalibByte			: std_logic_vector (7 downto 0) := x"00";

-- sygna�y wewn�trzne
signal S_Reset				: std_logic := '1';																	-- internal reset, active '0'
signal S_Command 			: std_logic_vector (31 downto 0) := (others => '1');						-- read command
signal S_Command_tmp 	: std_logic_vector (31 downto 0);												-- command one cycle before
signal S_CommandReady	: std_logic := '0';																	-- read ready command
signal S_ByteOut			: std_logic_vector (7 downto 0) := (others => '0');						-- byte to send
signal S_AdressRead 		: std_logic_vector (12 downto 0);												-- adress to read
signal S_BitCount			: std_logic_vector (4 downto 0) := (others => '0');						-- byte read counter
signal S_Synchro			: std_logic_vector (2 downto 0) := (others => '0');						-- clock synchronizaion
signal S_ProgEnable		: std_logic := '0';																	-- '1' unblock programing


begin

-- ##################################  synchro clock 50MHz with SCK clock #################################
	process (I_clk, I_Clr)
	begin
		if I_Clr = '0' then
			S_Reset				<= '0';
			S_ProgEnable		<= '0';
			S_Synchro			<= (others => '0');
		else
			if I_clk'event and I_clk = '1' then
			
				-- synchronize clocks
				S_Synchro 	<= S_Synchro (1 downto 0) & I_SCK;
			
				-- active reset signal after 'Program Enable' command
				if S_Command = ProgramEnable then
					S_Reset			<= '0';						-- automat reset
				else
					S_Reset			<= '1';
				end if;

				-- active signal progEnable
				if I_RESET = '0' then
					if S_Command = ProgramEnable then
						S_ProgEnable	<= '1';
					else
						null;
					end if;
				else
					S_ProgEnable	<= '0';				
				end if;
				
			
			end if;
		end if;
	end process;
-- #####################################################  end ####################################################




-- #########################################  module SPI + byte send #############################################

	-- get full command - rising edge
	S_Command_tmp	<= S_Command (30 downto 0) & I_MOSI;
	-- get adress after read operation
	S_AdressRead	<= S_Command_tmp (12 downto 0);


	process (I_clk, S_Reset)
	begin
	
		if S_Reset = '0' then
			S_Command 		<= (others => '0');
			S_BitCount 		<= (others => '0');
			S_CommandReady	<= '0';
		
		else
			if I_clk'event and I_clk = '1' then

				-- ### clear signal command ready
				S_CommandReady	<= '0';				

				-- ### at signal synchro
				if S_Synchro = "011" then
 		
					-- ## shift register
					S_Command 	<= S_Command_tmp;
					S_ByteOut	<= S_ByteOut (6 downto 0) & I_MOSI;
					S_BitCount	<= S_BitCount + 1;
	
					-- ## only at unblock
					if S_ProgEnable = '1' then
					
						-- # read full command
						if S_BitCount = "11111" then
							S_CommandReady	<= '1';
							
						-- # command analize
						elsif S_BitCount = "10111" then
							case S_Command_tmp (23 downto 16) is
					
								-- read signature byte
								when SignatureByteRead =>
									if S_Command_tmp (15 downto 0) = x"0000" then
										S_ByteOut <= SignatureByte_0;							
									elsif S_Command_tmp (15 downto 0) = x"0001" then
										S_ByteOut <= SignatureByte_1;							
									else
										S_ByteOut <= SignatureByte_2;
									end if;

								-- read Fuse Lock Byte and Fuse Byte High
								when ReadLockBits =>
									if S_Command_tmp (15 downto 0) = x"0000" then
										S_ByteOut <= I_FuseLock;							
									else
										S_ByteOut <= I_FuseBitsH;
									end if;
							
								-- read Fuse Byte Low
								when ReadFuseBits =>
									if S_Command_tmp (15 downto 0) = x"0000" then
										S_ByteOut <= I_FuseBitsL;							
									else
										S_ByteOut <= x"FF";
									end if;
						
								-- read Calibration byte
								when ReadCalibBits =>
									S_ByteOut <= CalibByte;							

								-- read Program Memory High Byte
								when ReadProgramMem_H =>
									if I_Busy = '0' then
										S_ByteOut <= I_FLASH_from_AVR (15 downto 8);
									else
										S_ByteOut <= x"FF";								
									end if;
						
								-- read Program Memory Low Byte
								when ReadProgramMem_L =>
									if I_Busy = '0' then
										S_ByteOut <= I_FLASH_from_AVR (7 downto 0);
									else
										S_ByteOut <= x"FF";								
									end if;
									
								-- wait for busy
								when Busy =>
									if I_Busy = '0' then
										S_ByteOut <= x"00";
									else
										S_ByteOut <= x"FF";								
									end if;
						
								-- do nothing
								when others =>
									null;
							
							end case;
						
						else
							null;
						end if; --if S_BitCount = "10111" then
						
					else
						null;
					end if; -- if S_ProgEnable = '1' then
					
				else
					null;
				end if; --if S_Synchro = "011" then
		
			end if; --if I_clk'event and I_clk = '1' then
		end if; --if S_Reset = '0' then
	
	end process;
	

-- #####################################################  end ####################################################




-- ##############################################  outside signals ###############################################
	Q_MISO					<= S_ByteOut (7);
	Q_Command				<= S_Command;
	Q_CommandReady			<= S_CommandReady;
	Q_FLASH_adr_AVR_RD	<= S_AdressRead;
	Q_ProgEnable			<= S_ProgEnable;
-- #####################################################  end ####################################################



end Behavioral;


