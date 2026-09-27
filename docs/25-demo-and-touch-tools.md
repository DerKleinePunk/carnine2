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

Both run from the development machine (WSL) and reach carnine-pc over SSH
(`pi@192.168.2.51`, key login). The Pi needs nothing installed beforehand.

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

- builds `touchplay` for aarch64 and copies it to `/home/pi/demo/`
- installs `resources/musik/*.mp3` into `/var/lib/carnine/media/demo/` and
  rescans the library
- writes a standstill position log for Steinau an der Straße (see below) to
  `/var/lib/carnine/maps/demo-steinau.nmea`
- installs the drop-in `/etc/carnine/config.d/90-demo.toml`, which points
  `navigation.replay_file` at that log
- restarts the backend, stops playback, saves `home` as the start page and
  restarts the frontend

`restore` removes the drop-in and restarts the backend, which then uses its
own position source again (on carnine-pc the recorded tour from
`10-navigation.toml`). The music stays in the library.

Restarting the backend interrupts the power supply's sign of life for a moment
(see [23 – Vehicle Power Supply](23-power-supply.md)). On carnine-pc on
2026-09-27, restarts like this left the supply in RUN. The only sign was one
warning: `alive counter low … alive=1`.

### Demo files

A demo file is plain text with one command per line. `#` starts a comment.

| Command | Effect |
|---|---|
| `say TEXT` | Cue on the terminal (for the person filming); nothing on the Pi |
| `page home\|maps\|media\|climate\|controls\|settings` | Tap that item in the side menu |
| `tap X Y` | Tap at a point |
| `swipe X Y DX DY [MS]` | Drag one finger |
| `pinch CX CY FROM TO [MS]` | Two fingers, horizontal distance FROM → TO (zoom) |
| `wait MS` | Pause |
| `type TEXT` | Type on the on-screen keyboard: letters, spaces, capitals via Shift |
| `key done\|backspace\|space\|shift` | One special key of the on-screen keyboard |
| `play PATH` | `MediaService.Play` with that file (it must be in the library) |
| `cli ARGS...` | Any `media_grpc_client` command, for example `cli seek 30000` |

`frankfurt.demo`, the first demo, takes about 36 s: 3 s on home, the music page
with "Here We Go Now" starting, the map page, "Frankfurt am Main" typed into
the destination search, the first hit chosen, and the route from Steinau
(69.5 km) on screen for 8 s.

For a new demo, copy `frankfurt.demo` and change it. Use `wait` to set the pace
for the camera.

### How it works

- **Touch:** `demo.sh` starts `touchplay` on the Pi once per run over SSH and
  feeds it one gesture per line on stdin. `touchplay` answers `ok` when a
  gesture has finished, so the next line waits for it.
- **Player and settings:** these go over gRPC. The runner opens an SSH tunnel
  from `127.0.0.1:50061` to the backend socket `/run/carnine/carnine.sock` and
  uses `media_grpc_client`, building it if needed. The socket is group
  `carnine`, and `pi` is in that group.
- **Coordinates:** these are logical pixels on the 1024x600 panel, worked out
  from the frontend layout:

  | UI element | Coordinates | Source |
  |---|---|---|
  | Side menu | x 48, items 72 px apart from y 104 (home) | `side_menu.dart` |
  | Destination search field | (560, 82) | `destination_search.dart` |
  | First hit | (560, 154) | `destination_search.dart` |
  | On-screen keyboard | rows at y 357 / 423 / 489 / 555, key unit 76.92 px | `keyboard_layout.dart`, `keyboard_panel.dart` |

  **When any of these layouts change, the coordinates in `demo.sh` and in the
  demo files have to follow.** Nothing checks them automatically.
- **Standing in Steinau:** the backend's replay source plays
  `standstill-nmea.sh` output: one `GGA` and one `RMC` per second, speed 0, no
  course, one hour long, looped. The coordinates are 50.31165, 9.45940, the
  `town` place from the names database.
- **Why the car stands still:** a replay that drives would bring its own route
  onto the map by itself (`MapsController` loads `GetReplayRoute` in replay
  mode), before anyone types a destination. A standstill log gives no route of
  its own, so the typed destination is the only one.

### Known quirks

- While the car stands, the frontend asks for the replay route every 3 s. Each
  time the backend logs `replay route failed … Insufficient shape provided
  (error_code 123)`, because Valhalla cannot map-match a single point. This is
  noise in the log only; nothing shows on screen.
- A search for "Frankfurt" alone ranks a village of that name near Scheinfeld
  first, so the demo types "Frankfurt am Main".
- The music is audible on the Pi's output at whatever volume is set.
