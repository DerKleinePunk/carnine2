# 07 Deployment View

## Overview

The CarPC system is deployed on an embedded Linux device (Raspberry Pi 4) with two main service components:
- **Rust backend service** (headless) – handles business logic, media playback, navigation, the power supply link and data operations (CAN is planned)
- **Flutter frontend application** – runs in a windowed GUI environment with touchscreen input

The deployment architecture emphasizes reliability and minimal resource consumption. Updates are Debian packages (`deploy_pi.sh`) or a new SD-card image; over-the-air (OTA) updates are planned.

---

## 7.1 Hardware Environment

### Target Platform
- **Hardware**: Raspberry Pi 4 Model B (4GB or 8GB RAM recommended)
- **Processor**: ARM Cortex-A72 (4x 1.5 GHz cores)
- **Storage**:
  - Root filesystem: microSD card (64 GB minimum; consider industrial‑grade cards for embedded reliability)
  - Optional: SSD via USB 3.0 for extended logging and media cache
- **RAM**: 4GB minimum (8GB recommended to avoid swap pressure)

### Peripherals and Interfaces
- **Display**: Waveshare 7" HDMI LCD (H) touchscreen ([product page](https://www.waveshare.com/7inch-hdmi-lcd-h.htm))
  - Connection: HDMI video + USB for touch input
  - Resolution: 1024×600 (native)
   - Audio: HDMI audio with separate headphone and speaker outputs; each speaker channel has a 2.6 W PA amplifier
  - The panel ships a cloned EDID whose timings the vc4 driver rejects; an
    EDID override keeps it on full KMS at its native mode, see
    [22 – Waveshare 1024x600 Display under Full KMS](22-waveshare-display-1024x600.md)
- **CAN Interface** (planned, no CAN code in the backend yet):
  • Adapter: MCP2515 (SPI) or isolated CAN HAT (e.g. PiCAN 2, Kvaser)
  • Protocol: CAN 2.0B, 500 kbps or 1 Mbps (vehicle‑specific)
  • Connection: SPI bus or USB
  • Prepared, not planned yet: MCP2515 on SPI0 with its interrupt on
    GPIO 25, see [24 – CAN Adapter (MCP2515 on SPI0)](24-can-adapter-mcp2515.md)
