----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    21:36:21 02/05/2018 
-- Design Name: 
-- Module Name:    Usart Atmega16 
-- Project Name: 
-- Target Devices: 
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
-- Onle single speed is allowed. It dont use U2X bit and dont use synchronus mode master/slave
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.all;

use work.common.ALL;
use work.Atmega16_reg.All;

entity Usart is
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
			  Q_TX_inRun	: out STD_LOGIC
			  );
end Usart;

architecture Behavioral of Usart is


-- ######################################### components #####################################################

component BaudGenerator
    Port ( I_Clk 			: in  STD_LOGIC;
           I_Clr 			: in  STD_LOGIC;
			  I_UBRR			: in  STD_LOGIC_VECTOR(14 downto 0);
			  I_RXEN			: in 	STD_LOGIC;
			  I_TXEN			: in 	STD_LOGIC;
			  I_RX_Clr		: in  STD_LOGIC;
			  I_TX_Clr		: in  STD_LOGIC;
			  I_TX_run		: in  STD_LOGIC;
			  
			  O_RX_en		: out STD_LOGIC;
			  O_TX_en		: out STD_LOGIC
			);
end component;

signal G_RX_en				: std_logic;
signal G_TX_en				: std_logic;

-- ############################################ locals ########################################################

-- types
subtype boudCount	is natural range 0 to 31;
subtype frameCount is natural range 0 to 15;

-- Sequential automat RX and TX
type AutomatMasterRX_type is (ST_WAIT_RX,
										ST_START_BIT,
										ST_DATA_RECEIVE,
										ST_ANALIZE);
signal AutomatMasterRX 			: AutomatMasterRX_type := ST_WAIT_RX;

-- Sequential automat RX and TX
type AutomatMasterTX_type is (ST_WAIT_TX,
										ST_SEND_DATA,
										ST_SEND_PARITY,
										ST_SEND_STOP);
signal AutomatMasterTX 			: AutomatMasterTX_type := ST_WAIT_TX;

-- signal common
signal L_dataBitsUsart	: std_logic_vector(2 downto 0);								-- combination UCSZ0-2
signal L_dataBits			: frameCount;														-- data bits in frame
signal L_parityBits		: frameCount;														-- parity bits per frame
signal L_stopBits			: frameCount;														-- stop bits in frame

-- signals RX
signal L_frameBitsRX		: frameCount;														-- total data bits in frame
signal L_RX_baudClr		: std_logic := '0';												-- '1' - reset signal for RX baud
signal L_rx_sync1			: std_logic;														-- faling edge detection
signal L_rx_sync2			: std_logic;
signal L_rx_main			: std_logic;
signal L_RX_baudCount	: boudCount;														-- counter EN signal
signal L_bit_Value		: std_logic;														-- recived '0' or '1' bit
signal L_bit_1				: std_logic;														
signal L_bit_2				: std_logic;
signal L_bit_3				: std_logic;
signal L_bit_all			: std_logic_vector(2 downto 0);								-- sum of bits 1, 2, 3
signal L_RX_bitCount		: frameCount;														-- bit counter
signal L_RX_receiver		: std_logic_vector(10 downto 0);								-- receiver register 9 bits + 1 parity + 2 stop
signal L_RX_dataL			: std_logic_vector(8 downto 0);								-- 9 bits from frame
signal L_RX_dataR			: std_logic_vector(8 downto 0);								-- 9 bits from frame right alligment
signal L_RX_stop			: std_logic;														-- and from stop bits
signal L_RX_even			: std_logic;														-- parity bit from frame
signal L_rec_evenM		: std_logic;														-- toal mux from data bits
signal L_rec_even			: std_logic;														-- calculated parity bit from frame
signal L_rec_odd			: std_logic;														-- calculated not parity bit from frame
signal L_rec_odd_even	: std_logic;														-- mux parity and not parity
signal L_rec_even5		: std_logic;														-- from frame - xor bits 0-4
signal L_rec_even6		: std_logic;														-- from frame - xor bits 0-5
signal L_rec_even7		: std_logic;														-- from frame - xor bits 0-6
signal L_rec_even8		: std_logic;														-- from frame - xor bits 0-7
signal L_rec_even9		: std_logic;														-- from frame - xor bits 0-8
signal L_RX_UDRen			: std_logic;														-- strob signal to write frame to USART registers
signal L_RX_UDR			: std_logic_vector(7 downto 0);								-- received bufor
signal L_UDR_Read			: std_logic;														-- '1' - read of received bufor
signal L_RXB8				: std_logic;														-- receiving of 9 bit of frame
signal L_FE					: std_logic;														-- bit FE
signal L_PE					: std_logic;														-- bit PE
signal L_DOR				: std_logic;														-- bit DOR
signal L_RXC				: std_logic;														-- bit data is waiting in bufor
signal L_RX_divCount		: std_logic_vector(10 downto 0);								-- counter to test receiving bit
signal L_RX_lastBit		: std_logic;														-- '1' - last bit is receiving

