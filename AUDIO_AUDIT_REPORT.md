
═══════════════════════════════════════════════════════════
  STM32G431 KUBU6 — I2S AUDIO RECORDING PROJECT
  COMPREHENSIVE CODE AUDIT & GAP ANALYSIS
═══════════════════════════════════════════════════════════

1. HARDWARE CONFIGURATION (from cubemx.ioc + BOM)
───────────────────────────────────────────────────
MCU:        STM32G431KBU6 (32KB RAM, 128KB Flash, LQFP32)
Clock:      160 MHz (HSI 16MHz → PLL N=20)
SysCLK:     160 MHz, AHB=160MHz, APB1=80MHz, APB2=160MHz

Audio Input:
  I2S2:     SPI2 in I2S Master RX mode
  WS:       PF0
  CK:       PF1
  SD:       PA11
  Format:   I2S_DATAFORMAT_24B (Philips standard)
  Freq:     48 kHz
  DMA:      DMA1_Channel1, circular, PERI=HALFWORD, MEM=HALFWORD

SD Card:
  SPI1:     Master, 8-bit, 625 kbps (prescaler 256)
  SCK:      PB3, MISO: PB4, MOSI: PB5
  CS:       NOT DEFINED (critical gap!)

GPIO:
  PA0:      ADC1_IN1 (unused)
  PA1:      GPIO_Output (mic select?)
  PA2:      GPIO_Output (mic select?)
  PA7:      GPIO_Output (LED)
  PB7:      GPIO_Input (button?)

2. CURRENT IMPLEMENTATION STATUS
───────────────────────────────────────────────────
✅ Clock configuration (160 MHz via PLL)
✅ I2S2 configured as Master RX, Philips, 24-bit, 48kHz
✅ DMA1_Channel1 circular for I2S2 RX
✅ SD Card SPI1 initialized (but NOT connected to FATFS)
✅ FATFS mounted (app_fatfs.c)
✅ WAV header generation (44 bytes, hardcoded)
✅ DMA receive callback (RxCpltCallback)
✅ Main loop: check flag → process → write → repeat
✅ 5-second recording (240 loops × 1000 frames)
✅ LED indicator (PA7)
✅ SysTick timer

❌ SD Card driver NOT wired (user_diskio.c has empty stubs)
❌ SD Card Chip Select pin NOT defined
❌ DMA buffer size mismatch (see §3)
❌ WAV header says 32-bit but I2S is 24-bit
❌ Audio processing has byte-order issues (see §4)
❌ No error handling
❌ No overflow/dropout detection
❌ No power management / low-power mode

3. CRITICAL BUGS
───────────────────────────────────────────────────

BUG #1: DMA Buffer Alignment MISMATCH
  I2S2 DataFormat:  I2S_DATAFORMAT_24B (24 bits per sample)
  DMA PeriphAlign:  DMA_PDATAALIGN_HALFWORD (16 bits)
  DMA MemAlign:     DMA_MDATAALIGN_HALFWORD (16 bits)
  
  With 24-bit I2S data, the HAL uses "16-bit extended" mode
  internally. Each "sample" is actually 2 × 16-bit words:
    - Word 0: [16 bits of audio data + padding]
    - Word 1: [8 bits of audio data + 8 bits padding]
  
  The DMA transfers 16-bit words, so:
    - Each I2S sample = 2 DMA words = 4 bytes
    - mic_rx_buffer is uint16_t[], so it receives 16-bit words
  → This is actually CORRECT for 24-bit I2S in extended mode.

BUG #2: WAV HEADER SAYS 32-BIT BUT DATA IS 24-BIT
  Header declares:
    ByteRate:  384,000 (48000 × 2 × 4 bytes) ← WRONG
    BlockAlign: 8 (2 × 4) ← WRONG
    BitsPerSample: 32 ← WRONG
  
  Actual data is 24-bit, so header should say:
    ByteRate:  288,000 (48000 × 2 × 3)
    BlockAlign: 6 (2 × 3)
    BitsPerSample: 24

BUG #3: AUDIO PROCESSING BYTE RECONSTRUCTION
  Code does:
    raw_left  = ((int32_t)mic_rx_buffer[i] << 16) | mic_rx_buffer[i+1]
    raw_right = ((int32_t)mic_rx_buffer[i+2] << 16) | mic_rx_buffer[i+3]
    stereo_audio[idx] = raw_left >> 8   // Shifts to 16-bit
  
  Issues:
  - The 24-bit I2S data from ICS-43434 is LEFT-JUSTIFIED
    (not right-aligned). The <<16 | shift assumes MSB-first
    data where the first 16-bit word contains the MSBs.
  - With Philips I2S standard and 24-bit format:
    - First transfer: bits [23:8] of sample → 16-bit word
    - Second transfer: bits [7:0] + padding → 16-bit word
  - The >>8 at the end converts to 16-bit, but the sign
    extension may be wrong for negative samples.
  - The interleaving assumes: [L_word0, L_word1, R_word0, R_word1]
    per group of 4 uint16_t entries.

