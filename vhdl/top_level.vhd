--=============================================================================
--ENGS 31/ CoSc 56
--Final Project Shell
--JFA
--=============================================================================

--=============================================================================
--Library Declarations:
--=============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--=============================================================================
--Entity Declaration:
--=============================================================================
entity top_level is
	Generic(
        CLK_DIVIDER_RATIO : integer := 50);
    Port ( 	
			clk_ext_port		: in std_logic;		
			vgaRed_ext_port 	: out std_logic_vector(3 downto 0);
			vgaBlue_ext_port	: out std_logic_vector(3 downto 0);
			vgaGreen_ext_port	: out std_logic_vector(3 downto 0);
			Hsync_port			: out std_logic;
			Vsync_port			: out std_logic);  
end top_level;

--=============================================================================
--Architecture Type:
--=============================================================================
architecture behavioral_architecture of shell is

--=============================================================================
--Sub-Component Declarations:
--=============================================================================
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--System Clock Generation:
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
component system_clock_generation is
    Generic( CLK_DIVIDER_RATIO : integer );
        Port (
            --External Clock:
            input_clk_port		: in std_logic;
            --System Clock:
            system_clk_port		: out std_logic);
end component;

--=============================================================================
--Signal Declarations: 
--=============================================================================
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Timing:
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
signal clk: std_logic := '0';

--=============================================================================
--Port Mapping (wiring the component blocks together): 
--=============================================================================
begin
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Wire the system clock generator into the shell with a port map:
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
clocking: lab4_system_clock_generation port map(
    input_clk_port  => clk_ext_port,   
    system_clk_port => clk );   
    
end behavioral_architecture;
