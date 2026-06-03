# Proto

Prototype PCB — STM32G431-based embedded system.

<img width="599" height="596" alt="image" src="https://github.com/user-attachments/assets/6882d186-b1bd-4c36-b714-b6d0aef492f9" />

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

### Connectors & I/O

- **J1** — Samtec MTLW-103-07-G-S-230: 3-pos vertical header 2.54 mm
- **J2** — Hirose DM3NW-SF-PEJ(800): MicroSD card push-push SMD
- **J3** — CNC Tech 3220-10-0100-00: 10-pos shrouded header 1.27 mm
- **SW1** — TE 1825282-1: Slide switch SPDT
- **SW2** — E-Switch TL3901AGQF180: Tactile push button

## Build

Open `cubemx.ioc` in STM32CubeMX to regenerate code, then open the project
in STM32CubeIDE

Full bill of materials exported from Altium: `proto.csv`
