# Proto

Embedded stereo audio logger on a SD card using an STM32G431 with dual MEMS mics.

<img width="599" height="596" alt="image" src="https://github.com/user-attachments/assets/6882d186-b1bd-4c36-b714-b6d0aef492f9" />
<img width="686" height="540" alt="image" src="https://github.com/user-attachments/assets/bd112ea4-7bae-4670-8bdd-320bb84a3ab9" />


## Overview

CubeIDE project (make-based) for a custom STM32G431 board featuring 24-bit stereo audio recording via dual I2S MEMS microphones, FATFS-based SD card logging, and DMA ping-pong buffering for non-blocking capture.

## About

This is a battery-powered embedded audio recorder built around the STM32G431 MCU. The board can be powered from a coin cell connected to **J1** (Vbat/GND), which feeds a TPS61021 boost regulator to provide the required 3.3 V rail.

Audio is captured from two TDK ICS-43434 MEMS microphones via I2S in Philips mode at 48 kHz / 24-bit. The DMA engine fills a ping-pong buffer, and each half-transfer triggers processing and a non-blocking SD write through FATFS. A tactile button (SW2) starts and stops recording, and the LED indicates recording status.

## Hardware / Chips on Board

| Ref | Part | Description |
|-----|------|-------------|
| **U1** | STM32G431KBU6 | STMicroelectronics — 32-bit MCU, 128 KB Flash, 32-pin UFQFPN |
| **U2** | TPS61021ADSGR | Texas Instruments — Adjustable Boost Regulator, 3 A, 8 WSON |
| **U3** | ICS-43434 | TDK — Omnidirectional MEMS Microphone, -26 dB |
| **U4** | ICS-43434 | TDK — Omnidirectional MEMS Microphone, -26 dB |

### Connectors & I/O

| Ref | Part | Description |
|-----|------|-------------|
| **J1** | Samtec MTLW-103-07-G-S-230 | 3-pos vertical header 2.54 mm — Vbat/GND (coin cell power) |
| **J2** | Hirose DM3NW-SF-PEJ(800) | MicroSD card push-push SMD |
| **J3** | CNC Tech 3220-10-0100-00 | 10-pos shrouded header 1.27 mm — SDIO + SWCLK programming |
| **SW1** | TE 1825282-1 | Slide switch SPDT — powers on/off the boost regulator |
| **SW2** | E-Switch TL3901AGQF180 | Tactile push button — wired to STM32 RESET pin |

## Build

Open `cubemx.ioc` in STM32CubeMX to regenerate code, then open the project
in STM32CubeIDE.

Full bill of materials exported from Altium: `proto.csv`