BUG #4: SD CARD DRIVER NOT WIRED
  user_diskio.c has empty stubs:
    USER_initialize → returns STA_NOINIT
    USER_read → returns RES_OK (does nothing)
    USER_write → returns RES_OK (does nothing)
    USER_ioctl → returns RES_OK (does nothing)
    USER_get_state → returns STA_NOINIT
  
  user_diskio_spi.c has a working SPI driver but it's NOT
  called from user_diskio.c.

BUG #5: SD CARD CHIP SELECT NOT DEFINED
  No CS pin defined in main.h or cubemx.ioc.
  user_diskio_spi.c expects SD_SPI_HANDLE, SD_CS_GPIO_Port,
  SD_CS_Pin — none are defined.

4. ARCHITECTURE & DESIGN ISSUES
───────────────────────────────────────────────────

ISSUE #1: 5-SECOND RECORDING IS TOO SHORT
  At 24-bit stereo 48kHz:
    5 sec × 48000 × 2 × 3 bytes = 13.8 MB
  But STM32G431 has only 32KB RAM!
  The code works by writing to SD card incrementally,
  which is the correct approach.

ISSUE #2: NO FSYNC AFTER WRITES
  f_write() calls don't include f_sync(). If power is lost
  mid-recording, the file is corrupted.

ISSUE #3: BLOCKING f_write() IN MAIN LOOP
  f_write() can take 100+ ms per call (SD card write).
  The DMA is circular so it keeps filling the buffer,
  but the main loop is blocked during f_write().
  If the buffer overflows during f_write(), audio data is lost.

ISSUE #4: DMA CIRCULAR MODE BUT NO DOUBLE BUFFERING
  The DMA runs in circular mode with a single buffer.
  When RxCpltCallback fires, the buffer has been fully
  transferred and the DMA starts overwriting from the beginning.
  The main loop processes the data, but there's no protection
  against the DMA overwriting data that hasn't been processed yet.

ISSUE #5: RECORDING SIZE CALCULATION
  MAX_RECORD_LOOPS = 240
  NUM_STEREO_FRAMES = 1000 (assumed from mic_rx_buffer size)
  mic_rx_buffer size = 1000 * 4 = 4000 uint16_t = 8000 bytes
  Each loop writes NUM_STEREO_FRAMES * 2 * 4 = 8000 bytes
  Total: 240 × 8000 = 1,920,000 bytes = ~1.9 MB
  
  But WAV header says ByteRate = 384,000 (32-bit)
  Expected 5-sec file: 5 × 384,000 = 1,920,000 bytes ✓
  
  If corrected to 24-bit:
  Expected 5-sec file: 5 × 288,000 = 1,440,000 bytes
  Actual written: 1,920,000 bytes (mismatch!)

5. RECOMMENDATIONS (Priority Order)
───────────────────────────────────────────────────

P0 — CRITICAL (will not work at all):
  1. Wire SD card driver: Update user_diskio.c to call
     USER_SPI_* functions from user_diskio_spi.c
  2. Define SD card CS pin in main.h and MX_GPIO_Init
  3. Ensure MX_FATFS_Init triggers USER_SPI_initialize

P1 — CRITICAL DATA CORRUPTION:
  4. Fix WAV header: Change from 32-bit to 24-bit PCM
     (or fix data to actually be 32-bit)
  5. Verify DMA buffer interleaving matches actual I2S data layout
  6. Add f_sync() after each f_write() block

P2 — IMPORTANT:
  7. Implement double-buffering for DMA to prevent data loss
  8. Add overrun/underrun detection (check I2S OVR/UDR flags)
  9. Add error handling for f_open, f_write, f_close
  10. Consider reducing sample rate or switching to 16-bit
      to reduce file size by 33%

P3 — NICE TO HAVE:
  11. Implement pause/resume functionality
  12. Add file naming (timestamp-based)
  13. Add button (PB7) to start/stop recording
  14. Add LED blink pattern for recording status
  15. Implement power-down after recording complete

6. WHAT NEEDS TO BE IMPLEMENTED
───────────────────────────────────────────────────

IMMEDIATE (to get audio recording working):
  A. Wire user_diskio.c to use user_diskio_spi.c
  B. Add SD_CS pin definition and GPIO init
  C. Fix WAV header to match actual data format
  D. Verify DMA buffer processing is correct

NEEDED FOR RELIABLE OPERATION:
  E. Double-buffering (HAL_I2S_Receive_DMA with half-complete callback)
  F. f_sync() calls after writes
  G. Error handling and status reporting

OPTIONAL IMPROVEMENTS:
  H. Switch to 16-bit PCM (halves file size)
  I. Add button-controlled recording
  J. Implement file rotation / max file size
  K. Add CRC check on written data

═══════════════════════════════════════════════════════════
  SUMMARY: The project has a working skeleton but cannot
  actually record audio because the SD card driver is not
  wired up. The audio processing logic has potential issues
  with byte alignment and the WAV header doesn't match the
  actual data format. The I2S configuration (24-bit, Philips,
  48kHz) is correct for the ICS-43434 microphones.
═══════════════════════════════════════════════════════════
