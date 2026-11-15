<p align="center"><img src="resources/images/rund_256.png" alt="CarNine logo" width="200"></p>

<h1 align="center">CarNine</h1>

<p align="center">
  <b>Offline car infotainment for the Raspberry Pi 4.</b><br>
  Navigation with spoken directions, your music, the reversing camera –
  on a 7" touchscreen, without a phone and offline if you want.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Raspberry%20Pi-4-c51a4a.svg" alt="Raspberry Pi 4">
  <img src="https://img.shields.io/badge/UI-Flutter-02569B.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/backend-Rust-b7410e.svg" alt="Rust">
  <img src="https://img.shields.io/badge/maps-offline-2e7d32.svg" alt="Offline maps">
  <img src="https://img.shields.io/badge/license-GPLv3-blue.svg" alt="GPLv3">
  <img src="https://img.shields.io/badge/status-work%20in%20progress-yellow.svg" alt="Work in progress">
</p>

<p align="center">
  <img src="docs/bedienung/bilder/karte-navigation.png" alt="Driving view: route, next turn, speed" width="49%">
  <img src="resources/images/readme/player.jpg" alt="Music player" width="49%">
</p>
<p align="center">
  <img src="resources/images/readme/start.jpg" alt="Home screen: clock, navigation, music, quick switches, ignition and voltage" width="49%">
  <img src="docs/bedienung/bilder/cam-grabber.png" alt="Analog reversing camera through a USB grabber" width="49%">
