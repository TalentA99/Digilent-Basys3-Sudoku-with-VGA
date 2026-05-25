----------------------------------------------------------------------------------
-- Engineer:		J. Graham Keggi
-- 
-- Create Date:	15:10:36 07/12/2010 
-- Module Name:	vga_test_pattern - Behavioral
-- Target Device:	Spartan3E-500 Nexys2
--
-- Description:	Reads in current pixel X and Y as 2 10-bit vectors and supplys
--						an 8-bit color code consistent with the VGA test pattern
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity vga_sync is
	port( clk	        		: in std_logic;
		  color					: out std_logic_vector(11 downto 0)
          color					: out std_logic_vector(11 downto 0)
          color					: out std_logic_vector(11 downto 0)
          color					: out std_logic_vector(11 downto 0)
          color					: out std_logic_vector(11 downto 0));
end vga_test_pattern;

architecture Behavioral of vga_test_pattern is
	
-- signals

begin

end Behavioral;