-- signal TX
signal L_TX					: std_logic := '1';												-- signal TX outside
signal L_TX_run			: std_logic := '0';												-- '1' transmision in progress
signal L_TXC				: std_logic	:= '0';												-- bit TXC
signal L_TXC_en			: std_logic := '0';												-- en do aktywowanie TXC - aktywny '1'
signal L_TX_baudClr		: std_logic := '0';												-- reset TX baud - active '1'
signal L_UDRE				: std_logic	:= '1';												-- bit UDRE
signal L_UDR_clr			: std_logic := '0';												-- set UDRE to '1'
signal L_UDR_write		: std_logic;														-- '1' - write to UDR register
signal L_TX_UDR			: std_logic_vector(7 downto 0);								-- transmiter buffer
signal L_TX_transmiter	: std_logic_vector(9 downto 0);								-- transmitt shifter 9 data bits + START bit
signal L_TX_bitCount		: frameCount;														-- counter for data bits to be send
signal L_tx_evenM			: std_logic;														-- for parity calculation
signal L_tx_even			: std_logic;														-- 
signal L_tx_odd			: std_logic;														-- 
signal L_tx_odd_even		: std_logic;														-- 
signal L_tx_even5			: std_logic;														-- 
signal L_tx_even6			: std_logic;														-- 
signal L_tx_even7			: std_logic;														-- 
signal L_tx_even8			: std_logic;														-- 
signal L_tx_even9			: std_logic;														-- 
signal L_TX_parityBit	: std_logic;														-- latch for parity bit

begin

-- ################################################# components #####################################################

	 -- baud generator
	 --
	 baud_Gen : BaudGenerator  
	 port map( 	I_Clk 			=> I_Clk,
					I_Clr				=> I_Clr,
					I_UBRR			=> I_UBRR,
					I_RXEN			=> I_UCSRB(RXEN),
					I_TXEN			=> I_UCSRB(TXEN),
					I_TX_run			=> L_TX_run,
					I_RX_Clr			=> L_RX_baudClr,
					I_TX_Clr			=> L_TX_baudClr,
					O_RX_en			=> G_RX_en,
					O_TX_en			=> G_TX_en
				);
-- ############################################# end components #####################################################