</p>
<p align="center"><sub>Screenshots from the test Pi (7" panel, 1024 × 600), UI in German.
More at <a href="https://www.carnine.de">carnine.de</a>.</sub></p>

---

## Why CarNine

A car PC has to work where the mobile network ends, start with the ignition
and never drain the battery. CarNine is built around that:

- **Offline if you want.** Map tiles, routing, place search and the voice all
  run on the device: no account, no API key, no data leaving the car.
  Live traffic is built in and off by default; the switch in the options
  comes with the next UI update (#179).
- **It is made for the car, not for the desk.** It starts and shuts down with
  the ignition, protects the battery, survives a cold start in the middle of
  a drive and comes back on the same page, with the music where it left off.
- **It is a whole system.** One SD-card image: Debian on the Pi, a Rust
  backend, a Flutter UI full screen without a desktop.

## What it does today

| | |
|---|---|
| 🗺️ **Navigation** | offline vector map, routes by [Valhalla](https://github.com/valhalla/valhalla) on the Pi, place search that forgives typos, follow mode |
| 🗣️ **Spoken directions** | turn-by-turn announcements made on the device (sherpa-onnx, Piper voice); the music goes down while a sentence plays (German for now) |
| 🎵 **Music** | your library on the device, import from a USB stick, playlists, queue |
| 📷 **Reversing camera** | analog camera through a USB grabber or a USB webcam, measured delay about 0.06–0.08 s |
| 🔌 **Power supply** | ignition-controlled start and clean shutdown, battery protection, amplifier relay, watchdog ([docs/23](docs/23-power-supply.md)) |
| 🔊 **Sound** | headphone jack or four speakers front and rear through a 5.1 decoder |
| 🌍 **Languages** | UI in 15 languages, on-screen keyboard |

Coming: lane guidance (the backend already delivers the lanes), reverse-gear
detection, OTA updates from GitHub releases. Ideas and plans:
[docs/17](docs/17-ideas-roadmap.md).

## Hardware

- **Raspberry Pi 4** – the only tested and supported target. It also runs on
  a BIGTREETECH Pi2, set up by hand and not tested regularly ([docs/27](docs/27-bigtreetech-pi2.md)).
- 7" touchscreen with 1024 × 600 (e.g. Waveshare 7", [docs/22](docs/22-waveshare-display-1024x600.md)).
- Optional: GPS receiver, the CarNine power-supply board for ignition and
  shutdown, USB grabber or webcam for the reversing camera, DS3231 real-time clock.

## Getting started

1. **Build the image** (see [Build the Raspberry Pi image](#build-the-raspberry-pi-image) below).
2. **Write it to an SD card** – step by step for Windows and Linux in the
   user guide: [Image auf die SD-Karte schreiben](docs/bedienung/image-schreiben.md).
3. **First start, password, Wi-Fi, map data:**
   [Nach der Installation](docs/bedienung/nach-der-installation.md).

No Pi at hand? `./run_wsl.sh` runs backend and frontend on a PC under WSL2,
the same way as on the Pi ([docs/07 §3.4](docs/07-deployment.md)).

## Documentation

- **User guide** (German, with screenshots of every screen): [docs/bedienung](docs/bedienung/README.md)
- **Architecture** (arc42, English): [docs/README.md](docs/README.md) – decisions in [docs/09](docs/09-architecture-decisions.md)
- **Backend** [src/backend](src/backend/README.md) · **Frontend** [src/frontend](src/frontend/README.md) · **API** [src/proto/carnine.proto](src/proto/carnine.proto)

## How it is built

```
src/backend/    Rust: navigation, media, voice, camera, power supply – gRPC server
src/frontend/   Flutter UI, runs full screen under ivi-homescreen on the Pi
src/proto/      the gRPC contract between both
resources/      Debian image (debos), systemd units, tools
docs/           arc42 architecture docs and the user guide
```

Tests and CI on every push. CarNine is also an experiment in AI-assisted
development: much of the code and documentation is written together with an
AI and checked on real devices before it goes in.

## Build

Before building, ensure you have the required build dependencies installed. See the specific README files for each component:

- [Backend Setup](src/backend/README.md#build-dependencies)
- [Frontend Setup](src/frontend/README.md#build-dependencies)

The root build scripts `build_linux.sh` and `build_pi.sh` generate Dart gRPC stubs from the shared schema at `src/proto/carnine.proto`.

To run backend and frontend locally in WSL2, with the frontend under ivi-homescreen as on the Pi, use `./run_wsl.sh` ([docs/07-deployment.md](docs/07-deployment.md) §3.4).

### Build the Raspberry Pi image

The Raspberry Pi image is built with Debos in the `godebos/debos` container. The repository must be mounted from `/mnt/wsl` when using Podman Desktop with WSL, so that the files are available to the Podman machine.

From the repository's `resources` directory, run:

```sh
cd /mnt/wsl/code/carnine2/resources
set -o pipefail
mkdir -p build-logs
podman run --rm -it --device /dev/kvm \
	--mount "type=bind,source=$(pwd),destination=/work" \
	--workdir /work \
	--security-opt label=disable \
	debos ./debos/raspbian.yaml 2>&1 | \
	tee "build-logs/debos-$(date +%Y%m%d-%H%M%S).log"
```

The recipe uses Dracut and includes the Plymouth `pix` theme. Kernel installation is separated from the final Dracut regeneration to avoid repeated initramfs builds in the ARM64 Fakemachine. A complete build produces `resources/raspbian.img.gz` and `resources/raspbian.img.bmap`. The full build log is kept in `resources/build-logs/`.

On the first boot from an SD card larger than the 3 GiB image, the enabled `expand-rootfs.service` first expands the last root partition and reboots once. On the following boot it expands the ext4 filesystem with `resize2fs` and disables itself. This makes the remaining SD-card capacity available to the system.

The generated image can be written to an SD card manually from Windows. Verify the target device carefully before flashing because writing the image replaces all data on the SD card.

## Contributing

Bug reports, ideas and pull requests are welcome – see [CONTRIBUTING.md](CONTRIBUTING.md)
and the [Code of Conduct](CODE_OF_CONDUCT.md). Resources: [sounds](resources/sounds/README.md).

## License

The code is licensed under the [GNU General Public License v3](LICENSE). The name CarNine and its logos are not covered by it; see [Name and Logo](NAME-AND-LOGO.md) for what you may do with them and when to ask.