- **GPS receiver** (optional, `position_source = "serial"`): any NMEA 0183
  receiver on USB or a UART, see [GPS receiver](#gps-receiver) below
- **Reversing camera** (optional, Kamera page since 0.10.0): an analogue camera
  on a USB grabber with the STK1160 chip, or a USB camera that delivers YUYV
  (uvcvideo); not on a hub that also carries the SSD, see
  [Reversing camera](#reversing-camera) below
- **Vehicle power supply** (optional): the AuPrV1_1 board switches the Pi
  with the ignition and gives it time to shut down; serial line on uart5
  (`/dev/powersupply`), see [23 – Vehicle Power Supply](23-power-supply.md)
- **Case fan and display backlight** (optional): two hardware PWM channels,
  GPIO 18 (pin 12) and GPIO 19 (pin 35). The image always enables both
  (`dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2`), and the backend
  package's udev rule `61-carnine-pwm.rules` gives the `gpio` group the sysfs
  files. The backend drives them with `chip = "pwm"` in `[[controls]]` and
  with `[display.backlight]`; examples in `resources/config/carnine.toml`.
  - Channel 0 is the case fan: a 5 V fan with two wires on JP10 of Michael's
    IO board, whose fan stage switches the 5 V with the signal "Sig" from
    GPIO 18. The duty cycle sets the speed (100 Hz by default, because the
    stage switches slowly); `min_level` is where the fan still turns,
    `kick_ms` gives full duty when it starts from off. It shows up as a
    slider on the Technik page and stops when the backend exits. With
    `boost_on_overheat = true` it runs at 100 % while the CPU overheat
    warning is on and goes back to its own value once it clears (see
    [06 – Runtime View](06-runtime.md)). Mind the
    polarity at JP10: pin 1 is +5 V (red wire), pin 2 ground. The fan has
    reverse polarity protection, so plugged in the wrong way round it simply
    does not turn (seen on carnine-pc on 2026-10-06).
    Tried on carnine-pc with the ebm-papst 405 FH at 100 Hz (2026-10-06),
    in duty cycle: below 30 % its noise is not bearable, at 30 % it starts
    from standstill by itself, and 50 % is fine. Hence `min_level = 30`, no
    `kick_ms` needed, and 50 % duty as the everyday value. The slider's
    levels 1–100 spread over `min_level`..100 % duty (0 is off), so with
    `min_level = 30` the slider shows about 29 for 50 % duty and cannot go
    below the bearable 30 %.
  - Channel 1 is for the backlight of a display modified for it (Waveshare
    7H: a resistor out, its pad to GPIO 19); no test unit has that yet. The
    options set it (SystemService `GetDisplayBrightness` /
    `SetDisplayBrightness`), it never goes below `min_percent` (10 %), and it
    stays on when the backend exits. Until the backend runs, such a display
    stays dark.
- **Power Supply**:
  • USB‑C: 5 V/3 A minimum (ensure quality supply to avoid voltage sag)
  • Optional: battery backup (UPS HAT) for graceful shutdown on power loss
- **Networking**:
  • Ethernet: recommended for reliable initial deployment and updates
  • Wi‑Fi: built‑in 802.11ac for remote diagnostics/OTA updates

### System Integration
- **Cooling**: Active cooling (fan) required for automotive environment; passive heatsink insufficient for sustained operation in vehicle.
  Both test units, carnine-pc and jeep-pi, have a CPU fan fed from header pins 4 (5 V) and 6 (GND). It runs
  whenever the Pi has power; carnine2 does not switch it. The case fan in the enclosure is a second fan
  (ebm-papst 405 FH) on the IO board, speed set over PWM (see the hardware list above). Keep those two pins free for other wiring
  (pin list in [24 – CAN Adapter](24-can-adapter-mcp2515.md#pins-on-the-pi-4)).
- **Mounting**: DIN‑rail or vehicle‑specific enclosure with vibration damping
- **Environmental**: automotive temp range (0 °C–50 °C); mitigate electrical noise with shielded CAN harnesses

---

## 7.2 Software Prerequisites

### Raspberry Pi (Runtime Only)

#### Carnine Runtime User

The backend and the frontend run as the dedicated system user `carnine`. The
user has no interactive login. The image adds it to the groups `audio`,
`render`, `video` and `input`; the backend unit adds `dialout` (serial lines
for GPS and power supply) and the capability `CAP_SYS_TIME` (clock from GPS).
Debos creates the following runtime directories:

- `/etc/carnine`: owned by `root:carnine`, mode `0770`
- `/var/lib/carnine`: owned by `carnine:carnine`, mode `0750`
- `/var/log/carnine`: owned by `carnine:carnine`, mode `0750`. The backend
  writes `backend.log` there, capped at 50 MB: past that it moves to
  `backend.log.1`, replacing an older one, so at most about 100 MB lie on the
  card (#59)

The runtime configuration `/etc/carnine/config.toml` is owned by
`root:carnine` with mode `0660`. The directory permission is required because
the backend persists configuration updates atomically by replacing a temporary
file with `rename`.

`deploy_pi.sh` overwrites `/etc/carnine/config.toml` with
`resources/config/carnine.toml` on every deployment. It stops both services,
installs the configuration **before** the packages (installing them already
starts the backend, which would otherwise read the old file until its next
restart), installs the packages with `--force-confnew` and starts the
services again. Settings that belong to
one device therefore go into drop-ins in `/etc/carnine/config.d/*.toml`, which
no package owns and no deployment touches:

- The backend reads `config.toml` first. It then lays every `*.toml` from
  `config.d` over it in name order, so a later file wins.
- Tables merge key by key. A drop-in can set one value, such as
  `[logging] level = "debug"`, or add a whole section.
- Files with any other extension are ignored, for example `*.dpkg-old` or
  editor backups.
- At startup the log lists each applied file as
  `configuration drop-in applied: ...`.
- With `CARNINE_CONFIG`, drop-ins come from the `.d` directory beside that
  file; `run_wsl.sh`, for example, uses `build/wsl-dev/config.d`.

The map setup of a device is the typical case. The image installs it from
`resources/config/config.d/10-navigation.toml`; the map data itself comes
separately with `./deploy_maps.sh [user@host]`, see
`resources/debos/README.md`:

```toml
# /etc/carnine/config.d/10-navigation.toml
[navigation]
position_source = "replay"
replay_file = "/var/lib/carnine/maps/GPS-Adnan-Tour.txt"
replay_loop = true
# serial_device = "/dev/gps"
# serial_baud = 4800
set_system_clock = true
track_directory = "/var/lib/carnine/tracks"
valhalla_url = "http://127.0.0.1:8002"
map_region = "Hessen"
names_database = "/var/lib/carnine/maps/germany_names.db"
```

(Shortened; the file in the repository also explains each key.)

#### Volume state on test setups

The backend keeps the volume across restarts in the file named by
`[audio] volume_state_path`, by default `/var/lib/carnine/audio-volume`
(`resources/config/carnine.toml`). The directory must exist and be writable
by the backend's user; the image (debos) creates `/var/lib/carnine`, the backend package does not. On a test
setup where it is missing, such as jeep-pi, either create that directory or
point the key at a writable one in a drop-in, for example
`config.d/20-audio.toml`.

Without a saved value the volume starts at 50 % and the log notes the
missing file (#47). Up to 0.8.0 the path was fixed in the code, and a missing
directory brought the volume back at 0 % after every restart.

#### Media database schema 6 (0.9.0)

0.9.0 raises the schema of the media database (`[media] database_path`, by
default `/var/lib/carnine/media.sqlite3`) from 5 to 6. The two new columns
hold each file's size and modification time, so that a rescan skips
unchanged files (#43). The backend migrates the file on its first start;
there is nothing to do by hand.

There is no way back with the migrated file: 0.8.0 refuses it with "database
schema version 6 is newer than supported version 5". Before updating a
device whose library, playlists or resume state matter, stop the services
and keep a copy (the database has no WAL files, the one file is enough):

```bash
sudo systemctl stop carnine-frontend carnine-backend
sudo cp -a /var/lib/carnine/media.sqlite3 /var/lib/carnine/media.sqlite3.0.8.0
```

To go back, stop the services, put the copy back and install 0.8.0.

The first rescan after the update reads every file once, since no row has a
size and time yet; with about 3600 tracks that took around an hour on a Pi 4
before #43. Later rescans only read new and changed files.

#### Media database schema 7 and 8 (0.9.4)

0.9.4 raises the schema twice, and the backend migrates on its first start:

- **7** adds the table `playlist_resume`: every playlist keeps its own place,
  so a single track from the search no longer wipes it (#68). The migration
  takes over the place saved so far.
- **8** adds `ui_state.language`, the display language chosen last (#30).

A device on 0.9.0 to 0.9.3 goes from 6 straight to 8. As with schema 6 there
is no way back: 0.9.3 refuses the file with "database schema version 8 is
newer than supported version 6". Keep a copy before the update, as above:

```bash
sudo systemctl stop carnine-frontend carnine-backend
sudo cp -a /var/lib/carnine/media.sqlite3 /var/lib/carnine/media.sqlite3.0.9.3
```

#### Media database schema 9 and 10 (0.10.0)

- **9** adds the table `camera_settings` for the reversing camera.
- **10** adds its column `width`.

Both only add; nothing existing changes. As before, an older backend refuses
the newer file, so keep a copy before the update as shown above.

#### Where the map data comes from

carnine2 does not build any map data. Tiles, names database, routing tiles
and the demo tour are made with the scripts in the map project
[DerKleinePunk/flutter_local_map](https://github.com/DerKleinePunk/flutter_local_map),
directory `scripts/`. Use the tag that `src/frontend/pubspec.yaml` pins for
`local_map` (currently `local_map-v0.6.0`), so the data matches the library
that draws it. The map project's `README.md` and
`docs/valhalla-offline-setup.md` describe the tools and prerequisites
(Docker, Python packages).

**The built files are in no repository.** Neither carnine2 nor the map
project checks them in (only the small demo tour is in the map project), and
at about 7.5 GB they do not belong there. The working copy is
`~/develop/carnine-maps` on the development machine, besides the devices
themselves; keep a backup of that folder elsewhere, since building it again
takes hours.

| File in `~/develop/carnine-maps` | Made by (map project) | Notes |
|---|---|---|
| `hessen.mbtiles` | `scripts/tilemaker.sh hessen` | tilemaker in a container (docker or podman, `CONTAINER_CMD`), OpenMapTiles schema, `scripts/tilemaker/config-openmaptiles-z17.json` together with the map project's own `scripts/tilemaker/process-openmaptiles.lua` (residential areas by size instead of from z8; the original Lua builds something else); source `germany-latest.osm.pbf` from Geofabrik, cut to the Hessen bounding box. Installed as `map.mbtiles`; the file in use is from 2026-09-23. Names only as `name:latin`, see §8.11 in [08 – Cross-cutting Concepts](08-crosscutting.md). |
| `germany/hessen_names.db` | `scripts/extract_names_to_sqlite.py`, run by `tilemaker.sh` as `<region>_names.db` | Installed as `germany_names.db`, built from `hessen.mbtiles`. FTS5 index for `SearchPlaces` and the `reverse_*` tables for `GetLocationName`. **A names database belongs to its tiles**: positions and each name's area come from them, so build it from the very `.mbtiles` that is installed. Since local_map 0.5.0 (September 2026) it carries the area and grid cells; an older one is still searched, but country-wide, without area and without a location name. It no longer uses WAL: before replacing it on a device, stop the services and delete a leftover `-wal`/`-shm`, which `deploy_maps.sh` does. |
| `valhalla_tiles.tar` | `scripts/valhalla/build_valhalla_from_pbf.sh`, called at the end of `tilemaker.sh` | Routing tiles for the local Valhalla. The current file (5 GB) is from a build on 2026-04-11 (container, an older Valhalla), which Valhalla 3.9.0 reads; on 2026-09-24 only the program was rebuilt. It covers all of Germany: read from its level-2 tile names on 2026-09-25, 895 of 1068 tiles lie in the German bounding box, the rest along ferry lines to Scandinavia and the Baltic, as in a Geofabrik Germany extract. So routes work beyond the Hessen tiles, into areas the map does not draw. |
| `GPS-Adnan-Tour.txt` | `scripts/GpsTest/` | Recorded NMEA tour replayed on the stand. New tours: record a drive, see [Recording drives](#recording-drives). |

The Valhalla program itself is not part of the data: it is built natively on
a Pi with `scripts/valhalla/build_valhalla_on_pi.sh` from the map project
(described in `docs/valhalla-offline-setup.md`, "Stand auf den Test-Pis") and
packaged as `carnine-valhalla.deb` with `resources/valhalla/package-deb.sh`
(the same Valhalla 3.9.0 binaries since the first package; the Debian
revision counts changes to the package around them).
The package brings carnine2's own unit and configuration,
`resources/valhalla/debian/valhalla.service` and `resources/valhalla/valhalla.json`
(listening on `127.0.0.1:8002`). The unit stops Valhalla with SIGINT and a
3 s timeout: after SIGTERM `valhalla_service` lingers about 29 s (measured
on the test Pi, 2026-09-25), longer than the 15 s the vehicle power supply
allows for the shutdown; on SIGINT it ends at once. The package 3.9.0 in the
images 0.13.0 to 0.15.0 lacks this; a device with such an image gets it by
installing the current package with `sudo apt install ./carnine-valhalla_<version>.deb`.

After building new data:

1. Copy the files into `~/develop/carnine-maps` under the names above;
   `deploy_maps.sh` expects exactly these (tiles and names can be other
   files with `CARNINE_MAP_TILES` and `CARNINE_NAMES_DATABASE`).
2. Renew the entry of each changed file in the `SHA256SUMS` of its folder
   (`sha256sum <file>`; `germany/` and `dach/` have their own). The script checks every file against
   the `SHA256SUMS` in its own folder, if that lists it, before it copies
   anything; a file without an entry is copied unchecked and named in the
   output.
3. `./deploy_maps.sh [user@host] [--dach] [--no-restart]`. `CARNINE_MAPS_DIR`
   names another source folder. Before stopping any service it checks the
   free space on the device: the new files plus a copy of the largest, since
   rsync writes the new file beside the old one. It sets `map_region` in
   `/etc/carnine/config.d/10-navigation.toml` to the region deployed
   (`Hessen` or `DACH`) and afterwards restarts `valhalla`, the backend and
   the frontend, unless `--no-restart` is given.
4. For another region, check the map style (`src/frontend/assets/maps/`)
   against the new tiles, see §8.11.

Without the development machine, e.g. for testers, the device installs a map
package by itself: `sudo carnine-install-maps` asks for a Nextcloud share
link (not built into the image), `--dir <folder>` takes a package folder on a
USB stick. `./pack_maps.sh` builds such a package from the same sources as
`deploy_maps.sh`; the format is described in `resources/debos/README.md`, the
steps for the tester in `docs/bedienung/nach-der-installation.md`.

**Our own test devices run with DACH** (Germany, Austria, Switzerland):
`./deploy_maps.sh pi@<device> --dach` takes `dach.mbtiles` (22.1 GB),
`dach_names.db` (2.3 GB) and their own `valhalla_tiles.tar` (6.6 GB) from
`~/develop/carnine-maps/dach` (`CARNINE_DACH_DIR`), a copy of the map
project's build with its `SHA256SUMS`; the demo tour is the same as for
Hessen. Replacing Germany with DACH needs about 29 GB free on the device (7 GB more
data plus the rsync copy of the tiles). jeep-pi and carnine-pc run with
DACH; on carnine-pc (Pi 3, 100 Mbit/s Ethernet) the 31 GB took 74 minutes
on 2026-10-01, at 8 to 10 MB/s.

Before that, **carnine-pc showed all of Germany** from 2026-09-26 to 2026-10-01:
`germany.mbtiles` (17.2 GB) and its `germany_names.db` (1.8 GB, 3.95 million
names) from `~/develop/carnine-maps/germany/`, deployed with
`CARNINE_MAP_TILES` and `CARNINE_NAMES_DATABASE` and `map_region =
"Deutschland"`. The Hessen tiles (2.3 GB) remain the default for testers and
smaller cards, with `germany/hessen_names.db`, as in the package for
`carnine-install-maps`.

#### GPS receiver

The backend takes its position from any receiver that speaks NMEA 0183 (it
uses `RMC` and `GGA`). Nothing in the code is tied to a model; what differs
between receivers is configuration:

1. **Device name.** The backend package installs
   `/lib/udev/rules.d/60-carnine-gps.rules`, which links known receivers to
   `/dev/gps`: u-blox (USB vendor `1546`, `ttyACM`) and the Prolific PL2303
   adapter (`067b:2303`, `ttyUSB`) found in many older mice. For another
   receiver, look up its IDs and add a rule in
   `/etc/udev/rules.d/61-carnine-gps-local.rules`:

   ```sh
   udevadm info --attribute-walk /dev/ttyUSB0 | grep -m2 -E 'idVendor|idProduct'
   echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="xxxx", ATTRS{idProduct}=="yyyy", SYMLINK+="gps"' \
     | sudo tee /etc/udev/rules.d/61-carnine-gps-local.rules
   ```

   Replug the receiver and check `ls -l /dev/gps`. Setting `serial_device` to
   the `/dev/serial/by-id/...` path works as well, without any rule.
2. **Line speed.** `serial_baud` (default 4800, the NMEA standard). USB CDC
   receivers (`ttyACM`) ignore it. On `ttyUSB` and UARTs it must match the
   receiver; to find it, try the common rates until readable sentences appear:

   ```sh
   for b in 4800 9600 38400; do
     sudo stty -F /dev/gps $b raw -echo; echo "== $b"
     sudo timeout 3 cat /dev/gps | head -c 300
   done
   ```

   The backend itself puts the line into raw mode at `serial_baud` when it
   opens it.
3. **Configuration** in a drop-in, e.g. `/etc/carnine/config.d/10-navigation.toml`:

   ```toml
   [navigation]
   position_source = "serial"
   serial_device = "/dev/gps"
   serial_baud = 4800
   ```

   then `sudo systemctl restart carnine-backend`. The log shows
   `GPS serial device opened`; `media_grpc_client ... positions` shows the
   fixes.

The service runs with the supplementary group `dialout`, which owns
`ttyACM*`/`ttyUSB*`. A receiver that is unplugged or not there yet is not an
error: the backend logs it and retries every 3 seconds.

Receivers with old firmware report a date 1024 weeks (19.6 years) too early,
the GPS week-number rollover; the one tested on 2026-09-25 said 2007-02-09.
The backend moves such dates forward and logs
`GPS receiver reports a date before a week-number rollover` once per connection.

Without a receiver, for example in WSL, `serial_device` can point at a plain
file or a named pipe of NMEA lines: the backend reads it as is, without line
setup.

#### Recording drives

With `track_directory` set in `[navigation]` (the device drop-in uses
`/var/lib/carnine/tracks`), the backend can write everything the receiver
sends to one file per drive, named after its GPS start time, e.g.
`2026-09-25T14-57-00Z.nmea`. Such a file is a valid `replay_file`: a real
drive becomes a trade-fair tour, and a problem seen on the road can be
replayed at the desk.

Recording is switched live over gRPC, no restart needed, and the switch is
kept in the media database across restarts and deployments:

```sh
media_grpc_client <endpoint> track-recording on    # or off
media_grpc_client <endpoint> nav-status            # track_recording=on track_file=...
```

`NavigationService.SetTrackRecording` answers `FAILED_PRECONDITION` when no
`track_directory` is configured. Only the serial source writes; with the
replay the switch is kept but nothing is written. A new file starts whenever
recording is switched on and whenever the receiver is reopened (unplugged,
backend restarted). If the directory cannot be written, the backend logs it
once and pauses recording until it is switched again. At 1 Hz a receiver
produces roughly 1 MB per hour; nothing deletes old files.

#### Reversing camera

The Kamera page (the former climate page, `DashboardDestination.camera`; a saved
page `climate` opens it) shows the picture through the `video_grabber`
plugin, pinned in `src/frontend/pubspec.yaml`. `build_pi.sh` builds its
`libvideo_grabber_view.so` against the same shell build as the bundle and
puts it into `/opt/carnine/frontend/lib/`. The page opens the device only
while it is shown and closes it when the page is left.

The capture path follows the device's format:

| Device | Driver | Format | Settings that apply |
|---|---|---|---|
| USB grabber with STK1160 (composite/S-Video) | `stk1160` | UYVY | `norm`, `input` (0–3 composite, 4 S-Video), `width` 360 or 720 |
| USB camera | `uvcvideo` | YUYV, always 640×480 | none of them |
| camera with MJPEG only | `uvcvideo` | — | not supported, the page shows "Kamera gestört" |

At width 720 the STK1160 fills USB 2: on jeep-pi about two thirds of the
frames came incomplete and the page showed about 10 per second; at 360, the
default, all 30 arrive. At 720 on a hub shared with the boot SSD the grabber
stalled the USB controller, so put grabber and camera straight on the Pi.

**Settings.** The backend keeps them (`CameraService`); the frontend reads
the settings in effect when it opens the page. Defaults come from `[camera]`
in the configuration (template in `resources/config/carnine.toml`, best set
in a drop-in such as `/etc/carnine/config.d/30-camera.toml`, then restart the
backend). What `SaveCameraSettings` stores goes into the database and wins
over the configuration, field by field. There is no settings page yet (#79);
until then the example client does it:

```bash
media_grpc_client <endpoint> camera-devices    # /dev/video0 <name> driver=stk1160
media_grpc_client <endpoint> camera-settings   # the settings in effect
media_grpc_client <endpoint> save-camera-settings - pal 2   # '-' keeps a value
```

`camera-devices` lists the first node of each video device and leaves out
the SoC's own nodes (`bcm2835-*`, `rpi-*`), so a Pi without a camera shows
none. `SaveCameraSettings` refuses a device outside `/dev/video*` and
`/dev/v4l/`, an unspecified norm, an input above 15 and any width other than
360 or 720 with `INVALID_ARGUMENT` and stores nothing. A changed
configuration has no effect on a field the database already holds; save that
field again instead.

Switching to the camera with the reverse gear needs a signal from the car
(CAN or a GPIO) and is not done yet.

#### Clock without RTC and network

The Raspberry Pi has no battery-backed clock. At boot systemd-timesyncd
starts from the time it saved at the last shutdown and corrects it over NTP
once a network is there; in the car there usually is none. With
`set_system_clock = true` in `[navigation]` (the device drop-in sets it) and
the serial source, the backend sets the clock from the first valid GPS fix:

- only while the kernel reports the clock as not synchronized, so NTP always
  wins when it is available;
- only when it is more than 2 seconds off, and once per backend start;
- after the week-number rollover correction above.

The log says `system clock set from GPS time` with the old and new time. The
unit grants `CAP_SYS_TIME` for this. Without the capability, for example when
the backend runs in WSL, it logs `could not set the system clock` once and
carries on. The replay source never sets the clock.

The image sets the time zone to `Europe/Berlin`, which is what the clock in
the UI shows; logs stay in UTC. Another zone:
`sudo timedatectl set-timezone <Zone>`, then restart `carnine-frontend`.

A settings change through `ConfigService` rewrites `config.toml` with the
merged values. The drop-ins are applied after it on the next start and still
win.

#### Audio output

The backend has no audio device setting. It plays through cpal's
`default_output_device()` (`src/backend/src/cpal_audio_engine.rs`), which on
the Pi is ALSA's `default` device, and sets the volume with
`amixer -M -c 0 set PCM` (`src/backend/src/audio_volume.rs`). Both therefore
follow **ALSA card 0**. The Pi 4 has three cards (`config.txt` from pi-gen
keeps `dtparam=audio=on`):

| ALSA name | Output |
|---|---|
| `vc4hdmi0` | HDMI0, the port next to USB-C, where the panel is |
| `vc4hdmi1` | HDMI1 |
| `Headphones` | 3.5 mm jack (`snd_bcm2835`) |

Without a setting, which one becomes card 0 depends on the order the modules
load. On carnine-pc HDMI0 came first because `vc4` is in the initramfs (for
the EDID override and Plymouth) and `snd_bcm2835` is not; on jeep-pi the jack
came first. **The image therefore fixes HDMI0 as card 0** (step "Choose ALSA
card 0" in `resources/debos/raspbian.yaml`, `carnine-audio-output.sh`)
by reserving the card slots per driver in the ALSA core module `snd`:

```
# /etc/modprobe.d/carnine-audio.conf
options snd slots=vc4,vc4,snd_bcm2835
```

The two vc4 cards take 0 and 1, the jack stays available as card 2. Tried on
jeep-pi, where the jack loads first: the line moved HDMI0 from card 1 to card
0. Check after a reboot:

```bash
cat /proc/asound/cards                  # 0 [vc4hdmi0 ], 1 [vc4hdmi1 ], 2 [Headphones]
cat /sys/module/snd/parameters/slots    # vc4,vc4,snd_bcm2835,...
```

Where `snd` already loads from the initramfs together with `vc4` (carnine-pc
and the image), the file must be in the initramfs too, since dracut runs with
`hostonly="no"` and does not take `/etc/modprobe.d` along by itself. The
image step therefore also writes

```
# /etc/dracut.conf.d/carnine-audio.conf
install_items+=" /etc/modprobe.d/carnine-audio.conf "
```

and the later `dracut --regenerate-all` builds it in. Check with
`sudo lsinitrd -f etc/modprobe.d/carnine-audio.conf /boot/initrd.img-$(uname -r)`.
On jeep-pi the file worked without this.

On a device set up before this step, write both files by hand, keep a copy
of the old initramfs, rebuild it for the running kernel and reboot:

```bash
sudo cp /boot/initrd.img-$(uname -r) /root/initrd.img-$(uname -r).bak
sudo dracut --force /boot/initrd.img-$(uname -r) $(uname -r)
sudo systemctl reboot
```

dracut copies the result to `/boot/firmware/initramfs8` itself, the file the
firmware loads.
On carnine-pc this gave `vc4,vc4,snd_bcm2835` in
`/sys/module/snd/parameters/slots` and HDMI0 as card 0.
`options snd_bcm2835 index=2` does **not** work: the driver has no `index`
parameter (only `enable_hdmi`, `enable_headphones`, `force_bulk`,
`num_channels`), and modprobe ignores the line without a word.

**Using the jack instead** (a panel without speakers, or a car without
speakers on HDMI): build the image with `-t audio_output:jack` (#64), or on a
running device swap the order in the same file,

```
options snd slots=snd_bcm2835,vc4,vc4
```

so the jack becomes card 0, and rebuild the initramfs as above. Tried on
carnine-pc, where `vc4` loads from the initramfs: 0 Headphones,
1 vc4hdmi0, 2 vc4hdmi1, the backend played on the jack and used amixer.
Again on 29.09.2026 on the Pi 3 by the steps in the user guide: 0 Headphones,
1 vc4hdmi, `audio volume restored percent=65` (-33.24 dB on the jack), playback
ran on card 0; dracut takes one to two minutes there.
Two things differ from HDMI:

- The jack's `PCM` is a mono hardware control with another range
  (-102.39 … +4 dB against -51 … 0 dB on HDMI). Without `-M` amixer mapped
  percent linearly onto that raw range, and the same percentage was far
  quieter on the jack (65 %: -33.24 dB against -17.80 dB). Since #65 the
  backend uses `-M`, which follows the dB curve, so the outputs sound alike.
  Measured on the Pi 3: 42 % is -18.00 dB on HDMI and -18.61 dB on the jack,
  50 % is -14.60 dB on HDMI, 25 % is -32.12 dB on the jack.
- The stored volume applies to both outputs, so after switching the backend
  starts at the same percentage.

The state file holds `42 mapped` since #65. A bare number from an older
version is on the old linear scale: at the next start the backend sets it
the old way once, reads the mapped percent back and keeps that, so the level
does not change with the update (on carnine-pc 65 became 42, -17.80 dB then
-18.00 dB).

Choosing the output in the UI is planned for later
([#48](https://github.com/DerKleinePunk/carnine2/issues/48)).

The `PCM` control on an HDMI card does not come from the driver, which has
no mixer: `/usr/share/alsa/cards/vc4-hdmi.conf` (package `libasound2-data`)
builds the card's `default` device as plug → softvol `PCM` → IEC958, since
vc4 only accepts `IEC958_SUBFRAME_LE` (see
[20 – Media Backend Plan](20-media-backend-plan.md#der-plopp-kommt-von-der-hdmi-senke-nicht-aus-dem-backend)).
No own `asound.conf` is needed for it. Two catches:

- The softvol control only exists once the device has been opened. At boot
  `alsa-restore` creates it from `/var/lib/alsa/asound.state`, where the
  entry "PCM Playback Volume" has to be. The image ships such a file
  (`resources/debos/alsa/asound.state`, 50 %), and the backend starts after
  `alsa-restore`. Without it the backend's first open creates the control,
  and the kernel lets only the handle that created it write it while softvol
  keeps it open: every `amixer set` then fails with "Invalid command!"
  (EPERM) and the volume stays at 100 % for that whole session (#61).
- The backend decides **once at startup** whether it can use amixer. If
  `PCM` is missing at that moment, the volume slider has no effect until the
  backend is restarted. Choosing the device in the UI (#48) would have to
  deal with this.

On a device that has never played through HDMI, create and store the control
once:

```bash
speaker-test -D default -c 2 -t sine -l 1
sudo alsactl store
amixer -c 0 get PCM                         # the control is there
sudo systemctl restart carnine-backend
```

Then check in the UI that music plays on the panel and that the volume
slider changes `amixer -c 0 get PCM`.

#### Spoken turn announcements

The package `carnine-voice` (installed by the image recipe) brings
sherpa-onnx 1.13.8 and the German voices `thorsten-medium` (default) and
`thorsten-low`; the backend loads them at run time and runs on silently
without them. `[voice]` picks the voice, the core (default 3) and the levels;
switch, loudness and the music's level set over gRPC are saved in the media
database (schema 13) and win over the configuration. Details, the flow and the
measurements: [26 – Spoken Turn Announcements](26-turn-announcements.md).

#### Operating System
- **OS**: Debian trixie (arm64) with the Raspberry Pi kernel and firmware from
  archive.raspberrypi.com, built as an SD-card image with debos
  (`resources/debos/raspbian.yaml`, see 3.1)
  • `systemd` for service management, `systemd-networkd` for the network
    (DHCP on every wired and wireless interface). Wi-Fi is off by default;
    since the release after 0.9.5 `sudo carnine-wlan` unblocks it, scans,
    and stores the network for `wpa_supplicant@wlan0`
    (`/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`, root only); `--off` and
    `--on` switch it off and back on across reboots

#### Runtime Dependencies (on Pi)
The Debian packages pull in everything they need; the image installs them:
- **Backend** (`src/backend/Cargo.toml`, `[package.metadata.deb]`):
  `ffmpeg`, `libasound2t64`, `alsa-utils`, `udisks2`
- **Frontend** (`src/frontend/debian/control`): `libdrm2`, `libgbm1`,
  `libegl1`, `libgles2`, `libinput10`, `libxkbcommon0`, `libudev1`,
  `libsystemd0`, `libseat1`, `libdisplay-info2`, `seatd`, `libatomic1`,
  `fontconfig`, `fonts-liberation`. The frontend unit wants `seatd.service`;
  `drm-kms-egl` hangs silently on `libseat` without it
- **Map and routing**: `carnine-valhalla.deb` (`resources/valhalla/`)

### Workstation (x86_64 Linux)

#### Build Dependencies (Workstation Only)

**Rust Backend Cross‑Compilation**
- Rust toolchain with `aarch64-unknown-linux-gnu` target (installed via `rustup`)
- `cargo-deb` (`cargo install cargo-deb`)
- `cargo-about` (`cargo install cargo-about --locked --features cli`);
  `build_pi.sh` stops without it
- Cross linker `aarch64-linux-gnu-gcc` (`gcc-aarch64-linux-gnu`)
- An arm64 sysroot with the ALSA development files at
  `build/sysroots/carnine-pi-arm64` (override `CARNINE_ARM64_SYSROOT`);
  `build_pi.sh` stops if `alsa.pc` is missing there
- `protobuf-compiler` 3.20+
- Standard build tools (gcc, make, pkg‑config), `rsync`, `dpkg-deb`

**Flutter Frontend Cross‑Compilation**
- [`emb_cli`](https://github.com/toyota-connected/emb_cli) **0.4.1** from
  pub.dev (8 Oct 2026), the version release builds use:

  ```
  dart install emb_cli@0.4.1
  emb --version          # 0.4.1
  ```

  Older releases do not work: 0.3.6 and 0.3.7 reject the code assets emb
  stages itself (`libsqlite3.so`,
  [emb_cli#255](https://github.com/toyota-connected/emb_cli/issues/255)),
  and 0.4.0 finds no board files with its default source
  ([emb_cli#261](https://github.com/toyota-connected/emb_cli/issues/261)).
  After a change of the emb version sync the boards as 3.3 describes; if the
  build then reports a lock drift, build once with `CARNINE_EMB_UPDATE_LOCK=1`
  (see 3.3).

  It worked if the build finishes and the bundle's `lib/` holds
  `libapp.so`, `libflutter_engine.so`, `libihs_shared.so.1`,
  `libsqlite3.so` (ARM aarch64) and `libvideo_grabber_view.so`.
- An emb workspace with the Flutter SDK emb pins and an
  [ivi-homescreen](https://github.com/toyota-connected/ivi-homescreen) checkout
  (see 3.3); the Flutter SDK on `PATH` is not used for Pi builds (ADR-020)
- `protoc-gen-dart` for the Dart gRPC code (`dart pub global activate protoc_plugin`)
- Standard build tools

#### System Packages (apt) on Workstation

```bash
sudo apt-get update && sudo apt-get install -y \
  build-essential \
  pkg-config \
  gcc-aarch64-linux-gnu \
  protobuf-compiler \
  rsync \
  git \
  curl
```

#### Development & Debugging Tools
- **SSH client** (for deploying binaries to Pi)
- **gdb‑multiarch** or **lldb** (remote debugging on Pi)
- **IDE with Rust/Dart support**:
  - VS Code + Rust Analyzer + Dart extensions
  - JetBrains IntelliJ / CLion / Android Studio
- **Remote debugging setup**: IDE extensions for remote debugging over SSH

---

## 7.3 Installation Steps

### 3.1 Operating System Setup

The device runs a complete SD-card image, built with debos from
`resources/debos/raspbian.yaml` (Debian trixie plus the Raspberry Pi archive).
It already contains the Carnine packages, the `carnine` user, the runtime
directories and the configuration; there is no manual OS setup with
`raspi-config`. `resources/debos/README.md` describes the build (podman with
`godebos/debos`) and its switches:

- `-t display:waveshare-1024x600`: Waveshare panel with its EDID (docs/22);
  default `auto`
- `-t audio_output:jack`: headphone jack as card 0 instead of HDMI (see
  [Audio output](#audio-output))
- `-t power_supply:auprv1`: car power supply with `gpio-poweroff` (docs/23)
- `-t target_hostname:<name>`, `-t "ssh_public_key:…"`; on the device the
  name changes with `sudo carnine-rename <name>` (since the release after
  0.9.5)
- `-t rootpassword:<password>`: password of the user `pi`, default
  `raspberry`. SSH accepts it; since the release after 0.9.5 every
  interactive login warns while it is still the default
  (`carnine-password-check`, `/etc/profile.d/carnine-password.sh`). Changing
  it and the hostname on the device: `docs/bedienung/nach-der-installation.md`

The result is `raspbian.img.gz` with the block map `raspbian.img.bmap` and
the build log below `build-logs/`. Write it to the card with `bmaptool copy`,
or from Windows with an imaging tool, after checking which card is selected.

CAN is not set up in the image yet: there is no CAN code in the backend, and
the adapter depends on the vehicle.

### 3.2 Build Backend (Rust)

`./build_pi.sh` builds the backend together with the frontend on the
workstation. For the backend it

1. checks the arm64 sysroot (`CARNINE_ARM64_SYSROOT`, default
   `build/sysroots/carnine-pi-arm64`),
2. cross-compiles with `aarch64-linux-gnu-gcc` as linker and `PKG_CONFIG_*`
   pointing into the sysroot, with `CARNINE_VERSION` and `CARNINE_BUILD_ID`
   from `VERSION` and the commit,
3. writes the licence texts of every crate in the binary with
   `cargo about` (`src/backend/about.toml`, `about.hbs`) into
   `target/third-party-licenses.txt`; a crate under a licence that
   `about.toml` does not accept stops the build,
4. packages that binary with `cargo deb --no-build --target
   aarch64-unknown-linux-gnu` and stages the result as
   `resources/debos/carnine-backend.deb`; the licence texts go to
   `/usr/share/doc/carnine-backend/third-party-licenses.txt`.

With `cargo-auditable` installed (`cargo install cargo-auditable --locked`)
step 2 runs `cargo auditable build`, so the binary carries its dependency
list; `--no-build` keeps cargo-deb from building it again without that list. After the build,
`build_pi.sh` writes an SBOM (CycloneDX and SPDX) and a grype CVE report next
to each package in `resources/debos/` (`<package>.cdx.json`, `.spdx.json`,
`.grype.txt`, #41): the backend's from the unpacked package, the frontend's
from the `pubspec.lock` it was built with. ivi-homescreen gets its own files
next to them (`carnine-frontend-ivi-homescreen.cdx.json`, `.openvex.json`,
`.grype.txt`): it vendors its C++ libraries as git submodules without package
metadata, which syft cannot see, so `resources/tools/sbom/gen_sbom.py` reads
the pinned submodules from the checkout in the emb workspace and writes them
as CycloneDX, with a CPE for the ones NVD lists (rapidjson, fmt), plus an
OpenVEX document that grype reads with `--vex`. A VEX entry marks a CVE
`not_affected` only if the build checks that the fixing commit is an ancestor
of the pinned submodule (CVE-2024-38517 in rapidjson, fixed by 8269bc2b). If
that check fails (the pin moved, or the submodule lacks the history), the
script stops and `build_pi.sh` warns, writes no ivi-homescreen report and
builds on. A CVE without an upstream fix to check, such as CVE-2024-39684,
stays in the report. The script follows ivi-homescreen #746, which our pin
predates. Not covered is the Flutter engine. Accepted findings are listed with
their reason in `.grype.yaml`. These are reports only; a finding never stops
the build. Without `cargo-auditable`, `syft` or `grype` the build goes on with
a warning (`CARNINE_SYFT`/`CARNINE_GRYPE` name other binaries). The image gets
its own report: the recipe keeps the package list in
`<image>.<audio_output>.sbom-input/` (one folder per variant, `.auprv1`
added with the power supply), and `resources/debos/image-sbom.sh` turns it into an
SBOM and a report on the host (`resources/debos/README.md`).

**Licences (#123).** Each of our packages carries the licences of what it
ships, under `/usr/share/doc/<package>/`: the backend the crate licences
above; the frontend a `copyright` that names its parts and points to
`opt/carnine/frontend/data/flutter_assets/NOTICES.Z` (Flutter collects the
licences of the engine and every Dart package there), plus
`ivi-homescreen-licenses.txt`, which `gen_sbom.py --licenses-output` writes
from a fixed list of files per submodule (a delivered submodule without an
entry, or a missing file, stops the build); Valhalla a `copyright` for
Valhalla 3.9.0, prime_server 0.13.1 and the third_party parts compiled in.
The image recipe adds `/usr/share/doc/carnine/SOURCE-OFFER.txt`
(from `resources/debos/source-offer.txt`, with the version filled in): where
the sources are, and a written offer of the GPL and LGPL sources for three
years on request to software@carnine.de. Next to it,
`source-packages.txt` lists every source package of the image with its
version, read from the image's dpkg database after the last install.

`./deploy_pi.sh` installs the staged packages on a device, and the debos
recipe takes them into a new image.

### 3.3 Build Frontend (Flutter via emb_cli / ivi-homescreen)

The frontend runs under ivi-homescreen with the `drm-kms-egl` backend and is
cross-built with `emb_cli` (ADR-020). `build_pi.sh` does all of the following;
the steps are listed for provisioning a new build host.

1. **Provision the emb workspace** (once per host, default
   `~/develop/emb-workspace`, override with `CARNINE_EMB_WORKSPACE`):

   ```bash
   W=~/develop/emb-workspace
   mkdir -p $W/app
   git clone --recursive https://github.com/toyota-connected/ivi-homescreen.git $W/app/ivi-homescreen
   emb flutter -w $W --flutter-version 3.47.5
   emb boards sync
   cd $W/app/ivi-homescreen
   git switch -c carnine 92c2353a
   emb cross . --target rpi4-trixie --backend drm-kms-egl -D DISABLE_PLUGINS=ON --fetch-only -w $W
   ```

   The checkout is pinned to 92c2353a on `v3.0`, without local patches. The
   display froze for good under load on 2026-09-26 (panning the Germany map;
   the app kept running, a VT switch thawed it): page-flip state was published
   after a nonblocking commit (ivi-homescreen #649). Upstream fixed it in #652,
   #654, #655 and #658 and added #659, which recovers a display whose flip
   event got lost. Both Pis ran 522e1d4b (#658, before #659) for about four
   hours on 2026-09-27 under synthetic pan/zoom without a freeze. A pin older
   than 15ab00f3 brings the freeze back.

   `emb boards sync` fetches the boards from emb's default source
   `emb-public`, matching the emb version (`emb boards list` shows
   `installed (emb-public)` with `rpi4-trixie`). A host that still carries the
   workaround for emb 0.4.0
   ([emb_cli#261](https://github.com/toyota-connected/emb_cli/issues/261)), a
   source `emb-boards` in `~/.config/emb/boards.yaml`, drops it with
   `emb boards remove emb-boards` and runs `emb boards sync` again; emb then
   restores `emb-public` by itself.

   The fetch downloads the Arm GNU toolchain and a RaspiOS trixie sysroot
   (several GB, cached under `~/.cache/emb`). The build also compiles a
   host-native `wayland-cxx-scanner` and needs `sudo apt install libpugixml-dev`
   on the workstation.

   After a change of the emb version, the first build can stop with
   `emb.lock drift … re-run with --update-lock` (0.4.0 to 0.4.1 did not;
   `emb.lock` still names 0.4.0). Then build once with
   `CARNINE_EMB_UPDATE_LOCK=1 ./build_pi.sh`: it adds `--update-lock` to its
   own emb call, so the lock matches exactly that call. Then build normally.
   The `--fetch-only` command above with `--update-lock` is not enough; it
   lacks `--app` and the other build options, and the next build reports the
   drift again.

2. **Build** with `./build_pi.sh`. It copies `src/frontend` to
   `build/emb-app/carnine_frontend` (emb writes into the app directory),
   stamps the version there, and runs
   `emb cross . --target rpi4-trixie --build --backend drm-kms-egl --app <copy> --mode release -D DISABLE_PLUGINS=ON`.
   Never judge performance from a debug build: `executor_lib` and other
   isolate pools fall back to the main isolate in debug.

3. **Install** the resulting `resources/debos/carnine-frontend.deb` with
   `./deploy_pi.sh`. The package installs the bundle to
   `/opt/carnine/frontend`; `/usr/bin/carnine-frontend` starts
   `homescreen -b /opt/carnine/frontend -f -c` (`-c`: touch only, no
   pointer). `CARNINE_HOMESCREEN_ARGS` in a systemd drop-in adds further
   embedder flags without a rebuild, for example `-d --drm-pipeline-depth 2`.

4. **Stop it by hand** with `pkill -x homescreen`. `pkill -f homescreen`
   also matches the SSH command line that runs it.

### 3.4 Run Locally in WSL2 (ivi-homescreen on WSLg)

`./run_wsl.sh` runs backend and frontend on the workstation, with the frontend
under ivi-homescreen as on the Pi rather than in the GTK runner of
`flutter run -d linux`. It uses the same emb workspace as 3.3 but builds
natively for x86_64 with the `wayland-egl` backend, which WSLg's compositor
provides. The Arm toolchain and sysroot are not needed for this.

```bash
./run_wsl.sh             # build what changed, then start both
./run_wsl.sh --no-build  # start the last build again
```

The window opens at 1024x600, the panel's size. Closing it or Ctrl+C in the
terminal stops the frontend, the backend and the Valhalla tunnel together.

What the script does:

1. Generates the protobuf stubs, copies `src/frontend` to
   `build/emb-app-local/carnine_frontend` and runs
   `emb cross . --build --backend wayland-egl --app <copy> --mode debug -D DISABLE_PLUGINS=ON`
   in the ivi-homescreen checkout. Without `--target`, emb builds for the host.
   The first build takes about a minute.
2. Builds the backend with `cargo build` and writes a configuration to
   `build/wsl-dev/config.toml`. The script regenerates it on every start, so
   change the script instead of the file. The database, covers, logs and
   socket all live in `build/wsl-dev/`. The media folder gets the repository
   test MP3 if it is empty.
3. Starts the backend with that configuration. It drops `CARNINE_SOCKET_PATH`
   and `CARNINE_TCP_ADDRESS` from the environment first, because a dev shell
   that exports them would otherwise take precedence over the configuration.
4. Tunnels the Pi's Valhalla to `127.0.0.1:8002`, because there is no local
   routing service. Without the Pi, the map still renders but shows no route.
5. Starts `homescreen -b <bundle> -w 1024 --height 600` with
   `CARNINE_EMBEDDED=1`, the socket from step 2 and the map tiles.

Overrides, each an environment variable:

| Variable | Default | Purpose |
|---|---|---|
| `CARNINE_EMB_WORKSPACE` | `~/develop/emb-workspace` | emb workspace from 3.3 |
| `CARNINE_FRONTEND_BUILD_MODE` | `debug` | `debug`, `profile` or `release` |
| `CARNINE_MAPS_DIR` | `~/develop/carnine-maps` | Folder with `hessen.mbtiles` and `germany_names.db` |
| `CARNINE_MAP_TILES`, `CARNINE_NAMES_DATABASE` | from `CARNINE_MAPS_DIR` | Individual map files |
| `CARNINE_REPLAY_FILE` | the tour shipped with the resolved `local_map` revision | NMEA replay for the own position |
| `CARNINE_WSL_MEDIA` | `build/wsl-dev/media` | Music folder; for example `/mnt/c/Users/<user>/Music` |
| `CARNINE_VALHALLA_TUNNEL` | `pi@192.168.2.51` | SSH target for the Valhalla tunnel; empty disables it |

Known differences from the Pi:

- WSLg has no GPU driver for EGL, so Mesa falls back to software rendering.
  The `libEGL warning` and `ZINK: failed to choose pdev` lines at startup are
  expected. Frame rates therefore say nothing about the Pi, and neither does a
  debug build (see 3.3).
- There is no UDisks2 in WSL, so the backend logs that the storage listener
  stopped and USB import cannot be tested here.
- Audio goes through cpal's default ALSA device, which WSLg routes to
  PulseAudio. The volume backend reports `pactl`.
- The frontend logs `NOTIFY_SOCKET is not set` because systemd does not start
  it here. This is harmless.

---

## 7.4 Backend Connectivity and Debugging

The installed backend's primary and only production transport is a Unix
domain socket at `/run/carnine/carnine.sock` (ADR-002), created on start by
systemd's `RuntimeDirectory=carnine` and owned by the `carnine` user with
mode `0600`. Frontend and backend run as the same user on the same machine,
so this needs no separate auth layer - only filesystem permissions - and,
unlike a TCP port, is not reachable over the network even by mistake. The
image recipe must not add a network-facing `tcp_address` to
`/etc/carnine/config.toml`.

`0600` is the default, not a hard-coded value: `server.socket_mode` (or the
`CARNINE_SOCKET_MODE` environment variable) accepts an octal mode, and modes
granting world access are rejected. Widening it to `0660` lets every member of
the `carnine` group reach the service — convenient on a test device where a
second login needs to run a gRPC client, and a deliberate weakening anywhere
else. The backend logs a warning at startup whenever the mode is not `0600`.
Both the socket and the `RuntimeDirectory=carnine` directory have to be
widened; the directory's `0700` alone already blocks a second account.

On the test device this is set through a systemd drop-in rather than
`/etc/carnine/config.toml`, because `deploy_pi.sh` overwrites that file from
the repository on every deployment:

```ini
# /etc/systemd/system/carnine-backend.service.d/testing-group-access.conf
[Service]
Environment=CARNINE_SOCKET_MODE=0660
RuntimeDirectoryMode=0750
```

plus `sudo usermod -aG carnine pi`. The generated image must not ship either.

Verify the service directly on the Pi:

```bash
sudo systemctl is-active carnine-backend.service
ls -l /run/carnine/carnine.sock
sudo -u carnine grpcurl -plaintext -import-path . -proto carnine.proto \
  -unix /run/carnine/carnine.sock carnine.MediaService/GetServiceVersion
```

(`grpcurl` supports Unix sockets via `-unix`; install it separately, it does
not ship with the image. The backend offers no gRPC reflection, so grpcurl
needs `src/proto/carnine.proto`, copied next to it. `GetServiceVersion`
exists on `MediaService`, `AudioService` and `NavigationService`.)

For debugging from a development machine against a Pi in the field, forward
the remote Unix socket to a local one over SSH instead of exposing the
backend on the network - OpenSSH (6.7+) forwards Unix sockets the same way
it forwards TCP ports:

```bash
ssh -N -L /tmp/carnine-debug.sock:/run/carnine/carnine.sock pi@<pi-ip>
```

In a second terminal, point any Unix-socket-aware gRPC client at the local
end of the tunnel, e.g.:

```bash
grpcurl -plaintext -import-path src/proto -proto carnine.proto \
  -unix /tmp/carnine-debug.sock carnine.MediaService/GetServiceVersion
```

### Local development (WSL2/desktop): TCP loopback fallback

`media_grpc_client` (`cargo run --example media_grpc_client`) only speaks
TCP, so local smoke-testing still needs the optional fallback transport from
ADR-002. Enable it for a `cargo run` session with:

```bash
CARNINE_SOCKET_PATH=/tmp/carnine-dev.sock \
CARNINE_TCP_ADDRESS=127.0.0.1:50051 \
cargo run
```

(`CARNINE_SOCKET_PATH` is also required in this setup: `/run/carnine` is
root-owned tmpfs and a plain dev user cannot create it, unlike the installed
service which gets it from `RuntimeDirectory=carnine`.) Then:

```bash
cargo run --example media_grpc_client -- http://127.0.0.1:50051 version
```

Use `127.0.0.1`, not `[::1]`, for this fallback: WSL2's localhost port
forwarding between Windows and the WSL2 VM has historically been unreliable
for IPv6-only loopback listeners, which is what caused the frontend's
original "not connected" symptom when both were mismatched. This TCP
fallback is also the path for a Flutter debug build running as a native
Windows process (VS Code's default "Windows" run target) against a backend
inside WSL2, since the two do not share a kernel/socket namespace and
Unix domain sockets cannot cross it - only Flutter runs from *within* WSL2
(e.g. `flutter run -d linux`) can use the Unix socket directly, matching the
production transport on the Pi.

Never enable `tcp_address` (or `CARNINE_TCP_ADDRESS`) in the versioned
configuration (`resources/config/carnine.toml`) or the generated image - it
must stay unset there, as a purely local, opt-in development convenience.

---

## 7.5 Network Exposure and Firewall Policy

Remote control must be reachable only from the local network (LAN). Public internet exposure is not allowed.

### Inbound Policy (default deny)
- Block all unsolicited inbound traffic from WAN interfaces.
- Allow only explicit LAN inbound rules required for operations.
- Prefer binding control endpoints to LAN interface addresses, not `0.0.0.0`.

### Example `nftables` baseline

```bash
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
   chain input {
      type filter hook input priority 0;
      policy drop;

      iif "lo" accept
      ct state established,related accept

      # Optional: SSH from LAN only
      ip saddr 192.168.0.0/16 tcp dport 22 accept

      # Optional: Remote control API from LAN only
      ip saddr 192.168.0.0/16 tcp dport 50051 accept

      # ICMP for diagnostics
      ip protocol icmp accept
      ip6 nexthdr ipv6-icmp accept
   }

   chain forward {
      type filter hook forward priority 0;
      policy drop;
   }

   chain output {
      type filter hook output priority 0;
      policy accept;
   }
}
EOF

sudo systemctl enable nftables
sudo systemctl restart nftables
```

### Operational Notes
- If remote control is not yet implemented, keep the remote control port closed.
- If remote control is enabled, require TLS and application-level authentication.
- Keep SSH disabled by default unless required for maintenance windows.