-- ########################################## RX and TX parameters ##################################################

	-- signal of the last receiving bit
	--
	L_RX_lastBit		<= 	'1' when L_RX_bitCount = L_frameBitsRX - 1 else '0';

	-- amount of the data bits in the frame rec/send 5, 6, 7, 8 lub 9
	--
	L_dataBitsUsart	<= I_UCSRB(UCSZ2) & I_UCSRC(UCSZ1) & I_UCSRC(UCSZ0);
	with L_dataBitsUsart select
		L_dataBits		<= 5 when "000",
								6 when "001",
								7 when "010",
								9 when "111",
								8 when others;
							
	-- parity bit (one or none)
	--
	L_parityBits		<= 1 when I_UCSRC(UPM1) = '1' else 0;
	
	-- total amount bits in frame RX - always one stop bit, the rest is ignoring
	--
	L_frameBitsRX		<= L_dataBits + L_parityBits + 1;
	
	-- type of received bit - '1' or '0'
	--
	L_bit_all <= L_bit_1 & L_bit_2 & L_bit_3;

	with L_bit_all select
	L_bit_Value <= '0' when "000",
						'0' when "001",
						'0' when "010",
						'1' when "011",
						'0' when "100",
						'1' when "101",
						'1' when "110",
						'1' when "111",
						'0' when others;

	-- get data bits from frame and alignt them to the right
	--
	L_RX_dataL	<= L_RX_receiver(8 downto 0) when I_UCSRC(UPM1) = '1' else L_RX_receiver(9 downto 1);
	
	with L_dataBitsUsart select
		L_RX_dataR		<= "0000" & L_RX_dataL(8 downto 4) when "000",
								"000" & L_RX_dataL(8 downto 3) when "001",
								"00" & L_RX_dataL(8 downto 2) when "010",
								L_RX_dataL(8 downto 0) when "111",
								"0" & L_RX_dataL(8 downto 1) when others;

	
	-- get stop bits
	--
	L_RX_stop 	<= L_RX_receiver(10);
	
	-- get parity bit, if it exist
	--
	L_RX_even	<= L_RX_receiver(9);
	
	-- calculate parity from received data
	--
	L_rec_even5	<= L_RX_dataR(4) xor L_RX_dataR(3) xor L_RX_dataR(2) xor L_RX_dataR(1) xor L_RX_dataR(0);
	L_rec_even6 <= L_RX_dataR(5) xor L_rec_even5;
	L_rec_even7 <= L_RX_dataR(6) xor L_rec_even6;
	L_rec_even8 <= L_RX_dataR(7) xor L_rec_even7;
	L_rec_even9 <= L_RX_dataR(8) xor L_rec_even8;
	
	with L_dataBitsUsart select
		L_rec_evenM		<= L_rec_even5 when "000",
								L_rec_even6 when "001",
								L_rec_even7 when "010",
								L_rec_even9 when "111",
								L_rec_even8 when others;
								
	L_rec_even		<= L_rec_evenM xor '0';
	L_rec_odd		<= L_rec_evenM xor '1';
	L_rec_odd_even	<= L_rec_even when I_UCSRC(UPM1) = '1' and I_UCSRC(UPM0) = '0' else L_rec_odd;
	
	-- calculate parity for transmiter
	--
	L_tx_even5 <= L_TX_UDR(4) xor L_TX_UDR(3) xor L_TX_UDR(2) xor L_TX_UDR(1) xor L_TX_UDR(0);
	L_tx_even6 <= L_TX_UDR(5) xor L_tx_even5;
	L_tx_even7 <= L_TX_UDR(6) xor L_tx_even6;
	L_tx_even8 <= L_TX_UDR(7) xor L_tx_even7;
	L_tx_even9 <= I_TXB8 xor L_tx_even8;
	
	with L_dataBitsUsart select
		L_tx_evenM		<= L_tx_even5 when "000",
								L_tx_even6 when "001",
								L_tx_even7 when "010",
								L_tx_even9 when "111",
								L_tx_even8 when others;

	L_tx_even		<= L_tx_evenM xor '0';
	L_tx_odd			<= L_tx_evenM xor '1';
	L_tx_odd_even	<= L_tx_even when I_UCSRC(UPM1) = '1' and I_UCSRC(UPM0) = '0' else L_tx_odd;
	
	
-- ################################## end RX TX parameters module ###############################################





