# FPGA-Based Tetris

<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
  * [Tech Stack](#tech-stack)
  * [File Structure](#file-structure)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [System Architecture](#system-architecture)
* [BRAM-Based Display Implementation](#bram-based-display-implementation)
* [Results and Performance](#results-and-performance)
* [Future Enhancements](#future-enhancements)
* [Troubleshooting](#troubleshooting)
* [Contributors](#contributors)
* [Acknowledgements and Resources](#acknowledgements-and-resources)
* [License](#license)

<!-- ABOUT THE PROJECT -->
## About The Project

This project implements a fully functional Tetris game using pure digital logic on the Xilinx Artix-7 FPGA platform. Unlike software-based implementations, this design operates entirely in hardware, providing deterministic performance and real-time responsiveness.

**Key Features:**
* Complete hardware implementation using Verilog HDL
* Real-time VGA output at 640x480 resolution, 60Hz refresh rate
* Hardware-accelerated collision detection and game logic
* BRAM-based background rendering system
* Button-based user input with hardware debouncing
* Self-contained system requiring no external processor

**Project Specifications:**
* **Target Platform:** Arty A7-35T Development Board
* **Design Complexity:** Medium
* **Primary Domains:** FPGA Development, Digital Design, Embedded Graphics

### Tech Stack

* **Verilog HDL** - Hardware description language for RTL design
* **Xilinx Vivado Design Suite** - FPGA synthesis and implementation toolchain
* **Arty A7-35T** - Xilinx Artix-7 FPGA development platform
* **VGA Interface** - Video output standard
* **GPIO** - General-purpose I/O for user controls

### File Structure
```
SRA-FPGA-based-tetris/
├── src/
│   ├── game_logic/
│   │   ├── tetris_fsm.v          # Main game state machine controller
│   │   ├── collision_detector.v   # Hardware collision detection engine
│   │   ├── score_counter.v        # Score tracking and display logic
│   │   └── piece_generator.v      # Pseudo-random piece generation
│   ├── graphics/
│   │   ├── vga_controller.v       # VGA timing and synchronization
│   │   ├── frame_buffer.v         # Display memory management
│   │   └── pixel_generator.v      # Pixel rendering engine
│   ├── input/
│   │   ├── button_debouncer.v     # Hardware button debouncing
│   │   └── input_handler.v        # Input processing and mapping
│   └── top_module.v               # Top-level system integration
├── constraints/
│   └── arty_a7_35t.xdc           # Physical constraints and pin mappings
├── sim/
│   └── testbenches/               # Verification testbenches
├── docs/
│   └── design_document.pdf        # Detailed design specification
└── README.md
```

<!-- GETTING STARTED -->
## Getting Started

This section provides detailed instructions for setting up and deploying the FPGA-based Tetris project.

### Prerequisites

Required hardware and software:
* **Xilinx Vivado Design Suite** (2019.1 or later)
  - WebPACK edition is sufficient for this project
  - Download from: https://www.xilinx.com/support/download.html
* **Arty A7-35T Development Board**
* **VGA-compatible display**
* **VGA cable and PMOD VGA adapter**
* **Micro-USB cable** for FPGA programming

### Installation

#### 1. Repository Setup
```bash
git clone https://github.com/Harshit6-b/SRA-FPGA-based-tetris.git
cd SRA-FPGA-based-tetris
```

#### 2. Vivado Project Creation
1. Launch Vivado Design Suite
2. Select **Create Project** from the welcome screen
3. Configure project settings:
   - Name: `fpga_tetris`
   - Type: RTL Project
   - Target: Arty A7-35T (xc7a35ticsg324-1L)
   - Enable: "Create project subdirectory"

#### 3. Source File Integration
1. Add design sources:
   - Navigate to **Project Manager → Add Sources**
   - Select **Add or Create Design Sources**
   - Import all files from the `src/` directory
   - Enable "Copy sources into project"

2. Add constraints:
   - Select **Add or Create Constraints**
   - Import `constraints/arty_a7_35t.xdc`
   - Verify constraint associations

#### 4. Design Hierarchy Configuration
1. Locate `top_module` in the Sources panel
2. Right-click and select **Set as Top**
3. Verify the design hierarchy is correctly established

#### 5. Implementation and Bitstream Generation
1. Execute **Run Implementation** from the Flow Navigator
2. Upon completion, select **Generate Bitstream**
3. Review timing reports for any violations
4. Typical build time: 5-10 minutes depending on system specifications

#### 6. Hardware Deployment
1. Connect Arty A7-35T board via USB
2. Power on the development board
3. Open Hardware Manager
4. Select **Auto Connect** to detect the target device
5. Program device with generated bitstream
6. Verify successful programming via DONE LED indicator

<!-- USAGE -->
## Usage

### Hardware Setup
1. **Display Connection:** Connect VGA cable between the PMOD VGA adapter and monitor
2. **Power:** Ensure board is powered via USB or external adapter
3. **Verification:** Confirm DONE LED indicates successful configuration

### Game Controls
The system utilizes four on-board push buttons for game control:
- **BTN0:** Move tetromino left
- **BTN1:** Rotate tetromino (clockwise)
- **BTN2:** Hard drop (accelerated descent)
- **BTN3:** Move tetromino right

### Gameplay
Upon successful deployment, the game initializes automatically. The display presents the game field with falling tetrominoes, score tracking, and level progression.

<!-- SYSTEM ARCHITECTURE -->
## System Architecture

The FPGA-based Tetris implementation follows a modular hardware architecture designed for efficiency and maintainability.

### Core Components

#### 1. Game Logic 
Game follows the following logic:
- **INIT:** System initialization and memory clearing
- **SPAWN:** Tetromino generation and placement
- **ACTIVE:** Main gameplay with user input processing
- **COLLISION:** Collision detection and line clearing
- **GAME_OVER:** End state with score display

#### 2. VGA Display Subsystem
Implements standard VGA timing for 640x480@60Hz output:
- Horizontal sync: 96 pixel clocks
- Vertical sync: 2 line periods
- Pixel clock: 25.175 MHz (derived from 100 MHz system clock)

#### 3. Input Processing Pipeline
Hardware debouncing implementation with:
- The system latches the input on a high state and ignores subsequent inputs until the signal transitions back to low.
- After the input transitions to high, no additional inputs are accepted until a low state is detected.

#### 4. Collision Detection Engine
Combinatorial logic implementation providing:
- Boundary checking
- Inter-tetromino collision detection
- Single-cycle response time

<!-- BRAM-BASED DISPLAY IMPLEMENTATION -->
## BRAM-Based Display Implementation

The project utilizes FPGA Block RAM (BRAM) resources for efficient background image storage and rendering.

### BRAM Architecture

#### Memory Organization
The BRAM is configured as a frame buffer storing pre-rendered background graphics:
- **Capacity:** 307,200 pixels (640x480)
- **Color Depth:** 12-bit RGB (4 bits per channel)
- **Access Pattern:** Sequential read for VGA scanning

#### Background Image Content
The pre-stored image includes:
- Game title and branding elements
- Playing field boundaries and grid
- Score and level display regions
- Decorative elements enhancing visual appeal

### Rendering Pipeline

#### Layer Composition
The display system implements a three-layer rendering approach:

1. **Background Layer (BRAM):** Static graphics providing visual framework
2. **Game Field Layer:** Dynamic tetromino positions and settled pieces
3. **Overlay Layer:** Score, level, and game status information

#### Pixel Generation Logic
```verilog
// Simplified pixel output logic
always @(posedge pixel_clk) begin
    if (active_video) begin
        if (tetromino_present) 
            rgb_out <= tetromino_color;
        else if (field_region)
            rgb_out <= field_data;
        else
            rgb_out <= bram_background;
    end else begin
        rgb_out <= 12'h000; // Blanking
    end
end
```

### Performance Benefits
- **Resource Efficiency:** Eliminates need for runtime background generation
- **Consistent Timing:** BRAM access provides deterministic read latency
- **Visual Quality:** Enables complex background graphics without logic overhead

<!-- RESULTS AND PERFORMANCE -->
## Results and Performance

### Implementation Metrics
- **Resource Utilization:** 
  - LUTs: ~40% of available resources
  - Block RAM: 15 BRAM tiles
  - DSP Slices: None required
- **Maximum Frequency:** 125 MHz (system constrained to 100 MHz)
- **Power Consumption:** <2W total system power
- **Display Performance:** Consistent 60 FPS with zero frame drops

### Gameplay Characteristics
- Responsive controls with <16.7ms input latency
- Smooth tetromino movement and rotation
- Accurate collision detection
- Progressive difficulty scaling

<!-- FUTURE ENHANCEMENTS -->
## Future Enhancements

Planned improvements and extensions:

- **Display Upgrade:** HDMI output support for modern displays
- **Enhanced Controls:** UART interface for keyboard input
- **Audio System:** PWM-based sound effect generation

<!-- TROUBLESHOOTING -->
## Troubleshooting

### Display Issues

#### No VGA Output
1. Verify VGA cable connections at both PMOD adapter and monitor
2. Confirm monitor VGA input selection
3. Check FPGA configuration status via DONE LED
4. Review constraints file for correct PMOD pin assignments

#### Display Artifacts
- Ensure proper PMOD connector seating
- Verify VGA timing parameters in vga_controller.v
- Check for ground connection integrity
- Consider signal integrity issues with cable length

### Input System Problems

#### Continuous Movement Issue
**Problem Description:** Single button press results in multiple tetromino movements.

**Root Cause:** Insufficient debouncing or missing rate limiting in continuous press handling.

**Solutions:**
1. Increase `DEBOUNCE_DELAY` parameter in button_debouncer.v
2. Implement rate limiting for held buttons:
   ```verilog
   parameter REPEAT_DELAY = 500_000; // 5ms at 100MHz
   ```
3. Add state machine for press/hold/release detection

#### Non-Responsive Buttons
1. Verify correct button mapping in constraints file
2. Check for proper pull-up resistor configuration
3. Test with oscilloscope for signal integrity
4. Confirm game state allows input (not in GAME_OVER)

### Build and Synthesis Issues

#### Common Vivado Errors
1. **Missing Top Module:** Ensure top_module is designated as top-level entity
2. **Constraint Conflicts:** Verify pin names match between design and XDC
3. **Timing Violations:** 
   - Review critical path in timing report
   - Consider pipelining long combinatorial paths
   - Adjust clock constraints if necessary

### System-Level Debugging
For complex issues:
1. Utilize Integrated Logic Analyzer (ILA) for runtime debugging
2. Implement chipscope cores for internal signal monitoring
3. Create focused testbenches for module-level verification
4. Review synthesis warnings for potential issues

<!-- CONTRIBUTORS -->
## Contributors

* [Harshit Bhalani](https://github.com/Harshit6-b)
* [Zaid Faruqui](https://github.com/zadily)
* [Suchit Garad](https://github.com/IamLegend509) - Project Mentor
* [Sarvesh Ganu](https://github.com/sarveshganu) - Project Mentor
* [Shri Vishakh Devanand](https://github.com/5iri) - Project Mentor

<!-- ACKNOWLEDGEMENTS AND RESOURCES -->
## Acknowledgements and Resources

* [SRA VJTI](https://sravjti.in/) - Society of Robotics and Automation
* [Digilent Documentation](https://digilent.com/reference/programmable-logic/arty/reference-manual?redirect=1) - Arty A7 Reference
* [Digital Logic Design](https://www.youtube.com/watch?v=BoIOLczVulQ&list=PLyqSpQzTE6M_dZdF7Bd-Uncl5_L_1VkXF) - To learn Digital Logic Design
* [ChipVerify](https://www.chipverify.com/) - To learn Verilog
* [HDLbits](https://hdlbits.01xz.net/wiki/Problem_sets#Verilog_Language) - To learn Verilog
* [Tetris Logic](https://www.cs.columbia.edu/~sedwards/classes/2024/4840-spring/designs/FPGA-Tetris.pdf) - To understand Tetris Logic
* [VESA Standards](https://projectf.io/posts/video-timings-vga-720p-1080p/) - VGA Timing Specifications

<!-- LICENSE -->
## License

This project is licensed under the MIT License. See `LICENSE` file for details.
