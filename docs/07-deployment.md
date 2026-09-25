# 07 Deployment View

## Overview

The CarPC system is deployed on an embedded Linux device (Raspberry Pi 4) with two main service components:
- **Rust backend service** (headless) – handles business logic, CAN communication, and data operations
- **Flutter frontend application** – runs in a windowed GUI environment with touchscreen input

The deployment architecture emphasizes reliability, minimal resource consumption, and support for over-the-air (OTA) updates.

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
- **CAN Interface**:
  • Adapter: MCP2515 (SPI) or isolated CAN HAT (e.g. PiCAN 2, Kvaser)
  • Protocol: CAN 2.0B, 500 kbps or 1 Mbps (vehicle‑specific)
  • Connection: SPI bus or USB
- **GPS receiver** (optional, `position_source = "serial"`): any NMEA 0183
  receiver on USB or a UART, see [GPS receiver](#gps-receiver) below
- **Vehicle power supply** (optional): the AuPrV1_1 board switches the Pi
  with the ignition and gives it time to shut down; serial line on uart5
  (`/dev/powersupply`), see [23 – Vehicle Power Supply](23-power-supply.md)
- **Power Supply**:
  • USB‑C: 5 V/3 A minimum (ensure quality supply to avoid voltage sag)
  • Optional: battery backup (UPS HAT) for graceful shutdown on power loss
- **Networking**:
  • Ethernet: recommended for reliable initial deployment and updates
  • Wi‑Fi: built‑in 802.11ac for remote diagnostics/OTA updates

### System Integration
- **Cooling**: Active cooling (fan) required for automotive environment; passive heatsink insufficient for sustained operation in vehicle
- **Mounting**: DIN‑rail or vehicle‑specific enclosure with vibration damping
- **Environmental**: automotive temp range (0 °C–50 °C); mitigate electrical noise with shielded CAN harnesses

---

## 7.2 Software Prerequisites

### Raspberry Pi (Runtime Only)

#### Carnine Runtime User

The backend runs as the dedicated system user `carnine`. The user has no
interactive login and is a member of the `audio` group. Debos creates the
following runtime directories:

- `/etc/carnine`: owned by `root:carnine`, mode `0770`
- `/var/lib/carnine`: owned by `carnine:carnine`, mode `0750`
- `/var/log/carnine`: owned by `carnine:carnine`, mode `0750`

The runtime configuration `/etc/carnine/config.toml` is owned by
`root:carnine` with mode `0660`. The directory permission is required because
the backend persists configuration updates atomically by replacing a temporary
file with `rename`.

`deploy_pi.sh` overwrites `/etc/carnine/config.toml` with
`resources/config/carnine.toml` on every deployment. Settings that belong to
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
valhalla_url = "http://127.0.0.1:8002"
map_region = "hessen"
names_database = "/var/lib/carnine/maps/germany_names.db"
```

#### Where the map data comes from

carnine2 does not build any map data. Tiles, names database, routing tiles
and the demo tour are made with the scripts in the map project
[DerKleinePunk/flutter_local_map](https://github.com/DerKleinePunk/flutter_local_map),
directory `scripts/`. Use the tag that `src/frontend/pubspec.yaml` pins for
`local_map` (currently `local_map-v0.3.0`), so the data matches the library
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
| `germany_names.db` | `scripts/extract_names_to_sqlite.py`, run by `tilemaker.sh` as `<region>_names.db` | FTS5 index for `SearchPlaces`. As the name says, the file in use comes from the full-Germany run (`./tilemaker.sh` without a region), so search covers more than the tiles show. |
| `valhalla_tiles.tar` | `scripts/valhalla/build_valhalla_from_pbf.sh`, called at the end of `tilemaker.sh` | Routing tiles for the local Valhalla. The current file (5 GB) is from a build on 2026-04-11 (container, an older Valhalla), which Valhalla 3.9.0 reads; on 2026-09-24 only the program was rebuilt. It covers all of Germany: read from its level-2 tile names on 2026-09-25, 895 of 1068 tiles lie in the German bounding box, the rest along ferry lines to Scandinavia and the Baltic, as in a Geofabrik Germany extract. So routes work beyond the Hessen tiles, into areas the map does not draw. |
| `GPS-Adnan-Tour.txt` | `scripts/GpsTest/` | Recorded NMEA tour replayed on the stand. New tours: record a drive, see [Recording drives](#recording-drives). |

The Valhalla program itself is not part of the data: it is built natively on
a Pi with `scripts/valhalla/build_valhalla_on_pi.sh` from the map project
(unit `scripts/valhalla/valhalla.service` beside it, described in
`docs/valhalla-offline-setup.md`, "Stand auf den Test-Pis") and packaged as `carnine-valhalla.deb` with
`resources/valhalla/package-deb.sh`.

After building new data:

1. Copy the files into `~/develop/carnine-maps` under the names above;
   `deploy_maps.sh` expects exactly these (the tiles can be another file with
   `CARNINE_MAP_TILES`).
2. Renew the checksums there:
   `sha256sum hessen.mbtiles germany_names.db valhalla_tiles.tar GPS-Adnan-Tour.txt > SHA256SUMS`.
3. `./deploy_maps.sh [user@host]`.
4. For another region, also set `map_region` in the navigation drop-in, and
   check the map style (`src/frontend/assets/maps/`) against the new tiles,
   see §8.11.

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

#### Operating System
- **OS**: Raspberry Pi OS (Debian‑based, 64‑bit preferred)
  • Kernel 5.10+ with `CONFIG_CAN=y`
  • `systemd` for service management

#### Runtime Dependencies (on Pi)
- **CAN Driver**: `socketcan` kernel module loaded (`modprobe can`, `modprobe can_raw`)
- **System libraries**:
  - `libegl1`, `libgles2`, `libgbm1` (Mesa EGL/GLES for ivi-homescreen)
  - `seatd` running (`systemctl enable --now seatd`); `drm-kms-egl` hangs silently on `libseat` without it
  - `libssl3` (OpenSSL runtime)
  - `curl` (for OTA updates)

### Workstation (x86_64 Linux)

#### Build Dependencies (Workstation Only)

**Rust Backend Cross‑Compilation**
- Rust toolchain with `aarch64-unknown-linux-gnu` target (installed via `rustup`)
- `protobuf-compiler` 3.20+
- Standard build tools (gcc, make, pkg‑config)

**Flutter Frontend Cross‑Compilation**
- [`emb_cli`](https://pub.dev/packages/emb_cli) (`dart install emb_cli`)
- An emb workspace with the Flutter SDK emb pins and an
  [ivi-homescreen](https://github.com/toyota-connected/ivi-homescreen) checkout
  (see 3.3); the Flutter SDK on `PATH` is not used for Pi builds (ADR-020)
- Standard build tools

#### System Packages (apt) on Workstation

```bash
sudo apt-get update && sudo apt-get install -y \
  build-essential \
  pkg-config \
  libssl-dev \
  protobuf-compiler \
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

1. **Write OS image** to microSD card:

   ```bash
   # on workstation
   sudo dd if=2024-12-05-raspios-bookworm-arm64.img \
       of=/dev/sdX bs=4M status=progress
   sync
   ```

2. **Enable kernel modules/interfaces**:

   ```bash
   sudo raspi-config
   # enable SPI, I2C, disable serial console if using hardware UART for CAN,
   # set boot to Desktop.
   ```

3. **Configure CAN (socketcan)**:

   ```bash
   sudo tee /etc/network/interfaces.d/can0 > /dev/null <<'EOF'
   auto can0
   iface can0 can static
       bitrate 500000
       up ip link set \$IFACE type can bitrate 500000 restart-ms 100
       down ip link set \$IFACE down
   EOF

   sudo systemctl restart networking
   ip link show can0  # should be UP
   ```

4. **Update packages**:

   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

### 3.2 Build Backend (Rust)

**Build on workstation (Linux), then transfer to Pi.**

1. Install Rust toolchain:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   rustup target add aarch64-unknown-linux-gnu
   ```

2. Build:

   ```bash
   cd src/backend
   cargo build --release --target aarch64-unknown-linux-gnu
   mkdir -p build/backend
   cp target/aarch64-unknown-linux-gnu/release/carnine-backend build/backend/
   ```

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
   cd $W/app/ivi-homescreen
   emb cross . --target rpi4-trixie --backend drm-kms-egl -D DISABLE_PLUGINS=ON --fetch-only -w $W
   ```

   The fetch downloads the Arm GNU toolchain and a RaspiOS trixie sysroot
   (several GB, cached under `~/.cache/emb`). The build also compiles a
   host-native `wayland-cxx-scanner` and needs `sudo apt install libpugixml-dev`
   on the workstation.

2. **Build** with `./build_pi.sh`. It copies `src/frontend` to
   `build/emb-app/carnine_frontend` (emb writes into the app directory),
   stamps the version there, and runs
   `emb cross . --target rpi4-trixie --build --backend drm-kms-egl --app <copy> --mode release -D DISABLE_PLUGINS=ON`.
   Never judge performance from a debug build: `executor_lib` and other
   isolate pools fall back to the main isolate in debug.

3. **Install** the resulting `resources/debos/carnine-frontend.deb` with
   `./deploy_pi.sh`. The package installs the bundle to
   `/opt/carnine/frontend`; `/usr/bin/carnine-frontend` starts
   `homescreen -b /opt/carnine/frontend -f`.

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
sudo -u carnine grpcurl -plaintext -unix /run/carnine/carnine.sock carnine.SystemService/GetServiceVersion
```

(`grpcurl` supports Unix sockets via `-unix`; install it separately, it does
not ship with the image.)

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
grpcurl -plaintext -unix /tmp/carnine-debug.sock carnine.SystemService/GetServiceVersion
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
cargo run --example media_grpc_client -- http://127.0.0.1:50052 version
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