-- ############################################## RX module #####################################################

	-- synchro falling edge
	--
	synchro_rx : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then 
			L_rx_sync1 	<= I_RX;
			L_rx_sync2 	<= L_rx_sync1;
			L_rx_main	<= L_rx_sync2;
		end if;
	end process;


	-- automat for RX - wait in reset state when I_RXEN = 0
	--
	rx_proces : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then
		
			if I_Clr = '1' or I_UCSRB(RXEN) = '0' then
				L_RX_receiver		<= (others => '0');
				L_RX_baudCount		<= 0;
				L_RX_bitCount		<= 0;
				L_RX_baudClr		<= '0';
				L_RX_UDRen			<= '0';
				AutomatMasterRX	<=	ST_WAIT_RX;
			else
				-- default values
				L_RX_baudClr		<= '0';
				L_RX_UDRen			<= '0';

				case AutomatMasterRX is
				
					-- wait for falling edge
					when ST_WAIT_RX =>
						if L_rx_main = '1' and L_rx_sync2 = '0' then
							L_RX_baudCount		<= 0;
							L_RX_baudClr		<= '1';
							L_RX_divCount		<= I_UBRR(14 downto 4);
							AutomatMasterRX	<=	ST_START_BIT;
						else
							AutomatMasterRX	<=	ST_WAIT_RX;						
						end if;


					-- start bit?
					when ST_START_BIT =>
						if G_RX_en = '1' then
							if L_bit_Value = '1' then											-- if '0' receive frame, '1' is noise
								AutomatMasterRX	<=	ST_WAIT_RX;
							else
								L_RX_receiver		<= (others => '0');
								L_RX_bitCount		<= 0;
								L_RX_baudCount		<= 0;
								L_RX_divCount		<= I_UBRR(14 downto 4);
								AutomatMasterRX	<=	ST_DATA_RECEIVE;							
							end if;							
						else
							if L_RX_divCount = 0 then
								L_RX_divCount		<= I_UBRR(14 downto 4);
								L_RX_baudCount		<= L_RX_baudCount + 1;
								if L_RX_baudCount = 7 then										-- at 7,8,9 test bit
									L_bit_1			<= L_rx_sync2;
								elsif L_RX_baudCount = 8 then
									L_bit_2			<= L_rx_sync2;
								elsif L_RX_baudCount = 9 then
									L_bit_3			<= L_rx_sync2;
								else
									null;
								end if;
							else
								L_RX_divCount		<= L_RX_divCount - 1;
							end if;
							AutomatMasterRX		<=	ST_START_BIT;													
						end if;


					-- receive Data bits
					when ST_DATA_RECEIVE =>
						if L_RX_bitCount < L_frameBitsRX then													-- get full frame
							if G_RX_en = '1' or (L_RX_lastBit = '1' and L_RX_baudCount = 10) then	-- next bit or last bit
								L_RX_bitCount	<= L_RX_bitCount + 1;										
								L_RX_receiver 	<= L_bit_Value & L_RX_receiver(10 downto 1);				-- put bit from MSB side
								L_RX_baudCount	<= 0;							
								L_RX_divCount	<= I_UBRR(14 downto 4);
							else
								if L_RX_divCount = 0 then
									L_RX_divCount		<= I_UBRR(14 downto 4);
									L_RX_baudCount		<= L_RX_baudCount + 1;
									if L_RX_baudCount = 7 then														-- at 8,9,10 test bit
										L_bit_1			<= L_rx_sync2;
									elsif L_RX_baudCount = 8 then
										L_bit_2			<= L_rx_sync2;
									elsif L_RX_baudCount = 9 then
										L_bit_3			<= L_rx_sync2;
									else
										null;
									end if;
								else
									L_RX_divCount		<= L_RX_divCount - 1;
								end if;							
							end if;							
							AutomatMasterRX	<=	ST_DATA_RECEIVE;												
						else
							AutomatMasterRX	<=	ST_ANALIZE;												
						end if;


					-- signal to seconf process to analise recived frame
					when ST_ANALIZE =>
						L_RX_UDRen				<= '1';
						AutomatMasterRX		<=	ST_WAIT_RX;												

				end case;
				
			end if;
		end if;
	end process;


	-- process for analise recived Farme - reset when Clr = '1' or UDR is read
	--
	L_UDR_Read			<= '1' when I_ADR_IO = UDR and I_RD_IO = '1' else '0';
	rx_analise : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then
		
			if I_Clr = '1' or L_UDR_Read = '1' then
				L_RXC		<= '0';
				L_FE		<= '0';
				L_DOR		<= '0';
				L_PE		<= '0';
				L_RXB8	<= '0';
			else
				if L_RX_UDRen = '1' then
					
					L_RXC			<= '1';													-- new data in receiver
					L_RX_UDR		<= L_RX_dataR(7 downto 0);							-- 8 data bits
					L_RXB8		<= L_RX_dataR(8);										-- 9-nith data bit
					L_FE			<= not L_RX_stop;										-- Frame Error
					L_DOR			<= L_RXC;												-- Data Overrun Error
					
					if I_UCSRC(UPM1) = '1' then										-- Parity Error
						if L_RX_even = L_rec_odd_even then
							L_PE	<= '0';
						else
							L_PE	<= '1';
						end if;
					else
						L_PE	<= '0';
					end if;
					
				end if;
			end if;
		
		end if;
	end process;
-- ############################################## end RX module #################################################





