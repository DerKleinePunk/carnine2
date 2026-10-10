# 25 – Demo and Touch Tools

**Status:** in use on carnine-pc since 2026-09-27 (Raspberry Pi 4, Waveshare
1024x600, ivi-homescreen v3.0 92c2353a).

Two small tools drive the UI on the Pi without anyone touching the panel. They
create a virtual touch panel through `/dev/uinput`, which ivi-homescreen picks
up while it runs, so neither needs a restart of the frontend.

| Tool | Directory | Purpose |
|---|---|---|
| `touchload` | `resources/tools/touchload/` | Load: random swipes and pinch-zooms on the map, reproducible by seed. Used for the frame-time measurements and the freeze soak tests. |
| `demo.sh` + `touchplay` | `resources/tools/demo/` | Show: a scripted sequence of page switches, taps, typing and player commands, for filming the display (social media, trade fair). |
| `messe-einrichten.sh` | `resources/config/messe/` | Trade fair mode: the device drives a tour in rounds on its own, see [Trade fair mode](#trade-fair-mode). |

Both run from the development machine (WSL) and reach carnine-pc over SSH
(`pi@192.168.2.51`, key login; `CARNINE_DEMO_PI` and `CARNINE_DEMO_PORT`
change host and tunnel port). The Pi needs nothing installed beforehand.

## touchload

```bash
cd resources/tools/touchload
aarch64-linux-gnu-gcc -O2 -Wall -static -o touchload touchload.c -lm
scp touchload pi@192.168.2.51:freeze/
ssh pi@192.168.2.51 sudo ~/freeze/touchload 45 1 500   # SECONDS SEED PAUSE_MS
```

Each round has 6 swipes and 3 pinches in and out inside the map area (the top
bar and the side menu are left out), then `PAUSE_MS`. With the same seed you get
the same gestures, which lets you compare two builds. It prints one line per round with
the UTC time. It expects the map page to be open.

## Scripted demo

### Quick start

From the repository root of the worktree:

```bash
resources/tools/demo/demo.sh prepare                                   # once before filming
resources/tools/demo/demo.sh run resources/tools/demo/frankfurt.demo   # as often as needed
resources/tools/demo/demo.sh restore                                   # afterwards
```

Run `prepare` again before each take so the UI starts from the same state:
home page, nothing playing, no route.

### What `prepare` and `restore` change on the Pi

`prepare`:

- builds `touchplay` for aarch64 and copies it with `demo_gps.py` to
  `/home/pi/demo/`
- installs `resources/musik/*.mp3` into `/var/lib/carnine/media/demo/` and
  rescans the library
- plans the drive from Steinau an der Straße to Frankfurt am Main on the Pi's
  own Valhalla (`demo_gps.py plan`) and installs it as
  `/var/lib/carnine/maps/demo-track.json`
- installs `demo_gps.py` as `/var/lib/carnine/maps/demo_gps.py`, creates the
  named pipe `/var/lib/carnine/maps/demo-gps.fifo` and starts the demo GPS
  mouse on it from there as the systemd unit `carnine-demo-gps` (see below).
  The unit runs as `carnine`, which cannot read `/home/pi` (mode 700 on the
  image). It stands in Steinau until the demo file says `drive`.
- installs the drop-in `/etc/carnine/config.d/90-demo.toml`, which sets
  `navigation.position_source = "serial"` with that pipe as `serial_device`
- restarts the backend, stops playback, saves `home` as the start page and
  restarts the frontend

`restore` stops `carnine-demo-gps`, removes the drop-in, the pipe and
`/var/lib/carnine/maps/demo_gps.py`, and
restarts the backend, which then uses its own position source again (on
carnine-pc the recorded tour from `10-navigation.toml`). The music and the
track stay on the Pi.

`prepare` needs `python3` on the Pi; it stops with a message if it is missing.

Restarting the backend interrupts the power supply's sign of life for a moment
(see [23 – Vehicle Power Supply](23-power-supply.md)). On carnine-pc on
2026-09-27, restarts like this left the supply in RUN. The only sign was one
warning: `alive counter low … alive=1`.

### Demo files

A demo file is plain text with one command per line. `#` starts a comment.

| Command | Effect |
|---|---|
| `say TEXT` | Cue on the terminal (for the person filming); nothing on the Pi |
| `page home\|maps\|media\|camera\|controls\|settings` | Tap that item in the side menu |
| `tap X Y` | Tap at a point |
| `swipe X Y DX DY [MS]` | Drag one finger |
| `pinch CX CY FROM TO [MS]` | Two fingers, horizontal distance FROM → TO (zoom) |
| `wait MS` | Pause |
| `type TEXT` | Type on the on-screen keyboard: letters, spaces, capitals via Shift |
| `key done\|backspace\|space\|shift` | One special key of the on-screen keyboard |
| `drive` | The demo GPS mouse leaves Steinau and drives the planned route |
| `play PATH` | `MediaService.Play` with that file (it must be in the library) |
| `cli ARGS...` | Any `media_grpc_client` command, for example `cli seek 30000` |

`frankfurt.demo`, the first demo, takes a little under 2 min: 3 s on home, the
music page with "Here We Go Now" starting, the map page, "Frankfurt am Main"
typed into the destination search, the first hit chosen, the route from Steinau
(about 70 km) on screen for 15 s, so the voice can prepare the first
announcements, then `drive`, the navigation mode switched to heading up, and
60 s of the drive. The whole drive takes about 5 min at factor 10; lengthen
the last `wait` to film it to the end.

For a new demo, copy `frankfurt.demo` and change it. Use `wait` to set the pace
for the camera.

### How it works

- **Touch:** `demo.sh` starts `touchplay` on the Pi once per run over SSH and
  feeds it one gesture per line on stdin. `touchplay` answers `ok` when a
  gesture has finished, so the next line waits for it.
- **Player and settings:** these go over gRPC. The runner opens an SSH tunnel
  from `127.0.0.1:39461` to the backend socket `/run/carnine/carnine.sock` and
  uses `media_grpc_client`, building it if needed. The tunnel belongs to that
  run and closes when `demo.sh` ends; a port that cannot be bound stops it
  with a message (set `CARNINE_DEMO_PORT`). This needs the test
  access from docs/07 ("Backend Connectivity and Debugging": socket mode
  `0660`, runtime directory `0750`, `pi` in the group `carnine`), which
  carnine-pc has; a fresh image does not.
- **Coordinates:** these are logical pixels on the 1024x600 panel, worked out
  from the frontend layout:

  | UI element | Coordinates | Source |
  |---|---|---|
  | Side menu | x 48, items 72 px apart from y 104 (home) | `side_menu.dart` |
  | Destination search field | (560, 82) | `destination_search.dart` |
  | First hit | (560, 154) | `destination_search.dart` |
  | Navigation mode button | (974, 404), with a route on screen | `maps_content.dart` |
  | On-screen keyboard | rows at y 357 / 423 / 489 / 555, key unit 76.92 px | `keyboard_layout.dart`, `keyboard_panel.dart` |

  **When any of these layouts change, the coordinates in `demo.sh` and in the
  demo files have to follow.** Nothing checks them automatically.
- **The demo GPS mouse:** `demo_gps.py feed` writes one `GGA` and one `RMC`
  per fix into the pipe, with the current UTC time. The backend reads the pipe
  like a GPS mouse (`GPS source is not a terminal, reading it as is`) and
  opens it again when it ends. Until `drive` the fixes stand at the start of
  the planned track, speed 0, no course: the road Valhalla snaps 50.31165,
  9.45940 (Steinau, the `town` place from the names database) to. `drive` sends `SIGUSR1` to the unit
  (`systemctl kill -s USR1 --kill-whom=main carnine-demo-gps`); from then on it follows the
  planned track with the speeds Valhalla gives for each stretch, and at the
  end it stands at the destination (50.11065, 8.68209, the first hit for
  "Frankfurt am Main").
- **Why a pipe and not the replay source:** in replay mode the map loads a
  route of its own (`MapsController` loads `GetReplayRoute`), before anyone
  types a destination. The serial source brings no route, so the typed
  destination is the only one. Because the track is planned on the same
  Valhalla with the same two points, the car stays on that route, so the
  map library (local_map 0.7.0 and later) has no reason to reroute.
- **Speed:** `CARNINE_DEMO_FACTOR` (default 10) is the seconds of the drive per
  second of video, `CARNINE_DEMO_HZ` (default 2) the fixes per second of video.
  Both are read by `prepare`. The speed shown stays the real one; only the
  car moves faster.
- `standstill-nmea.sh` is no longer used by `demo.sh`. It still writes a
  standstill log for the replay source when one is needed.

### Testing the reroute

Since local_map 0.7.0 the map computes the route again when the car leaves
it (user guide, `karte.md`). The demo GPS mouse can test that on the device:
plan a drive that takes a detour, type only the destination in the UI, and
let the mouse drive.

```bash
# on the Pi, after demo.sh prepare; Alsfeld, a detour, Liederbach (7.1 km)
cd /home/pi/demo
python3 demo_gps.py plan 50.751563 9.271198 50.726997 9.246758 \
    umweg-track.json --via 50.744158,9.287062
sudo install -o carnine -g carnine -m 0644 umweg-track.json \
    /var/lib/carnine/maps/demo-track.json
sudo systemctl restart carnine-demo-gps
```

- Each `--via` becomes a Valhalla `through` location, in the order given,
  without a stop. Choose the point off the direct route, so the drive leaves
  the route the map shows.
- The demo file types the destination (here "Liederbach") and taps the
  first hit, as `frankfurt.demo` does, then `drive`. The map shows the direct route; once
  the car turns off towards the via point, the log shows
  `[route] Route verlassen` and `[route] Route neu berechnet (#n), x km`.
- On carnine-pc on 2026-10-06 (Alsfeld, a detour, Liederbach; direct
  route 4.0 km, track 7.1 km, factor 2) it rerouted three times within 40 s.
  The third route (5.7 km) matched a route asked for by hand from that point;
  the car then stayed on it to the destination. Valhalla answered in about
  40 ms.
- Tests for `plan`: `python3 -m unittest test_demo_gps.py` in
  `resources/tools/demo/`, against a stand-in Valhalla; CI runs them in the
  backend job.

### Known quirks

- Do not signal the GPS mouse with `pkill -f demo_gps` over SSH: the pattern
  is also in the SSH command line, and `SIGUSR1` ends that shell. `demo.sh`
  uses `systemctl kill` for this reason.
- A search for "Frankfurt" alone ranks a village of that name near Scheinfeld
  first, so the demo types "Frankfurt am Main".
- The music is audible on the Pi's output at whatever volume is set.

## Trade fair mode

At the trade fair (Kunsthalle Montez, Frankfurt) the device runs on its own,
without a laptop driving it: the replay source drives a fixed tour in rounds,
with turn announcements and music. Unlike the scripted demo nothing is typed;
the map loads the tour's route itself (`GetReplayRoute`).

**Switching it on and off** from the development machine (WSL) or the laptop:

```bash
resources/config/messe/messe-einrichten.sh pi@192.168.2.51 an 192.168.77.2   # carnine-pc
resources/config/messe/messe-einrichten.sh pi@192.168.2.51 aus
```

`an` copies the tour to `/var/lib/carnine/maps/messe-tour.nmea` and
`90-messe.toml` to `/etc/carnine/config.d/`, then restarts backend and
frontend. `aus` removes `90-messe.toml` and restarts; the tour file and a fixed
address stay. The script turns nothing up: the music starts at the volume it
had.

**The drop-in** `resources/config/messe/90-messe.toml` overrides
`10-navigation.toml` (drop-ins: [07 – Deployment, "Carnine Runtime User"](07-deployment.md#carnine-runtime-user)):

| Key | Value | Effect |
|---|---|---|
| `[navigation] position_source` | `"replay"` | the tour instead of the GPS mouse |
| `[navigation] replay_file` | `/var/lib/carnine/maps/messe-tour.nmea` | the tour |
| `[navigation] replay_loop` | `true` | rounds without end |
| `[navigation] replay_destination_name` | `"Kunsthalle Montez"` | the destination's name for the search field; without it street and locality from the names database |
| `[navigation] demo_mode` | `true` | tells the frontend it is at the trade fair |
| `[media] resume_mode` | `"auto-play"` | music starts by itself after power on, from the last playlist |

**The tour** runs from Frankfurt Hauptbahnhof (south side) through Sachsenhausen
along the Main to the Honsellbrücke at the Kunsthalle Montez (Honsellstraße 7):
6.2 km, about 9 min a round with 10 s standing at the start and 20 s at the
destination (533 fixes, 8.9 min). It was planned on carnine-pc's Valhalla
through a tunnel and written as NMEA, with no via point; start and destination
come from the names database:

```bash
ssh -f -N -o ExitOnForwardFailure=yes -L 18002:127.0.0.1:8002 pi@192.168.2.51
cd resources/tools/demo
python3 demo_gps.py plan 50.10572 8.66410 50.10818 8.71014 messe-tour.json --valhalla http://127.0.0.1:18002
python3 demo_gps.py nmea messe-tour.json ../../config/messe/messe-tour.nmea   # --hz 1 --hold-start 10 --hold-dest 20
```

Another tour: other points, `--via LAT,LON` for each point to pass through.

`nmea` writes the drive in real time from a fixed day; only the gaps between
the fixes count, since the backend replaces the times with its own clock.

**What the backend reports** (`NavigationService`):

| Field | Meaning |
|---|---|
| `NavigationStatus.replay_lap` | round of the tour now driving, from 1; 0 without a replay. It rises with every new round, so a map that dropped the route after "Abbrechen" takes it up with the next one. |
| `NavigationStatus.demo_mode` | `[navigation] demo_mode` |
| `Route.destination_name` | the end of the replay route, for the search field; empty for other routes |

`media_grpc_client <endpoint> nav-status` shows `replay_lap=… demo_mode=…`,
`replay-route` shows `destination=…`.

**Fixed address.** With a third argument (`192.168.77.x`) the device keeps that
address beside DHCP, for a laptop on a switch without a router; the laptop
takes `192.168.77.1/24`. On image devices (systemd-networkd) the script
installs `/etc/systemd/network/wired.network.d/50-messe.conf`
(from `50-messe.network.conf`). On a device with NetworkManager it sets
nothing and prints the `nmcli` line to do it by hand. carnine-pc uses `.2`,
jeep-pi `.3`.

**Still open in the frontend** (Jonas): take up the route again with the next
round after "Abbrechen"
([#126](https://github.com/DerKleinePunk/carnine2/issues/126)), the
destination in the search field
([#127](https://github.com/DerKleinePunk/carnine2/issues/127)), back to the
map after 60 s without a touch while `demo_mode` is on, not with the keyboard,
a dialog or the media picker open
([#128](https://github.com/DerKleinePunk/carnine2/issues/128)), and the
password before leaving the app
([#51](https://github.com/DerKleinePunk/carnine2/issues/51)).

Tests: `sh resources/config/messe/tests/messe-einrichten-test.sh` (also in CI,
with shellcheck), the `nmea` tests in `test_demo_gps.py`, and backend tests for
the shipped tour file, the rounds, the name and the drop-in.
