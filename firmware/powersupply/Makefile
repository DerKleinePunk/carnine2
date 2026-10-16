# Firmware of the AuPrV1_1 vehicle power supply (docs/23-power-supply.md).
# ATmega88P at 8 MHz. Needs avr-gcc, avr-libc and binutils-avr; ./build.sh
# runs this in a container when they are not installed.

MCU = atmega88p
F_CPU = 8000000UL
BUILD = build
TARGET = $(BUILD)/RaspberryPower

CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size

CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -std=gnu99 -Wall -gdwarf-2 \
	-funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
LDFLAGS = -mmcu=$(MCU) -Wl,-Map=$(TARGET).map

OBJECTS = $(BUILD)/RaspberryPower.o $(BUILD)/serial.o

# .bin is what the Windows flashing tool takes, .hex is for avrdude.
all: $(TARGET).bin $(TARGET).hex $(TARGET).eep $(TARGET).lss
	$(SIZE) --mcu=$(MCU) $(TARGET).elf

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: %.c helper.h serial.h | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -j .text -j .data -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -R .eeprom -R .fuse -R .lock -R .signature -O ihex $< $@

# EEPROM defaults; the firmware writes its own on first start, so this is
# only informational.
$(TARGET).eep: $(TARGET).elf
	-$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" \
		--change-section-lma .eeprom=0 --no-change-warnings -O ihex $< $@ || exit 0

$(TARGET).lss: $(TARGET).elf
	$(OBJDUMP) -h -S $< > $@

# Host tests: the firmware compiled unchanged with the host's gcc against
# tests/fake/ (registers as plain variables), see tests/firmware_test.c.
HOSTCC ?= cc
test: | $(BUILD)
	$(HOSTCC) -std=gnu99 -Wall -Wno-unused-function -Wno-type-limits \
		-funsigned-char -Itests/fake $(TEST_FLAGS) \
		tests/firmware_test.c -o $(BUILD)/firmware_test
	$(BUILD)/firmware_test

clean:
	rm -rf $(BUILD)

.PHONY: all clean test
