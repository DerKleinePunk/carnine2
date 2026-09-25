# 23 – Vehicle Power Supply (Ignition, Shutdown, Watchdog)

**Status:** not integrated yet (2026-09-25). The hardware and its firmware
come from the predecessor project
[DerKleinePunk/carnine](https://github.com/DerKleinePunk/carnine); the
firmware is now in [firmware/powersupply/](../firmware/powersupply/README.md)
and builds here, but nothing in carnine2 talks to the supply so far.

## Why

In the car the Pi must not lose power while it writes to the SD card, and it
must not drain the battery when the car is parked. The power supply watches
the ignition (terminal 15, KL15), switches the Pi and the peripherals on and
off, gives the Pi time to shut down, and power-cycles a Pi that hangs.

## Board

**AuPrV1_1 "Nenntronic"**, 70 × 60 mm, from 2023-02: ATmega88P, three
relays, IR receiver; input 9–30 V, output 5.15 V / 4 A. Two of these exist.
Drawings: [board](hardware/power-supply/AuPrV1_1-board.pdf),
[layout](hardware/power-supply/AuPrV1_1-layout.jpg),
[connectors](hardware/power-supply/AuPrV1_1-connectors.jpg) (old names
`MichaelNenninger_Power_a3.pdf`, `RaspberryNetzteil*.jpg`). The old project
also has a UPS board and a "MicroPower" board; both were experiments that did
not work out and are not used.

### AuPrV1_1 connections

![AuPrV1_1 connectors](hardware/power-supply/AuPrV1_1-connectors.jpg)

- **Screw terminals (bottom):** Rel1, Rel2, Rel3 (three contacts each),
  Zündung (KL15), Dauerplus (KL30), Masse, 3 × +5 V out.
- **Pin header (top), towards the Pi:** RXD, TXD, Dig1, Dig2, Dig3, GND,
  +5 V, Analog1–3.
- **Relays in the firmware:** relay 0 = display and HDMI splitter, relay 1 =
  Pi power, relay 2 = amplifier. That these are Rel1–Rel3 in this order is
  assumed from the numbering, not checked.

Open before connecting it to a Pi: the signal level on RXD/TXD. The Pi's
UART is 3.3 V and not 5 V tolerant; the AVR can run at 5 V.

## Firmware (V2.2.12)

[firmware/powersupply/](../firmware/powersupply/README.md), taken over
unchanged from the old project. ATmega88P at 8 MHz. `./build.sh` builds it on
Linux (with a container when `avr-gcc` is not installed) into
`build/RaspberryPower.bin`.

**Flashing** is done with a Windows program through the bootloader on the
serial line: build here, copy the `.bin` to Windows, write it from there. The
command `U` resets the chip into the bootloader. Which bootloader and
protocol that is, is being asked; if it is a standard one, flashing and later
updates could run from the Pi itself. Putting on or updating the bootloader
itself is separate from the firmware.

### Serial line

38400 baud, 8N1. The Pi sends single ASCII characters, the supply answers and
reports in small binary telegrams `STX <id> <payload> ETX` (STX 0x02, ETX
0x03).

**Every second** the supply sends:

| Telegram | Payload |
|---|---|
| `STX 0x10 … ETX` | KL15: `'0'` or `'1'` |
| `STX 0x11 … ETX` | alive counter, decimal digits |
| `STX 0x12 … ETX` | state as a digit: `0` IDLE, `1` POWERON, `2` PIBOOT, `3` RUN, `4` POWEROFF |
| `STX 0x14 … ETX` | supply voltage in 0.1 V, decimal digits |

Every command is answered with `STX 0x13 <ACK 0x06 | NACK 0x15> ETX`. With
debug output on (a switch kept in the EEPROM, **on by default**) plain text
lines ending in `\n`, partly with VT100 screen codes, are mixed into the same
stream; a receiver must skip them.

**Commands from the Pi:**

| Char | Effect |
|---|---|
| `+` | alive (heartbeat) |
| `$` | the Pi shuts down: amplifier off, state POWEROFF, 15 s until power off |
| `1` `2` `3` | relay 0 / 1 / 2 on |
| `4` `5` `6` | relay 0 / 1 / 2 off |
| `!` / `?` | service mode on (watchdog off) / off |
| `*` + digit | power-on delay 1–9 s, stored in the EEPROM |
| `v` | firmware version as text |
| `#` | toggle debug output (stored in the EEPROM) |
| `U` | reset into the bootloader |

### States

| State | Entered when | Does | Leaves when |
|---|---|---|---|
| IDLE | power-off finished | microcontroller sleeps | KL15 on → POWERON |
| POWERON | KL15 on | relay 0 on (display, HDMI splitter) | after the power-on delay → PIBOOT; KL15 off → IDLE |
| PIBOOT | delay over | relay 1 on (Pi power), boot timer 30 s | timer over → RUN; KL15 off at that point → POWEROFF |
| RUN | Pi booted | watchdog active | KL15 off → POWEROFF (15 s); no alive → POWEROFF (5 s) |
| POWEROFF | KL15 off, `$`, or watchdog | amplifier off, count down | timer over **or Dig3 active** → all relays off → IDLE |

- **Watchdog:** the alive counter is capped at 3 and drops by one per second
  in RUN (not in service mode). `+` raises it, and so do most other
  commands (not `4`, `!`, `?`, `*`, `v`). Without a `+` for
  about 3 seconds the supply cuts the Pi hard.
- **Pi halted:** with `dtoverlay=gpio-poweroff,active_low=1,gpiopin=5` in
  `config.txt` the Pi signals on GPIO 5 that it has halted. Wired to Dig3,
  the supply switches off at once instead of waiting the full 15 s. Another
  GPIO works too; Dig3 is fixed unless the firmware changes.

## What carnine2 needs for it

Nothing of this is built yet.

- **Image:** UART enabled for the supply and the serial console moved off it
  (`enable_uart`, `cmdline.txt`); `gpio-poweroff` overlay; the service user
  in `dialout`.
- **Backend:** a power module with its own configuration section, off by
  default, testable in WSL on a pseudo-terminal like the GPS source. It sends
  `+` regularly, reads KL15, voltage and state, shuts the Pi down through
  logind when the supply goes to POWEROFF, and sends `$` when the Pi shuts
  down on its own. State over gRPC plus a command in `media_grpc_client`.
- **Timing to check on the device:**
  - The alive `+` must start within about 33 s of the Pi getting power
    (30 s PIBOOT plus the watchdog), or the supply cuts a Pi that is still
    booting. Boot time to a running backend is not measured yet.
  - Shutdown must finish within 15 s, unless Dig3 reports the halt; the
    backend alone may take up to 10 s to stop (`TimeoutStopSec`).
  - The firmware can be changed where these do not fit.
- **Amplifier relay:** switching the amplifier on after the audio stream is
  open and off before it closes would hide the HDMI pop on the car radio.

The old C++ implementation (`src/backend/communication/PowerSupplySerial.cpp`
in the old project) sends `+` on every status telegram and schedules the
shutdown through logind one second after POWEROFF.
