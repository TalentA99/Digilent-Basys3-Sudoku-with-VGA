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
	port( clk	        		: in std_logic; -- Assumes 25MHz clock
		  pixel_x					: out std_logic_vector(9 downto 0);
          pixel_y					: out std_logic_vector(9 downto 0);
          video_on					: out std_logic;
          hsync					    : out std_logic;
          vsync					    : out std_logic);
end vga_sync;

architecture Behavioral of vga_sync is
	
-- signals
signal h_cnt, v_cnt : unsigned(9 downto 0) := (others => '0');
signal h_sync_sig : std_logic := '0';
signal H_video_on, V_video_on : std_logic := '0';

-- Slightly adjust H_MAX and V_MAX depending on moniter being used

constant left_border : integer := 48;
constant h_display : integer := 640;
constant right_border : integer := 16;
constant h_retrace : integer := 96;
constant H_MAX : integer := left_border + h_display + right_border + h_retrace - 1; --number of PCLKs in an H_sync period

constant top_border : integer := 29;
constant v_display : integer := 480;
constant bottom_border : integer := 10;
constant v_retrace : integer := 2;
constant V_MAX : integer := top_border + v_display + bottom_border + v_retrace - 1; --number of H_syncs in an V_sync period

begin

h_counter : process(clk)
begin
    if rising_edge(clk) then
        if h_cnt < h_display + right_border then               
            h_sync_sig <= '1';                    -- display and front porch
        elsif h_cnt < h_display + right_border + h_retrace then
            h_sync_sig <= '0';                    -- active sync pulse during retrace
        else
            h_sync_sig <= '1';                    -- back porch
        end if;

        if h_cnt = H_MAX then   
            h_cnt <= (others => '0');
        else    
            h_cnt <= h_cnt + 1;
        end if;
    end if; 
end process h_counter;
hsync <= h_sync_sig;

v_counter : process(clk)
begin
    if rising_edge(clk) then
        if h_cnt = H_MAX then
            if v_cnt = V_MAX then
                v_cnt <= (others => '0');
            else 
                v_cnt <= v_cnt + 1;
            end if;
        end if;

        if v_cnt < v_display + bottom_border then
            vsync <= '1';
        elsif v_cnt < v_display + bottom_border + v_retrace then
            vsync <= '0';
        else 
            vsync <= '1';
        end if;
    end if; 
end process v_counter;

output_logic : process(h_cnt, v_cnt)
begin
    if h_cnt < h_display then
        pixel_x <= std_logic_vector(h_cnt);
    else
        pixel_x <= (others => '0');
    end if;

    if v_cnt < v_display then
        pixel_y <= std_logic_vector(v_cnt);
    else 
        pixel_y <= (others => '0');
    end if;

    H_video_on <= '0';
    V_video_on <= '0';
    if h_cnt < h_display then
        H_video_on <= '1';
    end if;

    if v_cnt < v_display then
        V_video_on <= '1';
    end if;
end process output_logic;

video_on <= H_video_on AND V_video_on; --Only enable video out when H_video_out and V_video_out are high. It's important to set the output to zero when you aren't actively displaying video. That's how the monitor determines the black level.

end Behavioral;

