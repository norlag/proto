# Proto

Prototype PCB — STM32G431-based embedded system.

## Overview

CubeIDE project (make-based) for a custom STM32G431 board with microphone input,
microSD storage, battery backup, and user interface LEDs/switches.

## Hardware / Chips on Board

| Ref | Part | Description |
|-----|------|-------------|
| **U1** | STM32G431KBU6 | STMicroelectronics — 32-bit MCU, 128 KB Flash, 32-pin UFQFPN |
| **U2** | TPS61021ADSGR | Texas Instruments — Adjustable Boost Regulator, 3 A, 8 WSON |
| **U3** | ICS-43434 | TDK — Omni-directional MEMS Microphone, -26 dB |
| **U4** | ICS-43434 | TDK — Omni-directional MEMS Microphone, -26 dB |

### Passive & Passive-like Components

- **BT1** — Keystone 1063: Coin cell battery holder (20 mm, 1-2 cells)
- **C1-C3** — MLCC capacitors (10 uF / 47 uF / 220 pF)
- **C4-C10** — Samsung CL21B104KBCNNNC: 100 nF 0805 (x7)
- **L1** — Murata DFE252012P-R47M: 0.47 uH shielded inductor (boost converter)
- **R1-R15** — Resistors: 10 k, 390, 100 k, 316 k, 1 k
- **D1** — Nexperia PESD3V3L1UB: TVS diode 3.3 V SOD523
- **D2-D6** — Diodes Inc. LTL-1CHEE: Red LEDs (T/H, x5)

### Connectors & I/O

- **J1** — Samtec MTLW-103-07-G-S-230: 3-pos vertical header 2.54 mm
- **J2** — Hirose DM3NW-SF-PEJ(800): MicroSD card push-push SMD
- **J3** — CNC Tech 3220-10-0100-00: 10-pos shrouded header 1.27 mm
- **SW1** — TE 1825282-1: Slide switch SPDT
- **SW2** — E-Switch TL3901AGQF180: Tactile push button

## Project Structure

```
Core/
  Inc/            -- HAL header files
  Src/            -- HAL source files
  Startup/        -- Startup assembly files
Drivers/
  CMSIS/          -- ST Cube HAL + CMSIS
  STM32G4xx_HAL_Driver/
FATFS/
  App/            -- FatFS application layer
  Target/         -- FatFS target (SDMMC)
Middlewares/
  Third_Party/    -- Third-party libraries (FatFS)
Debug/            -- Makefile, linker script, build objects
STM32G431KBUX_FLASH.ld  -- Linker script
cubemx.ioc        -- STM32CubeMX project
```

## Build

Open `cubemx.ioc` in STM32CubeMX to regenerate code, then open the project
in STM32CubeIDE or build from command line:

```bash
cd Debug
make -j$(nproc)
```

## BOM

Full bill of materials exported from Altium: `proto.csv`
