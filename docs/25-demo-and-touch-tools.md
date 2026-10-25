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
| `drm_shot*.py`, `carmcp.py`, `touch_load.py` | `resources/tools/drm-shot/` | Pictures for the user guide: photo of the display output, getting to the page, see [Screenshots for the user guide](#screenshots-for-the-user-guide). They run on the Pi itself. |

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

## Screenshots for the user guide

The pictures in `docs/bedienung/bilder/` (and on carnine.de) are taken on the
test Pi (jeep-pi) with the **release packages**, before the version is tagged
(CONTRIBUTING, "Release checklist"). flutter-local-map takes them,
carnine2-docs builds them into the guide.

**Photo straight from the display output.** The tools read the DRM scanout,
so the result is exactly what the panel shows, 1024×600, no camera, no
window frame. The tools are in `resources/tools/drm-shot/`; copy the
directory to the Pi as a whole (`carmcp.py shot` calls `drm_shot.py` next to
it). They need root (DRM handles) and libdrm:

```bash
scp -r resources/tools/drm-shot pi@<pi>:
sudo python3 ~/drm-shot/drm_shot_planes.py ~/bilder-<version>/optionen.png   # all KMS planes, needs python3-numpy
sudo python3 ~/drm-shot/drm_shot.py check.png                                 # primary plane only, no numpy
sudo chown pi:pi ~/bilder-<version>/*.png
```

`drm_shot_planes.py` stacks every plane by zpos; the camera or a video sits on
its own plane, so pages with a platform view come out black with
`drm_shot.py`. Take guide pictures with `drm_shot_planes.py` always;
`drm_shot.py` is fine for a quick check. `drm_shot_planes.py` also lives in
[video_grabber](https://github.com/DerKleinePunk/video_grabber) (`tools/`).
Both run on jeep-pi; on carnine-pc `drm_shot.py` has been used,
`drm_shot_planes.py` needs python3-numpy there.

Tests (no DRM device, socket or uinput needed; also in the CI, which installs
python3-numpy so that none are skipped):
`cd resources/tools/drm-shot && python3 -m unittest discover -v`.

**Getting to the right page.**

- **Touch over uinput** (any build): `sudo python3 ~/drm-shot/touch_load.py tap X Y`
  in panel pixels (0..1023, 0..599), read off an earlier picture (middle of
  the button). `hold X Y S [COMMAND]` presses for S seconds and runs COMMAND
  while held (e.g. a picture of a pressed state). Without arguments it runs
  map load rounds like the C tool [touchload](#touchload) and logs them to
  `~/freeze/load.log` of the user behind sudo (`TOUCH_LOAD_LOG` overrides).
  Each call creates a new input device and the frontend keeps a file
  descriptor per device, so for many taps use `touchplay`
  ([Scripted demo](#scripted-demo)). The coordinates follow the layout:
  check them for each version.
- **MCP** (only a frontend built with `CARNINE_FRONTEND_MCP=1` and started
  with `--enable-mcp`, see
  [07 – Deployment, Build Frontend](07-deployment.md#33-build-frontend-flutter-via-emb_cli--ivi-homescreen);
  jeep-pi since 2026-10-17, not carnine-pc): the client `carmcp.py`, run as
  the user of the frontend (not root), talks to the local socket
  `/run/user/<uid>/ivi-homescreen/mcp.sock` (`CARMCP_SOCK` overrides). It
  lists the widget tree with labels and rectangles (`nodes [filter]`), taps
  by label or position (`tap <label>`, `tapxy X Y`, `long <label>`) and
  types through the app's own keyboard (`type <text>`; clear the field with
  its X first). `shot <name>` writes `~/shots/<name>.png` with `drm_shot.py`
  (primary plane only, so not for pages with a platform view).
- **Start page without tapping:** `media_grpc_client <endpoint> save-ui-state
  <page>` sets the page the UI opens on.
- A small helper per version chains the steps, for example
  `b0191.sh t 46 466 w 2 s optionen-system`: `t X Y` taps and waits 1.5 s,
  `w SEC` waits, `s NAME` takes the photo `~/bilder-<version>/NAME.png`.

**What is on the picture.** The backend runs with a copy of the current
`config.toml` that changes only what the picture needs, started by hand with
`CARNINE_CONFIG=<file>` instead of the unit:

- route pictures: `[navigation] position_source = "serial"` on
  `~/demo/gps.fifo`, fed by `demo_gps.py feed <track.json>`, so only the
  route tapped in for the picture is on the map;
- map and announcements otherwise: the replay source (Schwalmstadt –
  Alsfeld);
- the overheat notice: `[system] cpu_temperature_warn_celsius` set low
  (30, clear 25);
- the connection notice: stop the backend for a moment (only on a device
  without the KL15 power supply, see below);
- music: a fixed playlist, so titles and covers stay the same; volume and
  playlist are set in the app. Trade fair mode stays off.

Afterwards stop the backend started by hand and start the unit again with
the normal `config.toml` (`sudo systemctl stop carnine-backend; sudo
systemctl reset-failed carnine-backend; sudo systemctl start
carnine-backend`), and stop `demo_gps.py`.

On a device with the KL15 power supply ([23](23-power-supply.md); carnine-pc,
later jeep-pi), **never leave the backend stopped**: only the backend sends
the sign of life, and the supply cuts the Pi after about 3 s without it. There
put the changed keys in a drop-in in `/etc/carnine/config.d/` and run `sudo
systemctl restart carnine-backend` instead of starting the backend by hand;
afterwards remove the drop-in and restart again. A drop-in replaces arrays
such as `[[controls]]` as a whole.

**Rules.**

- No people on any picture; point the camera at an empty scene.
- No post-processing for the guide: PNG, 1024×600 as the scanout delivers
  it, covers stay. For the website, covers are pixelated and the pictures
  carry no version number.
- Compare each new picture with the old one; if only the clock or status
  symbols differ, the old one stays.
- The pictures go to the share first (`anhaenge/bedienung-<version>/` with
  `SHA256SUMS`, nothing overwritten), then into the guide with mode 644.
  Set the version in the first line of `docs/bedienung/README.md` and run
  `docs/bedienung/pdf/build.sh`.
- jeep-pi drives a 160 W amplifier: do not turn the volume up for a media
  picture without telling Michael.

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
| `[media] resume_mode` | `"auto-play"` | music starts by itself after power on, from the last playlist; on a fresh card nothing plays until a playlist has been played once |

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

**The first round waits for its route** (since aed6f03): in trade fair mode
the replay publishes its first fix at once, so the map has the position, and
stands there until the tour's route is computed, at most 30 s; then it drives
off. Later rounds, replays without trade fair mode, a tour without any valid
fix (it gets no route) and a GPS mouse drive at once. After a cold start the
replay used to drive off with the backend while the frontend asked for the
route about 4.5 s later, and the start announcement was ready only after the
car had passed its spot (2026-10-23, carnine-pc). The backend log says
"replay waits at its start for the route", then "replay route ready, the
tour drives off" with `waited_ms`, or after 30 s the warning "no replay
route in time, the tour drives off anyway". On a cold start on 2026-10-23 it
waited 5.9 s; the start announcement came 1 ms late and the next one 0.8 s
late, where before it was missing and the next one came 6.5–8.2 s late.
While the first round stands, `replay_lap` is 0; it becomes 1 only when the
tour drives off (since 84db1b7). After a restart of only the backend, a
frontend that still shows lap 1 from before sees the lap fall, fetches the
new route and so lets the tour go; with lap 1 already during the wait it saw
no change and the tour stood the full 30 s (2026-10-23, carnine-pc and
jeep-pi).

**What the backend reports** (`NavigationService`):

| Field | Meaning |
|---|---|
| `NavigationStatus.replay_lap` | round of the tour now driving, from 1; 0 without a replay and while the first round waits at its start for the route. It rises with every new round, so a map that dropped the route after "Abbrechen" takes it up with the next one. |
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

**What the frontend does with it** (Jonas, eaa6317 and c8ebf8a; the user
guide describes it in `verhalten.md`, section „Messe-Modus“, and `karte.md`):

- **"Abbrechen" lasts until the round ends**
  ([#126](https://github.com/DerKleinePunk/carnine2/issues/126)). When
  `replay_lap` rises, the map fetches `GetReplayRoute` again and follows with
  the heading up, as at the start. When `replay_lap` falls below the last value
  seen (backend restarted, trade fair mode switched on by drop-in), the old
  replay route is dropped and the new one fetched, also after "Abbrechen", so
  a stale "Ziel erreicht" no longer comes. A route the user picked is left
  alone. There is no `setRoute` per round (local_map 0.8.8).
- **Destination in the search field**
  ([#127](https://github.com/DerKleinePunk/carnine2/issues/127)):
  `Route.destination_name` stands there like a chosen destination, without a
  search, with **X** to clear it; typing goes to the search as before. After
  "Abbrechen" the field is empty again; a destination the user picked is not
  overwritten.
- **Back to the map after 60 s without a touch** while `demo_mode` is on
  ([#128](https://github.com/DerKleinePunk/carnine2/issues/128),
  `idle_return.dart`). Every touch, also on the keyboard and in dialogs,
  starts the 60 s again. While the on-screen keyboard, a dialog or one of the
  playlist flows in Medien (create, add titles, rename) is open, the page
  stays and waits another minute. Without `demo_mode` nothing changes.
- **Zoom in the log**
  ([#130](https://github.com/DerKleinePunk/carnine2/issues/130)): each change
  of the whole zoom level writes a line like `[map] Zoom 16 (15.7)` to the
  frontend log: the log viewer (Optionen → System → Logansicht öffnen) and
  `/var/log/carnine/frontend.log` on the Pi, not the journal.
- **No replay route** ([#100](https://github.com/DerKleinePunk/carnine2/issues/100)):
  when `GetReplayRoute` fails (for example `NOT_FOUND` while Valhalla still
  starts), the frontend waits 3, 6, 15, 30 and then 60 s between tries
  (`MapsController.defaultReplayRetryDelays`) and logs the reason once
  („No replay route yet: …“). A new round, a backend restart or another
  position source tries again at once; after "Abbrechen" it does not ask.

The password before leaving the app
([#51](https://github.com/DerKleinePunk/carnine2/issues/51), 530609a) is
checked by the backend:
[07 – Deployment, "Exit password"](07-deployment.md#exit-password-beenden).

Tests: `sh resources/config/messe/tests/messe-einrichten-test.sh` (also in CI,
with shellcheck), the `nmea` tests in `test_demo_gps.py`, and backend tests for
the shipped tour file, the rounds, the name and the drop-in.
