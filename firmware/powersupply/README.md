# Power supply firmware

Firmware of the AuPrV1_1 vehicle power supply: ignition (KL15), power-on and
shutdown timing, alive watchdog and the three relays. Board, protocol and
states are described in [docs/23-power-supply.md](../../docs/23-power-supply.md).

Taken over from
[DerKleinePunk/carnine](https://github.com/DerKleinePunk/carnine)
`src/powersupply/RaspberryPower/` at a84e9fa (2023-03-12), version V2.2.12.

**V2.3.0** (2026-09-25): the Pi gets 60 s instead of 30 s to boot
(`PI_BOOT_TIME`), and RUN starts with the alive counter at 3 instead of 1
(`PI_ALIVE_ON_RUN`), so a Pi that has not sent `+` yet has 3 s of grace
instead of 1.
Authors: Marcus Borst, Michael Nenninger.

## Build

```sh
./build.sh          # build/RaspberryPower.bin, .hex, .eep, .lss, .map
./build.sh clean
```

`build.sh` uses an installed `avr-gcc` (Debian/Ubuntu:
`sudo apt install gcc-avr avr-libc binutils-avr make`) and otherwise builds
in a Debian container with podman or docker. ATmega88P, 8 MHz, `-Os`; the
firmware uses about 4.1 KB of the 8 KB flash.

The current compiler warns `-Wstringop-overflow` for every `SendString` call,
because the functions are declared with `char s[50]` parameters. That is
harmless: an array parameter is a pointer, and the strings are
zero-terminated. The warnings stay until the code is touched anyway.

## Flash

`build/RaspberryPower.bin` goes onto the chip with the Windows flashing tool
through the bootloader on the serial line: copy the file to the Windows
machine and write it from there. The firmware command `U` resets the chip
into that bootloader. How the bootloader itself is put on or updated is a
separate topic and not part of this firmware.

Note: the firmware keeps two settings in the EEPROM (debug output, power-on
delay) and writes defaults there on first start; flashing the program does
not reset them.
