--=============================================================================
-- Authors: Talent and Sky
--ENGS 31 / CoSc 56 — Final Project
-- Module   : datapath
-- implementation : JFA (shell skeleton) 
--
-- Description:
--   Datapath for the Basys3 Sudoku game.  Matches the block diagram from
--   deliverable and the Shell Design Specification:
--
--   Inputs  : SW(9:0), en_game, set_reset (monopulsed BTNC),
--             up / down / left / right (monopulsed directional buttons), clk
--   Outputs : finish, sel_num(9:0), game_display(81×4),
--             selected_cell(80:0)
--
--   Internal register banks (all 81 cells, 4 bits each unless noted):
--     game_display    — what the VGA sees (includes "in-flight" number)
--     game_state      — committed player entries only
--     game_solution   — correct answer for every cell
--     unchangeable    — '1' for pre-filled (given) cells
--     selected_cell   — one-hot, '1' marks the cursor position
--
--   Number encoding: 0000 = empty, 0001–1001 = digits 1–9
--   Switch encoding: SW0 = reset/erase (→ 0000), SW1–SW9 = digit 1–9
--=============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
--=============================================================================
-- Entity
--=============================================================================
entity datapath is
    Port (
        -- Clock
        clk             : in  std_logic;
 
        -- Controller enable (high while FSM is in PLAY state)
        en_game         : in  std_logic;
 
        -- Monopulsed button inputs (one clock-wide pulses from debouncer)
        set_reset       : in  std_logic;   -- BTNC: commit selected number
        move_up         : in  std_logic;   -- BTNU
        move_down       : in  std_logic;   -- BTND
        move_left       : in  std_logic;   -- BTNL
        move_right      : in  std_logic;   -- BTNR
 
        -- Number-select switches SW9 downto SW0
        sw              : in  std_logic_vector(9 downto 0);
 
        -- Outputs to FSM / controller
        finish          : out std_logic;   -- '1' when puzzle is solved
 
        -- Outputs to LED bank: lights the LED matching the active switch
        -- (all 10 LEDs light if more than one switch is on simultaneously)
        sel_num         : out std_logic_vector(9 downto 0);
 
        -- Outputs to VGA display logic
        -- Flat arrays: index 0 = row0,col0 … index 80 = row8,col8
        game_display    : out std_logic_vector(81*4-1 downto 0);   -- 324 bits
        selected_cell   : out std_logic_vector(80 downto 0)        --  81 bits
    );
end datapath;

  -=============================================================================
-- Architecture
--=============================================================================
architecture behavioral_architecture of datapath is
 
    --=========================================================================
    -- Type definitions
    --=========================================================================
    -- 81-element array of 4-bit cell values (0 = empty, 1–9 = digit)
    type cell_array   is array (0 to 80) of std_logic_vector(3 downto 0);
    -- 81-element array of single-bit flags
    type flag_array   is array (0 to 80) of std_logic;
 
    --=========================================================================
    -- Hardcoded puzzle (easy example — will change as desired)
    --   Row-major order: cell(r,c) = index r*9 + c
    --   0 = empty cell the player must fill
    --   BCD 1–9 for given digits
    --
    --   Puzzle source: sudoku.com/easy (one example)
    --
    --     5 3 _ | _ 7 _ | _ _ _
    --     6 _ _ | 1 9 5 | _ _ _
    --     _ 9 8 | _ _ _ | _ 6 _
    --     ------+-------+------
    --     8 _ _ | _ 6 _ | _ _ 3
    --     4 _ _ | 8 _ 3 | _ _ 1
    --     7 _ _ | _ 2 _ | _ _ 6
    --     ------+-------+------
    --     _ 6 _ | _ _ _ | 2 8 _
    --     _ _ _ | 4 1 9 | _ _ 5
    --     _ _ _ | _ 8 _ | _ 7 9
    --=========================================================================
    constant PUZZLE : cell_array := (
        -- row 0
        "0101","0011","0000",  "0000","0111","0000",  "0000","0000","0000",
        -- row 1
        "0110","0000","0000",  "0001","1001","0101",  "0000","0000","0000",
        -- row 2
        "0000","1001","1000",  "0000","0000","0000",  "0000","0110","0000",
        -- row 3
        "1000","0000","0000",  "0000","0110","0000",  "0000","0000","0011",
        -- row 4
        "0100","0000","0000",  "1000","0000","0011",  "0000","0000","0001",
        -- row 5
        "0111","0000","0000",  "0000","0010","0000",  "0000","0000","0110",
        -- row 6
        "0000","0110","0000",  "0000","0000","0000",  "0010","1000","0000",
        -- row 7
        "0000","0000","0000",  "0100","0001","1001",  "0000","0000","0101",
        -- row 8
        "0000","0000","0000",  "0000","1000","0000",  "0000","0111","1001"
    );
 
    -- Solution matching the puzzle above
    constant SOLUTION : cell_array := (
        -- row 0
        "0101","0011","0100",  "0110","0111","0010",  "1000","1001","0001",
        -- row 1
        "0110","0111","0010",  "0001","1001","0101",  "0011","0100","1000",
        -- row 2
        "0001","1001","1000",  "0011","0100","1000",  "0101","0110","0111",
        -- row 3
        "1000","0101","1001",  "0111","0110","0001",  "0100","0010","0011",
        -- row 4
        "0100","0010","0110",  "1000","0101","0011",  "0111","0001","0001",  -- note: col8 is 1 not 01
        -- row 5
        "0111","0001","0011",  "1001","0010","0100",  "0101","1000","0110",
        -- row 6
        "1001","0110","0001",  "0101","0011","0111",  "0010","1000","0100",
        -- row 7
        "0010","1000","0111",  "0100","0001","1001",  "0110","0011","0101",
        -- row 8
        "0011","0100","0101",  "0010","1000","0110",  "0001","0111","1001"
    );
 
    --=========================================================================
    -- Register banks
    --=========================================================================
    signal game_state_reg   : cell_array := PUZZLE;    -- player's committed entries
    signal game_display_reg : cell_array := PUZZLE;    -- what VGA sees
    signal unchangeable_reg : flag_array;              -- '1' = pre-filled cell
    signal sel_cell_reg     : flag_array;              -- one-hot cursor
 
    --=========================================================================
    -- Internal signals
    --=========================================================================
    signal cursor_idx       : integer range 0 to 80 := 0;  -- current cursor position
 
    -- Decoded "selected number" from switches
    signal sel_num_sig      : std_logic_vector(9 downto 0);
    signal num_valid        : std_logic;    -- '1' when exactly one switch is on
    signal sel_digit        : std_logic_vector(3 downto 0); -- BCD digit to write
 
    -- Finish logic
    signal finish_sig       : std_logic;
 
