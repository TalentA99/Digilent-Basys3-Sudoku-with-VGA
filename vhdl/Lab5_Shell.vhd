--=============================================================================
--ENGS 31/ CoSc 56
--Lab 5 Shell
--Ben Dobbins
--Eric Hansen
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
entity lab5_shell is
    Generic(
        CLK_DIVIDER_RATIO : integer := 50;
        STABLE_TIME       : integer := 200 );
    Port (
        clk_ext_port	        : in std_logic;						-- mapped to external IO device (100 MHz Clock)				
        term_input_ext_port		: in std_logic_vector(3 downto 0);	-- slide switches SW15 (MSB) down to SW12 (LSB)
        op_ext_port		        : in std_logic;						-- button center
        clear_ext_port		    : in std_logic;						-- button down
        seg_ext_port		    : out std_logic_vector(0 to 6);
        dp_ext_port				: out std_logic;
        an_ext_port				: out std_logic_vector(3 downto 0)
    );
end lab5_shell;

--=============================================================================
--Architecture Type:
--=============================================================================
architecture behavioral_architecture of lab5_shell is

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

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Input Conditioning:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    component button_interface is
        Generic(
            STABLE_TIME : integer );
        Port( clk_port            : in  std_logic;
             button_port         : in  std_logic;
             button_db_port      : out std_logic;
             button_mp_port      : out std_logic);
    end component;

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Controller:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    component lab5_controller is
        Port (
            --timing:
            clk_port 			: in std_logic;
            --control inputs:
            load_port		    : in std_logic;
            clear_port		    : in std_logic;
            --control outputs:
            term1_en_port	    : out std_logic;
            term2_en_port	    : out std_logic;
            sum_en_port		    : out std_logic;
            reset_port		    : out std_logic);
    end component;

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Datapath:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    component lab5_datapath is
        Port (
            --timing:
            clk_port 			 : in std_logic;
            --control inputs:
            term1_en_port        : in std_logic;
            term2_en_port        : in std_logic;
            sum_en_port          : in std_logic;
            reset_port           : in std_logic;
            --datapath inputs:
            term_input_port      : in std_logic_vector(3 downto 0);
            --datapath outputs:
            term1_display_port   : out std_logic_vector(3 downto 0);
            term2_display_port   : out std_logic_vector(3 downto 0);
            answer_display_port  : out std_logic_vector(3 downto 0);
            overflow_port		 : out std_logic);
    end component;

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --7-Segment Display:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    component mux7seg is
        Port ( clk_port 	: in  std_logic;						--should get the 1 MHz system clk
             y3_port 		: in  std_logic_vector(3 downto 0);		--left most digit
             y2_port 		: in  std_logic_vector(3 downto 0);		--center left digit
             y1_port 		: in  std_logic_vector(3 downto 0);		--center right digit
             y0_port 		: in  std_logic_vector(3 downto 0);		--right most digit
             dp_set_port 	: in  std_logic_vector(3 downto 0);     --decimal points
             seg_port 	: out  std_logic_vector(0 to 6);		--segments (a...g)
             dp_port 		: out  std_logic;						--decimal point
             an_port 		: out  std_logic_vector (3 downto 0) );	--anodes
    end component;

    --=============================================================================
    --Signal Declarations: 
    --=============================================================================
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Timing:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    signal clk : std_logic;

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Controller:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    signal op_mp, clear_mp : std_logic; -- monopulse signals for operation and clear
    signal op_db, clear_db : std_logic; -- monopulse signals for operation and clear
    
    signal term1_en, term2_en, sum_en, reset : std_logic;
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Datapath:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    signal overflow         : std_logic := '0'; --You get this one for free
    signal dp_set : std_logic_vector(3 downto 0);

    signal term1_display, term2_display, answer_display : std_logic_vector(3 downto 0);
    --=============================================================================
    --Port Mapping (wiring the component blocks together): 
    --=============================================================================
begin
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wire the system clock generator into the shell with a port map:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    clocking: system_clock_generation
        generic map (
            -- leave this so it can be passed down from the testbench
            clk_divider_ratio => clk_divider_ratio
        )
        port map(
            input_clk_port  => clk_ext_port,     -- External clock
            system_clk_port =>  clk);   -- System clock

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wire the input conditioning block into the shell with a port map:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wiring the port map in twice generates two separate instances of one component
    load_monopulse: button_interface
        generic map (
            -- leave this so it can be passed down from the testbench
            stable_time         => stable_time )
        port map(
            clk_port            => clk,
            button_port         => op_ext_port,
            button_db_port      => open,
            button_mp_port      => op_mp);

    clear_monopulse: button_interface
        generic map (
            -- leave this so it can be passed down from the testbench
            stable_time         => stable_time )
        port map(
            clk_port            => clk,
            button_port         => clear_ext_port ,
            button_db_port      => open ,
            button_mp_port      => clear_mp);

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wire the controller into the shell with a port map:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    controller: lab5_controller port map(
            clk_port	 	  => clk,
            load_port  	      => op_mp,
            clear_port        => clear_mp,
            term1_en_port 	  => term1_en,
            term2_en_port 	  => term2_en,
            sum_en_port 	  => sum_en,
            reset_port 		  => reset);

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wire the datapath into the shell with a port map:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    datapath: lab5_datapath port map(
            clk_port	 		=> clk,
            term1_en_port 	    => term1_en,
            term2_en_port 	    => term2_en,
            sum_en_port 	    => sum_en,
            reset_port			=> reset,
            term_input_port		=> term_input_ext_port,
            term1_display_port  => term1_display,
            term2_display_port  => term2_display,
            answer_display_port => answer_display,
            overflow_port		=> overflow);

    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    --Wire the 7-segment display into the shell with a port map:
    --+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    -- prepend the overflow with 3 '0's
    dp_set <= "000" & overflow;

    seven_seg: mux7seg port map(
            clk_port	=> clk,		--should get the 1 MHz system clk
            y3_port		=> term1_display,		--left most digit
            y2_port 	=> term2_display,		--center left digit
            y1_port 	=> "0000",		--center right digit (don't use this one)
            y0_port 	=> answer_display,		--right most digit
            dp_set_port => dp_set,	--you get this one for free too
            seg_port 	=> seg_ext_port,
            dp_port 	=> dp_ext_port,
            an_port 	=> an_ext_port);

end behavioral_architecture;
