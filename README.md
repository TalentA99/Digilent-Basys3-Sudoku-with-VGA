# 🎮 Basys3 Sudoku with VGA
### ENGS 31 / CoSc 56 — Digital Electronics Final Project By Talent and Sky
**Dartmouth College** · Spring 2026

> A fully hardware-implemented, interactive Sudoku game running on a **Digilent Basys3 FPGA**, rendered live over **VGA** at 640×480, playable entirely through the board's onboard buttons and switches — no CPU, no OS, no software.

---

## 📺 Demo

> *VGA output and gameplay video/screenshot coming soon.*

---

## 🗂️ Table of Contents

- [Overview](#overview)
- [Goals & Motivation](#goals--motivation)
- [Hardware](#hardware)
- [Architecture](#architecture)
  - [System Block Diagram](#system-block-diagram)
  - [Component Breakdown](#component-breakdown)
- [Game Flow](#game-flow)
- [Controls](#controls)
- [VHDL Module Reference](#vhdl-module-reference)
- [VGA Timing](#vga-timing)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Current Status](#current-status)
- [Known Issues & Limitations](#known-issues--limitations)
- [Future Work](#future-work)
- [Team](#team)
- [Acknowledgements](#acknowledgements)

---

## Overview

This project implements a complete, playable **Sudoku game in synthesizable VHDL** targeting the **Digilent Basys3** development board (Xilinx Artix-7 FPGA). The game is rendered on a standard VGA monitor at 640×480 @ 60 Hz using the board's 12-bit RGB VGA port, and is controlled entirely via the Basys3's five onboard push-buttons and ten slide switches.

The design is a clean **RTL (Register Transfer Level)** implementation — no soft processors, no HLS, no embedded software. Every game state transition, cursor movement, input validation, and pixel output is described in hardware and compiled directly to FPGA fabric.

---

## Goals & Motivation

This project was undertaken as the final project for **ENGS 31 / CoSc 56: Digital Electronics** at Dartmouth College. The learning objectives are:

- **Design a non-trivial FSM-based digital system** from scratch, from specification through synthesis and hardware testing.
- **Practice hierarchical RTL design** — splitting a complex system into clean, independently-testable components (clock generation, VGA sync, datapath, controller).
- **Implement a real VGA display pipeline** that correctly generates sync signals and drives a pixel color bus in real time.
- **Handle real-world input** robustly — including switch debouncing and monopulse generation so that a single physical button press registers as exactly one logical event.
- **Close the loop on FPGA development** — from pencil-and-paper block diagrams, to VHDL, to Vivado synthesis/place-and-route, to a working demo on physical hardware.

The Sudoku game was chosen because it is rich enough to exercise all of these skills (display memory, rule-checking logic, multi-state FSM, input handling) while remaining tractable in the course timeframe.

---

## Hardware

| Item | Detail |
|---|---|
| FPGA Board | Digilent Basys3 (Xilinx Artix-7 XC7A35T) |
| Display | Any standard VGA monitor (640×480 @ 60 Hz) |
| Interface | VGA port on Basys3 (12-bit colour: 4-bit R/G/B) |
| User Input | 5× onboard push-buttons (BTNC, BTNU, BTND, BTNL, BTNR) |
| Number Select | SW0–SW9 (10 slide switches) |
| Feedback LEDs | LD0–LD9 (mirrors active switch selection) |
| Onboard Clock | 100 MHz crystal oscillator → divided to 25 MHz system clock |
| Toolchain | AMD Vivado (Design Suite 2024.x recommended) |

---

## Architecture

### System Block Diagram

```
                         ┌──────────────────┐
  BTNC ──[debounce+mono]─►                  │  sel_num (10) ──► LEDs LD0–LD9
  BTNU ──[debounce+mono]─►   D A T A P A T H│
  BTND ──[debounce+mono]─►                  │  game_display (81×4) ─────┐
  BTNL ──[debounce+mono]─►   (registers,    │  selected_cell (81×1) ────┤
  BTNR ──[debounce+mono]─►    movement,     │                           │
                          │    commit,      │  finish ──────────────────┤
  SW0–SW9 ────────────────►    validation)  │                           │
                          └──────▲──────────┘                           │
                                 │ en_game                               │
                          ┌──────┴──────────┐                           │
  BTNC ───────────────────►                 │  screen_start             │
  BTNU ───────────────────►  C O N T R O L │  screen_finish            │
  BTND ───────────────────►  L E R  (FSM)  ├──────────────────────────►│
  BTNL ───────────────────►                │                           │
  BTNR ───────────────────►  START→PLAY→END│                           │
  finish ──────────────────►               │                           │
                          └──────▲──────────┘                           │
                                 │                                       ▼
  CCLK (100MHz) ──►[clock_div]──► CLK (25MHz)              ┌──────────────────────┐
                                  │                         │   V G A   O U T P U T│
                                  └────────────────────────►│   L O G I C          │
                                                            │                      │
                                                            │  pixel_x, pixel_y   │
                                                            │  from vga_sync ──►  │
                                                            │                      ├──► Hsync
                                                            │  renders:            ├──► Vsync
                                                            │  • start screen      ├──► R[3:0]
                                                            │  • sudoku grid       ├──► G[3:0]
                                                            │  • cursor highlight  └──► B[3:0]
                                                            │  • win screen        
                                                            └──────────────────────┘
```

### Component Breakdown

#### 1. `clock_generation`
Divides the 100 MHz board oscillator down to a **25 MHz pixel clock** suitable for 640×480 VGA timing. Uses a parameterised counter and a `BUFG` primitive to route the divided clock cleanly onto the FPGA clocking network with minimal skew.

**Key fix:** The `COUNT_LEN` calculation uses `ceil(log2(TC + 1.0)) + 1` to guarantee a non-zero counter width even when `CLK_DIVIDER_RATIO = 2`.

#### 2. `vga_sync`
Generates the **horizontal and vertical sync signals** and outputs the current (`pixel_x`, `pixel_y`) coordinates on every clock cycle, following the 640×480 @ 60 Hz VGA standard:

| Parameter | Value |
|---|---|
| Pixel clock | 25.175 MHz (approx. 25 MHz) |
| H total | 800 pixels |
| H display | 640 px |
| H front porch | 16 px |
| H sync pulse | 96 px |
| H back porch | 48 px |
| V total | 525 lines |
| V display | 480 lines |
| V front porch | 10 lines |
| V sync pulse | 2 lines |
| V back porch | 29 lines |

Also outputs `video_on`, which goes low during the blanking intervals so the RGB outputs are forced to zero (required for the monitor to correctly establish its black level).

#### 3. `vga_test_pattern_12bit`
A standalone **test pattern generator** (7-bar colour pattern) used during bring-up and integration testing of the VGA pipeline before the Sudoku display logic was wired in. Accepts `(row, column)` and outputs a 12-bit `color`.

#### 4. `datapath`
The heart of the game. Holds and manipulates all game state:

| Register Bank | Size | Purpose |
|---|---|---|
| `game_display_reg` | 81 × 4 bits | What the VGA sees — includes live preview of pending digit |
| `game_state_reg` | 81 × 4 bits | Committed player entries (no preview) |
| `game_solution` | 81 × 4 bits | Correct answer for each cell (ROM constant) |
| `unchangeable_reg` | 81 × 1 bit | '1' for pre-filled (given) cells the player cannot edit |
| `sel_cell_reg` | 81 × 1 bit | One-hot cursor position register |

Clocked logic handles:
- **Cursor movement** with wrap-around at all four grid edges
- **Switch validation** — exactly one switch → valid digit; multiple switches → all LEDs light, write blocked
- **Cell commit** — `set_reset` (BTNC monopulse) writes the pending digit into `game_state_reg` if the cell is mutable
- **Live display preview** — the selected cell shows the currently dialled switch digit before commit
- **Finish detection** — combinational comparison of all 81 cells against the solution; output goes to FSM

#### 5. `controller` (FSM)
A three-state Moore machine:

```
         any button
  ┌─────────────────────────────────────────────┐
  ▼                                             │
START ──(any button pressed)──► PLAY ──(finish='1')──► END
  ▲                                             │
  └──────────────(restart pressed)──────────────┘

Outputs:
  START : screen_start='1', en_game='0'
  PLAY  : en_game='1',      screen_start='0', screen_finish='0'
  END   : screen_finish='1', en_game='0'
```

#### 6. `debouncer` + `monopulse`
Physical buttons are mechanically noisy. A **debouncer** filters out glitches using a shift-register/counter scheme, then a **monopulse** (one-shot) circuit ensures that each clean button press produces **exactly one clock-wide pulse**, preventing accidental multi-registration of a single press.

#### 7. `shell` (top-level)
Wires all sub-components together. Passes `CLK_DIVIDER_RATIO` down from a top-level generic so the testbench can accelerate simulation without modifying source files.

---

## Game Flow

```
┌─────────────────────────────────────────────────┐
│               START SCREEN                      │
│     "Press any button to begin"                 │
│                                                  │
│        [any button] ──────────────────┐         │
└─────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────┐
│              PLAY SCREEN                        │
│                                                  │
│  9×9 Sudoku grid displayed over VGA             │
│  • Given cells shown in white                   │
│  • Player cells shown in grey                   │
│  • Cursor cell highlighted (different shade)    │
│  • Active switch digit previewed in cursor cell │
│                                                  │
│  Player navigates with BTNU/D/L/R               │
│  Selects digit with SW1–SW9 (SW0 = erase)       │
│  Confirms with BTNC                             │
│                                                  │
│       [all 81 cells correct] ─────────┐         │
└─────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────┐
│               WIN SCREEN                        │
│        "Puzzle Solved! 🎉"                      │
│        "Press any button to restart"            │
│                                                  │
│        [any button] ── back to START            │
└─────────────────────────────────────────────────┘
```

---

## Controls

| Input | Action |
|---|---|
| **BTNU** | Move cursor up (wraps) |
| **BTND** | Move cursor down (wraps) |
| **BTNL** | Move cursor left (wraps) |
| **BTNR** | Move cursor right (wraps) |
| **BTNC** | Confirm / commit selected number into cell |
| **SW1–SW9** | Select digit 1–9 to place |
| **SW0** | Select erase (clears the current cell) |
| **Any button** | Start game (from start screen) / Restart (from win screen) |

> **LED feedback:** The LED corresponding to the active switch lights up. If two or more switches are on simultaneously, *all* LEDs light to warn the player of an invalid selection — the commit button is locked out until a single switch is selected.

---

## VHDL Module Reference

```
src/
├── shell.vhd                   Top-level: wires all components
├── clock_generation.vhd        100MHz → 25MHz pixel clock (BUFG)
├── vga_sync.vhd                H/V sync, pixel_x/y, video_on
├── vga_test_pattern_12bit.vhd  7-bar colour test pattern (bringup aid)
├── datapath.vhd                Game state, cursor, commit, finish
├── controller.vhd              FSM: START / PLAY / END states
├── debouncer.vhd               Switch/button noise filter
└── monopulse.vhd               One-shot pulse generator per button
```

### Port Summary — `datapath`

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | 25 MHz system clock |
| `en_game` | in | 1 | High during PLAY state |
| `set_reset` | in | 1 | Monopulsed BTNC |
| `move_up/down/left/right` | in | 1 each | Monopulsed directional buttons |
| `sw` | in | 10 | Raw switch bus SW9:SW0 |
| `finish` | out | 1 | Puzzle solved flag → FSM |
| `sel_num` | out | 10 | LED driver: active switch(es) |
| `game_display` | out | 324 | 81 cells × 4-bit BCD → VGA |
| `selected_cell` | out | 81 | One-hot cursor → VGA |

### Cell Encoding

| Value (4-bit) | Meaning |
|---|---|
| `0000` | Empty cell |
| `0001` – `1001` | Digits 1–9 (BCD) |

---

## VGA Timing

The design targets **640×480 @ 60 Hz** (pixel clock ≈ 25.175 MHz, approximated as 25 MHz with the integer clock divider). The `vga_sync` module generates `hsync` and `vsync` with active-low sync pulses and outputs a `video_on` blanking signal. RGB outputs are forced to `000` when `video_on = '0'`.

The Sudoku grid is rendered by comparing the current (`pixel_x`, `pixel_y`) raster position to the bounds of each of the 81 cells and the grid lines. The VGA output logic reads `game_display` (which cell holds which digit) and `selected_cell` (which cell has the cursor) to decide the pixel colour at each position.

---

## Repository Structure

```
Digilent-Basys3-Sudoku-with-VGA/
│
├── README.md                   ← You are here
│
├── src/                        VHDL source files
│   ├── shell.vhd
│   ├── clock_generation.vhd
│   ├── vga_sync.vhd
│   ├── vga_test_pattern_12bit.vhd
│   ├── datapath.vhd
│   ├── controller.vhd
│   ├── debouncer.vhd
│   └── monopulse.vhd
│
├── constraints/                Basys3 XDC pin-constraint file
│   └── basys3_sudoku.xdc
│
├── sim/                        Testbenches
│   ├── tb_clock_generation.vhd
│   ├── tb_datapath.vhd
│   └── tb_shell.vhd
│
├── docs/                       Design documentation
│   ├── block_diagram.pdf       Handwritten architecture sketch
│   └── shell_design_spec.md    Full written specification
│
└── vivado/                     Vivado project files (generated)
    └── .gitignore
```

---

## Getting Started

### Prerequisites
- [AMD Vivado Design Suite](https://www.xilinx.com/products/design-tools/vivado.html) (2022.x or later recommended)
- Digilent Basys3 board
- VGA monitor + VGA cable
- Micro-USB cable (for programming)

### Steps

**1. Clone the repository**
```bash
git clone https://github.com/Sky-JF/Digilent-Basys3-Sudoku-with-VGA.git
cd Digilent-Basys3-Sudoku-with-VGA
```

**2. Open Vivado and create a new project**
- Target: `xc7a35tcpg236-1` (Basys3)
- Add all `.vhd` files from `src/` as design sources
- Add `constraints/basys3_sudoku.xdc` as a constraint file

**3. Run Simulation (optional but recommended)**
- Set `tb_shell.vhd` as the top simulation source
- Run behavioural simulation to verify game logic before hardware testing

**4. Run Synthesis → Implementation → Generate Bitstream**

**5. Program the board**
- Connect Basys3 via USB
- Open Hardware Manager in Vivado
- Program device with the generated `.bit` file

**6. Connect VGA monitor and play!**

---

## Current Status

| Feature | Status |
|---|---|
| Clock generation (25 MHz) | ✅ Complete |
| VGA sync signal generation | ✅ Complete |
| VGA test pattern (bringup) | ✅ Complete |
| Datapath (registers, cursor, commit) | ✅ Complete |
| Switch debounce + monopulse | ✅ Complete |
| Controller FSM | 🔄 In progress |
| VGA Sudoku grid renderer | 🔄 In progress |
| Start / Win screen display | 🔄 In progress |
| Full system integration | 🔄 In progress |
| Hardware testing on Basys3 | ⏳ Pending |
| Puzzle database (USB drive) | 📋 Stretch goal |

---

## Known Issues & Limitations

- **Single hardcoded puzzle** — the current datapath contains one puzzle and solution encoded as VHDL constants. Puzzle selection from an external database is a planned future feature.
- **No input clock exactly 25.175 MHz** — the integer divider produces a 25 MHz pixel clock (0.7% error), which is within tolerance for most monitors but may cause display instability on stricter displays.
- **No save state** — the game state resets on every FPGA power cycle or reprogram, as there is no non-volatile storage in the current design.
- **Digit font rendering** — 7-segment-style or bitmap font rendering for digits 1–9 on the VGA grid is still being refined.

---

## Future Work

- **Puzzle database over USB** — load puzzles from a FAT-formatted USB drive connected to the Basys3's USB-UART port (described in the original spec as a stretch goal).
- **Difficulty selection** — offer easy / medium / hard puzzles chosen at the start screen.
- **Timer display** — add a seconds counter rendered on-screen to track solve time.
- **Error highlighting** — flash or colour-code cells that conflict with Sudoku row/column/box rules in real time.
- **Multiple puzzle support** — cycle through a ROM of several built-in puzzles rather than a single hardcoded one.
- **Colour display** — extend the VGA renderer to use colour (the pipeline already supports 12-bit RGB; current game logic uses greyscale only).

---

## Team

| Name | Role |
|---|---|
| **Sky** | Architecture, VGA pipeline, shell integration |
| **Talent** | Datapath RTL, controller FSM, clock generation |

*ENGS 31 / CoSc 56 — Digital Electronics, Dartmouth College, Spring 2026*

---

## Acknowledgements

- **J. Graham Keggi** — `vga_sync` and `vga_test_pattern_12bit` modules, originally written for the Spartan3E Nexys2 and adapted here for the Basys3.
- **ENGS 31 Course Staff** — project specification, lecture slides on VGA timing, and lab infrastructure.
- [sudoku.com/easy](https://sudoku.com/easy/) — source of the hardcoded puzzle used in development.
- Digilent Basys3 Reference Manual and Xilinx Vivado documentation.

---

*Built with synthesizable VHDL — no processors were harmed in the making of this project.*