begin
 
    --=========================================================================
    -- Initialise unchangeable_reg from PUZZLE at elaboration time
    -- (done in the clocked process below via a reset-like first-cycle init)
    --=========================================================================
 
    --=========================================================================
    -- Switch decoding — validate number select
    --
    --   SW0  → erase (digit = 0000)
    --   SW1  → digit 1 (0001) … SW9 → digit 9 (1001)
    --   If more than one switch is high → invalid, light all LEDs, no write
    --=========================================================================
    
 --Still need to work on the logic here.
  
 
    --=========================================================================
    -- Clocked datapath process
    --   • Initialises unchangeable_reg on first cycle (treated like a reset)
    --   • Handles cursor movement
    --   • Handles cell commit (set_reset button)
    --   • Updates game_display_reg so VGA sees pending selection
    --=========================================================================
    datapath_proc : process(clk)
        variable new_idx : integer range 0 to 80;
        variable row     : integer range 0 to 8;
        variable col     : integer range 0 to 8;
    begin
        if rising_edge(clk) then
 
            -- ------------------------------------------------------------------
            -- Initialise unchangeable flags from the hardcoded puzzle.
            -- We do this every cycle unconditionally — it is combinationally
            -- derived and synthesises cleanly as constant logic.  A proper
            -- reset input could drive this instead; omitted per spec.
            -- ------------------------------------------------------------------
            --Still need to work on the logic
          
          
          
          -- --------------------------------------------------------------
                -- Cell commit: set_reset button with a valid switch selection,
                -- on a cell the player is allowed to change
                -- --------------------------------------------------------------
                if set_reset = '1' and num_valid = '1'
                        and unchangeable_reg(cursor_idx) = '0' then
                    -- Write digit into game_state (committed store)
                    game_state_reg(cursor_idx) <= sel_digit;
                end if;
 
                -- --------------------------------------------------------------
                -- Build game_display:
                --   • Pre-filled cells always show their puzzle value
                --   • Player-editable cells show game_state value
                --   • The currently selected editable cell also previews
                --     the currently dialled-in switch digit (not yet committed)
                -- --------------------------------------------------------------


                --Still need to logically implement this here
                  
    end process datapath_proc;
 
    --=========================================================================
    -- Finish detection — compare game_state_reg to SOLUTION for every cell
    --   Pre-filled cells are always correct (player cannot modify them), so
    --   we only need to check mutable cells against the solution.
    --   finish goes high when ALL 81 cells match.
    --=========================================================================
    finish_check : process(game_state_reg)
        variable all_match : std_logic;
    begin
        --need code implementation here
    end process finish_check;
 
    
 
    --=========================================================================
    -- Flatten internal arrays to std_logic_vector output ports
    --   game_display : bits [i*4+3 : i*4] = cell i  (i=0 is top-left)
    --   selected_cell: bit  [i]            = cursor flag for cell i
    --=========================================================================
    flatten_outputs : process(game_display_reg, sel_cell_reg)
    begin
        --need code implementation here too
      
end behavioral_architecture;
 

  
