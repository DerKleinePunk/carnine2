# 24 – CAN Adapter (MCP2515 on SPI0)

**Status:** preparation only (2026-09-27). No CAN adapter is planned for
now, and nothing in carnine2 talks CAN yet. This page fixes the pins so
that nothing else takes them, and collects what is needed to bring up
`can0` once an adapter is chosen. Open points are marked **TODO**. They
depend on the car and on the module bought for it, so they are found out
before fitting, not guessed here.

## Why

[07 – Deployment View](07-deployment.md) names an MCP2515 on SPI as one way
to reach the vehicle's CAN bus. The Pi already uses several GPIOs for the
[power supply](23-power-supply.md), so the CAN pins are reserved now.

## The MCP2515

From the Microchip data sheet (DS20001801J):

- Stand-alone CAN controller, CAN 2.0B up to 1 Mb/s, standard and extended
  frames, two receive buffers, six 29-bit filters and two masks.
- SPI interface up to 10 MHz, SPI modes 0,0 and 1,1.
- Supply 2.7–5.5 V.
- Clock from a crystal or an external clock: up to 25 MHz at 2.7–5.5 V,
  up to 40 MHz at 4.5–5.5 V. The data sheet lists 4, 8, 16 and 20 MHz
  crystals as tested.
- One general interrupt output **INT**, active low.
- It is only the controller. The bus lines CANH/CANL need a separate
  transceiver (XCVR in figure 1-2 of the data sheet); modules usually
  carry one.
- Loopback mode sends frames from the transmit to the receive buffers
  without putting anything on the bus, for development and testing.

## Pins on the Pi 4

The adapter sits on SPI0, chip select CE0, with its interrupt on
**GPIO 25**. Michael fixed GPIO 25 on 2026-09-27.

| Signal | GPIO | Header pin | MCP2515 pin |
|---|---|---|---|
| MOSI | GPIO 10 | 19 | SI |
| MISO | GPIO 9 | 21 | SO |
| SCLK | GPIO 11 | 23 | SCK |
| CE0 | GPIO 8 | 24 | CS |
| Interrupt | GPIO 25 | 22 | INT |
| GND | – | e.g. 20 | VSS |

SPI0 pin mapping from the Raspberry Pi documentation. CE1 (GPIO 7, pin 26)
stays free for a second device on SPI0.

These pins do not collide with what carnine2 already uses:

- uart5 to the power supply on GPIO 12/13 (pins 32/33),
- `gpio-poweroff` on GPIO 5 (pin 29),
- I2C on GPIO 2/3 (`dtparam=i2c_arm=on` in the image); keep it free,
- GPIO 0/1 are reserved for a HAT ID EEPROM.

uart4 would sit on GPIO 8/9 and is therefore not used; see
[Wiring to the Pi 4](23-power-supply.md#wiring-to-the-pi-4).

### Levels

The Pi's GPIOs are 3.3 V: outputs drive 3.3 V, and inputs take 3.3 V, not
5 V (Raspberry Pi documentation, "GPIO and the 40-pin header"). From the
MCP2515 data sheet (table 13-1):

- SO and INT drive close to the MCP2515's own supply (VOH = VDD − 0.5 V
  and VDD − 0.7 V). With VDD = 5 V they would put about 5 V on GPIO 9 and
  GPIO 25.
- SCK, CS and SI need 0.7 × VDD as high level, 3.5 V at VDD = 5 V, more
  than the Pi's 3.3 V.

An MCP2515 at 3.3 V fits the Pi directly. At 5 V it needs level shifting
on these lines.

**TODO (vehicle-dependent, find out before fitting):** which module is
used, whether its MCP2515 runs on 3.3 V or 5 V, and whether its transceiver
needs 5 V. That decides whether level shifting is needed.

## Device tree

The overlay `mcp2515-can0` (Raspberry Pi overlay README) configures an
MCP2515 on spi0.0:

```
dtoverlay=mcp2515-can0,oscillator=<Hz>,interrupt=25
```

