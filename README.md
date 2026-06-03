# Proto

**Embedded 24-bit stereo audio recorder** coin-cell powered, STM32G431, dual MEMS mics, microSD logging.

[![STM32](https://img.shields.io/badge/MCU-STM32G431-0096c6.svg)](https://www.st.com/en/microcontrollers-microprocessors/stm32-32-bit-arm-cortex-mcus.html)
[![C](https://img.shields.io/badge/Language-C-azure.svg)](https://en.wikipedia.org/wiki/C_(programming_language))
[![FATFS](https://img.shields.io/badge/Storage-FATFS-orange.svg)](http://elm-chan.org/fsw/ff/00index_e.html)

![Board overview](https://github.com/user-attachments/assets/6882d186-b1bd-4c36-b714-b6d0aef492f9)
![Board detail](https://github.com/user-attachments/assets/bd112ea4-7bae-4670-8bdd-320bb84a3ab9)

---

## Features

- **24-bit stereo audio** at 48 kHz from two TDK ICS-43434 MEMS microphones
- **Battery powered** — runs from a single coin cell via J1 (Vbat/GND) with TPS61021 boost regulator
- **SD card logging** — FATFS-based WAV file storage on microSD (J2)
- **Timestamped filenames** — auto-generated `YYMMDD_HHMMSS.WAV`
- **Slide switch power** — SW1 controls boost regulator ON/OFF; SW2 handles MCU reset
- **Low power** — STM32G431 with DMA-driven I2S capture, minimal CPU involvement
- **Compact footprint** — custom PCB in 32-pin UFQFPN form factor

## Block Diagram

```
+-----------+     +-----------+     +-----------+
| Coin Cell |---->| TPS61021  |---->| STM32G431 |
| (Vbat/GND)|     | Boost     |     | Cortex-M4 |
+-----------+     +-----------+     +-----------+
                                          |
+-----------+                             |
| ICS-43434 |---+                         |
| (Left)    |   |                         |
+-----------+   |                         |
+-----------+   |   +-----------+         |
| ICS-43434 |---+-->| I2S2      |---------+
| (Right)   |       | Philips   |
+-----------+       +-----------+
                        |
                        v
                +-----------+
                | DMA +     |----> MicroSD (J2)
                | FATFS     |
                +-----------+
                        |
                        v
                +-----------+
                | LED (PA7) |
                | SW2 (RST) |
                +-----------+
```

## Hardware

### Components

| Ref | Part | Description |
|-----|------|-------------|
| **U1** | STM32G431KBU6 | ARM Cortex-M4, 128 KB Flash, 32 kB RAM, 32-pin UFQFPN |
| **U2** | TPS61021ADSGR | Boost regulator, 2.3–5.5 V in, 3.3 V out, 3 A |
| **U3** | ICS-43434 | TDK omni-directional MEMS mic, -26 dBFS |
| **U4** | ICS-43434 | TDK omni-directional MEMS mic, -26 dBFS |

### Connectors

| Ref | Description |
|-----|-------------|
| **J1** | 3×2.54 mm — Vbat / GND, coin cell input |
| **J2** | Hirose DM3NW-SF-PEJ(800) — MicroSD push-push SMD |
| **J3** | 10×1.27 mm — SWCLK + SDIO, debugging & programming |

### Switches

| Ref | Description |
|-----|-------------|
| **SW1** | TE 1825282-1 — Slide switch, boost regulator ON/OFF |
| **SW2** | E-Switch TL3901AGQF180 — Tactile push button, MCU reset |

## Software

### Stack

| Layer | Technology |
|-------|-----------|
| **MCU** | STM32G431KBU6 (ARM Cortex-M4 @ 170 MHz) |
| **Drivers** | STM32 HAL (I2S, SPI, DMA, GPIO) |
| **File System** | FATFS |
| **Language** | C |
| **IDE** | STM32CubeIDE (make-based) |

### Audio Pipeline

1. Two ICS-43434 MEMS microphones feed STM32 I2S2 in Philips mode
2. 24-bit samples at 48 kHz, stereo (L/R)
3. DMA transfers audio to RAM with half-transfer / transfer-complete callbacks
4. Samples are written as interleaved 24-bit PCM to WAV files on microSD
5. Files are named with timestamps (`YYMMDD_HHMMSS.WAV`)

## Build

1. Open `cubemx.ioc` in **STM32CubeMX** to regenerate the initialization code
2. Import the project into **STM32CubeIDE**
3. Build with `make` or use the IDE's build button

## Project Structure

```
proto/
├── Core/
│   ├── Inc/                    # Header files
│   └── Src/
│       ├── main.c              # Application entry point
│       ├── stm32g4xx_it.c      # Interrupt handlers
│       └── stm32g4xx_hal_msp.c # Peripheral MSP callbacks
├── Drivers/
│   ├── CMSIS/                  # ARM CMSIS libraries
│   └── STM32G4xx_HAL_Driver/   # ST HAL drivers
├── FATFS/
│   ├── App/                    # FATFS application layer
│   └── Target/                 # Disk I/O abstraction (SPI)
├── Middlewares/
│   └── Third_Party/FatFs/      # FATFS source
├── cubemx.ioc                  # STM32CubeMX project file
├── STM32G431KBUX_FLASH.ld      # Flash linker script
└── proto.csv                   # BOM (Altium export)
```

## References

- [STM32G431 Product Page](https://www.st.com/en/microcontrollers-microprocessors/stm32-32-bit-arm-cortex-mcus.html)
- [TPS61021 Datasheet (TI)](https://www.ti.com/lit/ds/symlink/tps61021a.pdf)
- [ICS-43434 Datasheet (TDK)](https://product.tdk.com/en/search/sw_piezo/mic/mems-mic/info?part_no=ICS-43434)
- [FATFS Documentation](http://elm-chan.org/fsw/ff/00index_e.html)