-- ############################################## TX module #####################################################

	-- catch UDRE
	--
	L_UDR_Write			<= '1' when I_ADR_IO = UDR and I_WE_IO = '1' else '0';
	UDRE_tx : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then
			if I_Clr = '1' then
				L_UDRE		<= '1';
				L_TX_UDR		<= (others => '0');			
			else
				if L_UDR_Write = '1' and I_UCSRB(TXEN) = '1' then
					L_UDRE		<= '0';
					L_TX_UDR		<= I_DIN;
				else
					if L_UDR_clr = '1' then
						L_UDRE		<= '1';				
						L_TX_UDR		<= (others => '0');			
					end if;
				end if;
			end if;
		end if;
	end process;
	
	-- main TX process
	--
	tx_proces : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then
		
			if I_Clr = '1' then
				L_TX					<= '1';
				L_UDR_clr			<= '0';
				L_TX_baudClr		<= '0';
				L_TX_parityBit		<= '0';
				L_TXC_en				<= '0';
				L_TX_run				<= '0';
				L_TX_transmiter	<= (others => '0');
				AutomatMasterTX	<=	ST_WAIT_TX;
			else
				-- default values
				L_UDR_clr			<= '0';			
				L_TX_baudClr		<= '0';
				L_TXC_en				<= '0';

				case AutomatMasterTX is
				
					-- wait for UDRE = '0'
					when ST_WAIT_TX =>
						L_TX					<= '1';
						if I_UCSRB(TXEN) = '1' then						
							if L_UDRE = '0' then
								L_UDR_clr			<= '1';														-- clr UDRE
								L_TX_baudClr		<= '1';														-- clr TX baud
								L_TX_run				<= '1';
								L_TX_transmiter	<= I_TXB8 & L_TX_UDR & '0';							-- copy TX bufer to shift register with Start bit
								L_TX_bitCount		<= L_dataBits + 1;										-- total count data bits + start bit
								L_TX_parityBit		<= L_tx_odd_even;											-- parity bit
								AutomatMasterTX	<=	ST_SEND_DATA;
							else
								L_TX_run				<= '0';
								AutomatMasterTX	<=	ST_WAIT_TX;						
							end if;
						else
							null;
						end if;
					
					
					-- send Start bit and data bits
					when ST_SEND_DATA	=>
						L_TX_run						<= '1';
						if G_TX_en = '1' then
							if L_TX_bitCount > 0 then
								L_TX					<= L_TX_transmiter(0);
								L_TX_transmiter	<= '0' & L_TX_transmiter(9 downto 1);
								L_TX_bitCount		<= L_TX_bitCount - 1;
								AutomatMasterTX		<=	ST_SEND_DATA;						
							else
								if I_UCSRC(UPM1) = '1' then												-- parity or direct to STOP bit								
									L_TX	<= L_TX_parityBit;
									AutomatMasterTX	<=	ST_SEND_PARITY;						
								else
									L_TX	<= '1';							
									AutomatMasterTX	<=	ST_SEND_STOP;
									if I_UCSRC(USBS) = '1' then											-- 2 STOP bits
										L_TX_bitCount	<= 1;
									else																			-- 1 STOP bit
										L_TX_bitCount	<= 0;								
									end if;
								end if;
							end if;
						end if;
					
					
					-- send parity bit
					when ST_SEND_PARITY =>
						L_TX_run					<= '1';
						if G_TX_en = '1' then
							L_TX	<= '1';
							AutomatMasterTX	<=	ST_SEND_STOP;
							if I_UCSRC(USBS) = '1' then													-- 2 STOP bits
								L_TX_bitCount	<= 1;
							else																					-- 1 STOP bit
								L_TX_bitCount	<= 0;								
							end if;
						end if;
					
					
					-- send 1 or 2 STOP bits
					when ST_SEND_STOP =>
						if G_TX_en = '1' then
							L_TX	<= '1';
							if L_TX_bitCount = 0 then
								L_TX_run				<= '0';
								L_TXC_en				<= '1';
								AutomatMasterTX	<=	ST_WAIT_TX;							
							else
								L_TX_run				<= '1';
								L_TX_bitCount		<= L_TX_bitCount - 1;
								AutomatMasterTX	<=	ST_SEND_STOP;
							end if;
						end if;
					
					
					
				end case;
			end if;
		end if;
	end process;


	-- interrupt TXC when transmission is finished and TX bufor is empty (UDRE='1')
	--
	tx_int : process (I_Clk)
	begin
		if I_Clk'event and I_Clk = '1' then
		
			if I_Clr = '1' then
				L_TXC			<= '0';
			else
				if ((I_Int_Ack = '1' and I_Int_Vect = TXC_int_vec) or (I_WE_IO = '1' and I_ADR_IO = UCSRA and I_DIN(TXC) = '1')) then
					L_TXC 	<= '0';
				elsif L_TXC_en = '1' and L_UDRE = '1' then
					L_TXC 	<= '1';
				end if;			
			end if;
			
		end if;
	end process;

-- ############################################## end TX module #################################################




-- ######################################## outside signals #####################################################