| Parameter | Meaning | Default in the overlay source |
|---|---|---|
| `oscillator` | clock frequency of the CAN controller in Hz | 16000000 |
| `spimaxfrequency` | maximum SPI clock in Hz | 10000000 |
| `interrupt` | GPIO of the interrupt line | 25 |

- The defaults come from `mcp2515-can0-overlay.dts`; GPIO 25 is already
  the default, `interrupt=25` only makes it visible.
- The overlay switches SPI0 on itself and disables `spidev0.0`, so no
  `dtparam=spi=on` is needed for it.
- The generic overlay `mcp2515` does the same with `spi0-0` and the
  parameter `speed` instead of `spimaxfrequency`.
- `oscillator` must match the crystal on the module. A wrong value gives
  a wrong bit rate, and the adapter then cannot talk to the bus.

**TODO (vehicle-dependent, find out before fitting):** the crystal on the
chosen module (e.g. 8 or 16 MHz). It gives `oscillator=`.

The image does not load the overlay today.

## Bringing up can0

The SocketCAN commands below come from the kernel documentation
("SocketCAN – Controller Area Network", section on netlink). The bit rate
must be set before the interface goes up:

```bash
ip link set can0 up type can bitrate <bit/s>
ip -details link show can0
```

- `restart-ms 100` restarts the controller automatically after bus-off.
- `ip -details link show can0` shows state, bit timing and the clock the
  driver uses; it must match `oscillator=`.
- [07 – Deployment View](07-deployment.md) has an example with 500000.

**TODO (vehicle-dependent, find out before fitting):** the bit rate of the
bus and where it is tapped. 07 says "500 kbps or 1 Mbps (vehicle-specific)";
it differs from car to car and between the buses of one car.

## Testing

`candump` and `cansend` come from [can-utils](https://github.com/linux-can/can-utils).
The image does not install the package.

Without a bus, in the controller's loopback mode:

```bash
ip link set can0 down
ip link set can0 type can bitrate 500000 loopback on
ip link set can0 up
candump can0 &
cansend can0 123#DEADBEEF
```

`candump` shows the frame although nothing goes out on the bus. The kernel
driver `mcp251x` supports loopback, listen-only and triple sampling. This tests
SPI, interrupt and driver. The bit rate here is only an example, loopback
does not need the right one. For the real bus, bring the interface up again
with `loopback off`.

On the bus, first listen only, so a wrong bit rate does not disturb the
car:

```bash
ip link set can0 down
ip link set can0 type can bitrate <bit/s> listen-only on
ip link set can0 up
candump can0
```

`cansend` frame format: `<can_id>#<data>`, e.g. `123#DEADBEEF`
(usage text of `cansend`).

## Sources

- Microchip MCP2515 data sheet, DS20001801J:
  https://ww1.microchip.com/downloads/en/DeviceDoc/MCP2515-Stand-Alone-CAN-Controller-with-SPI-20001801J.pdf
- Raspberry Pi overlay README, `mcp2515` and `mcp2515-can0`:
  https://github.com/raspberrypi/linux/blob/rpi-6.12.y/arch/arm/boot/dts/overlays/README
- Overlay source with the defaults:
  https://github.com/raspberrypi/linux/blob/rpi-6.12.y/arch/arm/boot/dts/overlays/mcp2515-can0-overlay.dts
- Raspberry Pi documentation, SPI0 pin mapping:
  https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/computers/raspberry-pi/spi-bus-on-raspberry-pi.adoc
- Raspberry Pi documentation, GPIO levels:
  https://github.com/raspberrypi/documentation/blob/master/documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc
- Linux kernel driver `mcp251x` (supported control modes):
  https://github.com/raspberrypi/linux/blob/rpi-6.12.y/drivers/net/can/spi/mcp251x.c
- Linux kernel documentation, SocketCAN:
  https://www.kernel.org/doc/html/latest/networking/can.html
- can-utils, `cansend` usage: https://github.com/linux-can/can-utils
