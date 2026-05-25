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
entity shell is
	Generic(
        CLK_DIVIDER_RATIO : integer := 4);
    Port ( 	
			clk_ext_port		: in std_logic;		
			vgaRed_ext_port 	: out std_logic_vector(3 downto 0);
			vgaBlue_ext_port	: out std_logic_vector(3 downto 0);
			vgaGreen_ext_port	: out std_logic_vector(3 downto 0);
			Hsync_port			: out std_logic;
			Vsync_port			: out std_logic);  
end shell;

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
component clock_generation is
    	Generic( CLK_DIVIDER_RATIO : integer );
        Port (
            --External Clock:
            input_clk_port		: in std_logic;
            --System Clock:
            system_clk_port		: out std_logic);
end component;

component vga_test_pattern_12bit is
	Port (
		row, column 		: in std_logic_vector(9 downto 0);
		color 				: out std_logic_vector(11 downto 0)
	);
end component;

component vga_sync is
	Port (
		clk	        		: in std_logic; -- Assumes 25MHz clock
		pixel_x				: out std_logic_vector(9 downto 0);
		pixel_y				: out std_logic_vector(9 downto 0);
		video_on			: out std_logic;
		hsync			    : out std_logic;
		vsync				: out std_logic
	);
end component;

--=============================================================================
--Signal Declarations: 
--=============================================================================
--Timing:
signal clk: std_logic := '0';
signal pixel_x, pixel_y : std_logic_vector(9 downto 0) := (others => '0');
signal color : std_logic_vector(11 downto 0);
signal video_on : std_logic := '0';


--=============================================================================
--Port Mapping (wiring the component blocks together): 
--=============================================================================
begin

-- Wire color 
vgaRed_ext_port <= color(11 downto 8);
vgaGreen_ext_port <= color(7 downto 4);
vgaBlue_ext_port <= color(3 downto 0);

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--Wire the system clock generator into the shell with a port map:
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
clocking : clock_generation
        generic map (
            -- leave this so it can be passed down from the testbench
            clk_divider_ratio => clk_divider_ratio
        )
        port map(
            input_clk_port  => clk_ext_port,     -- External clock
            system_clk_port =>  clk);   -- System clock   

vga_test : vga_test_pattern_12bit port map (
	row => pixel_y,
	column => pixel_x, 
	color => color
);

sync : vga_sync port map (
	clk => clk,
	pixel_x => pixel_x,
	pixel_y => pixel_y,
	video_on => video_on,
	hsync => Hsync_port,
	vsync => Vsync_port
);
    
end behavioral_architecture;
