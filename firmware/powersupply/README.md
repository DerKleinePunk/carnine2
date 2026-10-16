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
**V2.4.0** (2026-10-16):
- Ignition off during PIBOOT now gives the Pi its 15 s to shut down once
  PIBOOT ends. Before, `powerOffTimer` was still 0 and the next pass cut the
  Pi's power without a shutdown.
- A lone `*` (line noise) waits at most 20 ms for its digit, then NACK.
  Before, it waited for ever; the hardware watchdog reset the chip and every
  relay dropped.
- `U`/`u` enters the bootloader only in IDLE or POWERON, while the Pi has no
  power; otherwise NACK. **Flash with the ignition off.**
- KL15 counts as off only after 1 s without a break (on counts at once), so
  a short dip no longer starts the irreversible POWEROFF.
- Debug output is off by default. The first start of V2.4.0 switches it off
  once on a module that ran an older version (EEPROM byte 2 = `0x02` marks
  that); `#` switches it on again for good.

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

## Tests

```sh
./build.sh test     # or: make test
```

`tests/firmware_test.c` compiles `RaspberryPower.c` and `serial.c` unchanged
with the host's `cc` against stand-ins for the AVR headers (`tests/fake/`):
registers are plain variables, each pass of the main loop gets one
millisecond tick, and the hardware watchdog (about 125 ms) and `cli()` in
`ResetTheChip()` count as a chip reset. The tests drive ignition, Dig3 and
the serial line and check relays, states and answers. CI runs them.

## Flash

`build/RaspberryPower.bin` goes onto the chip with the Windows flashing tool
through the bootloader on the serial line: copy the file to the Windows
machine and write it from there. How the bootloader itself is put on or
updated is a separate topic and not part of this firmware.

**Into the bootloader:** the command `U` or `u` on the serial line
(`Interpret()` → `SwitchToBootLoaderOperation()` in `RaspberryPower.c`)
waits a moment and resets the chip through the watchdog (`ResetTheChip()`);
after the reset the bootloader runs for a short time. The command gets no
ACK. With debug output on, and only while `USB_Connected()` reads pin PC0
as high, the firmware first sends "Reboot for Bootloader".

**`GetInfo`:** according to Michael the bootloader understands the command
`GetInfo` followed by Enter (CR/LF). Not tried yet, and nothing is built
for it. Open, to be tried together with Michael because the supply
restarts: how long the bootloader window lasts and what `GetInfo` answers.

Note: the firmware keeps two settings in the EEPROM (debug output, power-on
delay) and writes defaults there on first start; flashing the program does
not reset them.