-- Mux for RX bits
--
Q_RXC				<= L_RXC		when I_UCSRB(RXEN) = '1'	else '0';
Q_INT_RX			<= '1' 		when I_UCSRB(RXEN) = '1' and L_RXC = '1' and I_UCSRB(RXCIE) = '1' else '0';
Q_FE				<= L_FE		when I_UCSRB(RXEN) = '1'	else '0';
Q_DOR				<= L_DOR		when I_UCSRB(RXEN) = '1'	else '0';
Q_PE				<= L_PE		when I_UCSRB(RXEN) = '1' and I_UCSRC(UPM1) = '1' else '0';
Q_RXB8			<=	L_RXB8	when I_UCSRB(RXEN) = '1'	else '0';
Q_RX_buf			<= L_RX_UDR;
Q_UDRE			<= L_UDRE;
Q_TX				<= L_TX		when (I_UCSRB(TXEN) = '1' or L_TX_run = '1')	else '1';
Q_TXC				<= L_TXC;
Q_TX_inRun		<= L_TX_run;
Q_INT_UDRE		<= L_UDRE	when I_UCSRB(UDRIE) = '1' 	else '0';
Q_INT_TXC		<= L_TXC		when I_UCSRB(TXCIE) = '1' 	else '0';

end Behavioral;






------------------------------------- Baud generator -----------------------------
-- formula: (1/boud)/(1/fosc) = fosc/boud. Bit U2X is ignored. UBRRH bit 6-0 (in standard Atmega only bits 3-0 can be used)
-- for 9600 boud - 25000000/9600 = 2604
-- 
-- 		fosc 25Mhz		fosc 30MHz
--				UBRR				UBRR
--	2400		10417				12500
-- 4800		5208				6250
-- 9600		2604				3125
-- 14,4k		1736				2083
-- 19,2k		1302				1562
-- 28,8k		868				1042
-- 38,4k		651				781	
-- 57,6k		434				521	
-- 76,8k		325				391
-- 115,2k	217				260
-- 230,4k	109				130
-- 250k		100				120



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.common.ALL;


entity BaudGenerator is
    Port ( I_Clk 			: in  STD_LOGIC;
           I_Clr 			: in  STD_LOGIC;
			  I_UBRR			: in  STD_LOGIC_VECTOR(14 downto 0);
			  I_RXEN			: in 	STD_LOGIC;
			  I_TXEN			: in 	STD_LOGIC;
			  I_RX_Clr		: in  STD_LOGIC;
			  I_TX_Clr		: in  STD_LOGIC;
			  I_TX_run		: in  STD_LOGIC;
			  
			  O_RX_en		: out STD_LOGIC;
			  O_TX_en		: out STD_LOGIC
			);
end BaudGenerator;

architecture Behavioral of BaudGenerator is

signal L_TX_en 			: std_logic;
signal L_RX_en 			: std_logic;
signal L_TX_counter		: std_logic_vector(14 downto 0);
signal L_RX_counter		: std_logic_vector(14 downto 0);

begin

	-- RX and TX WE generation. TX must run to finish (I_TX_run)
	--
	L_RX_en	<= '1' when L_RX_counter = 0 and I_RXEN = '1' and I_CLR = '0' else '0';	
	L_TX_en	<= '1' when L_TX_counter = 0 and (I_TXEN = '1' or I_TX_run = '1') and I_CLR = '0' else '0';
	
	process (I_Clk)
	begin
		if (rising_edge(I_CLK)) then
			if (I_CLR = '1') then																	
				L_RX_counter	<=	I_UBRR;
				L_TX_counter	<=	I_UBRR;
			else
			
				-- RX generation
				--
				if I_RXEN = '1' then
					if I_RX_Clr = '0' then
						if L_RX_counter = 0 then
							L_RX_counter	<=	I_UBRR;
						else
							L_RX_counter	<= L_RX_counter - 1;
						end if;
					else
						L_RX_counter <= I_UBRR - 3;					-- start frame - first signal is shorter for falling edge detection
					end if;
				else
					null;
				end if;
				
				-- TX generation
				--
				if I_TXEN = '1' or I_TX_run = '1' then
					if I_TX_Clr = '0' then
						if L_TX_counter = 0 then
							L_TX_counter	<=	I_UBRR;
						else
							L_TX_counter	<= L_TX_counter - 1;
						end if;
					else
						L_TX_counter <= (others => '0');
					end if;
				else
					null;
				end if;
				
			end if;
		end if;
	end process;
	
	
	-- outside
	--
	O_RX_en	<=	L_RX_en;
	O_TX_en	<=	L_TX_en;


end Behavioral;
