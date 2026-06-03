##############################################################################
# Makefile for STM32G431 Audio Recorder Project
# Auto-generated build system — no STM32CubeIDE required
##############################################################################

# Toolchain
CPU      = -mcpu=cortex-m4
FPU      = -mfpu=fpv4-sp-d16
FLOAT_API = -mfloat-abi=hard
MCU      = $(CPU) -mthumb $(FPU) $(FLOAT_API)

CC       = arm-none-eabi-gcc
AS       = arm-none-eabi-gcc -x assembler-with-cpp
CP       = arm-none-eabi-objcopy
OD       = arm-none-eabi-objdump
SZ       = arm-none-eabi-size

# Build directory
BUILD    = Build

# Source files
CORE_SRC = Core/Src/main.c \
           Core/Src/stm32g4xx_hal_msp.c \
           Core/Src/stm32g4xx_it.c \
           Core/Src/syscalls.c \
           Core/Src/sysmem.c \
           Core/Src/system_stm32g4xx.c \
           Core/Src/libc_stub.c

STARTUP  = Core/Startup/startup_stm32g431kbux.s

FATFS_SRC = FATFS/App/app_fatfs.c \
            FATFS/Target/user_diskio.c \
            FATFS/Target/user_diskio_spi.c

HAL_SRC   = Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_adc.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_adc_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_cortex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_dma_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_exti.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_flash_ramfunc.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_gpio.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_i2s.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_pwr_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_rcc_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_spi.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_hal_spi_ex.c \
            Drivers/STM32G4xx_HAL_Driver/Src/stm32g4xx_ll_adc.c

FATFS_LIB = Middlewares/Third_Party/FatFs/src/ff.c \
            Middlewares/Third_Party/FatFs/src/diskio.c \
            Middlewares/Third_Party/FatFs/src/ff_gen_drv.c \
            Middlewares/Third_Party/FatFs/src/option/syscall.c

# All source files
SRC = $(CORE_SRC) $(STARTUP) $(FATFS_SRC) $(HAL_SRC) $(FATFS_LIB)

# Object files
OBJ = $(patsubst %,$(BUILD)/%.o,$(SRC))

# Include paths
INCDIR = Core/Inc \
         Drivers/STM32G4xx_HAL_Driver/Inc \
         Drivers/CMSIS/Device/ST/STM32G4xx/Include \
         Drivers/CMSIS/Include \
         FATFS/Target \
         FATFS/App \
         Middlewares/Third_Party/FatFs/src

# C defines
CDEFS = STM32G431xx USE_HAL_DRIVER

# Compiler flags
CFLAGS = $(MCU)
CFLAGS += -Wall -fdata-sections -ffunction-sections
CFLAGS += -std=c11
CFLAGS += -Og
CFLAGS += -g3 -gdwarf-2
CFLAGS += $(addprefix -I,$(INCDIR))
CFLAGS += $(addprefix -D,$(CDEFS))

# Linker script
LDSCRIPT = STM32G431KBUX_FLASH.ld

# Assembler flags
ASFLAGS = $(MCU) -Wall -fdata-sections -ffunction-sections
ASFLAGS += -Wa,-a,-ad,-alms=$(BUILD)/$(notdir $*.lst)
ASFLAGS += $(addprefix -I,$(INCDIR))
ASFLAGS += $(addprefix -D,$(CDEFS))

# Linker flags
LDFLAGS = -T$(LDSCRIPT) -Wl,--gc-sections -Wl,--print-memory-usage

# Output
TARGET = $(BUILD)/proto.elf
HEX    = $(BUILD)/proto.hex
BIN    = $(BUILD)/proto.bin

# Default target
all: $(TARGET) $(HEX) $(BIN) $(BUILD)/memory_usage.txt

$(BUILD)/memory_usage.txt: $(TARGET)
	@$(SZ) --format=berkeley $< > $@
	@echo ""
	@echo "=== Memory Usage ==="
	@cat $@

# Compile C sources
$(BUILD)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# Compile ASM sources
$(BUILD)/%.s.o: %.s
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -c $< -o $@

# Link
$(TARGET): $(OBJ)
	arm-none-eabi-ld --gc-sections -T$(LDSCRIPT) --print-memory-usage \
		$(OBJ) \
		/usr/lib/gcc/arm-none-eabi/14.2.1/thumb/v7e-m+fp/hard/libgcc.a \
		/usr/lib/gcc/arm-none-eabi/14.2.1/thumb/v7e-m+fp/hard/crti.o \
		/usr/lib/gcc/arm-none-eabi/14.2.1/thumb/v7e-m+fp/hard/crtbegin.o \
		/usr/lib/gcc/arm-none-eabi/14.2.1/thumb/v7e-m+fp/hard/crtn.o \
		-o $@
	@$(SZ) --format=berkeley $@
	@echo ""
	@echo "=== Memory Usage ==="
	@$(SZ) --format=berkeley $@ > $(BUILD)/memory_usage.txt
	@cat $(BUILD)/memory_usage.txt

# Convert to hex and bin
$(HEX): $(TARGET)
	$(CP) -O ihex $< $@

$(BIN): $(TARGET)
	$(CP) -O binary -S $< $@

# Clean
clean:
	rm -rf $(BUILD)

# Disassembly
disasm: $(TARGET)
	$(OD) -S $< > $(BUILD)/disasm.txt

# Flash (requires openocd/stlink)
flash: $(BIN)
	openocd -f interface/stlink.cfg -f target/stm32g4x.cfg -c "program $(BIN) verify reset exit"

# Reset
.PHONY: all clean flash disasm
