# 26 – Spoken Turn Announcements

**Status:** on feature/backend since 2026-10-06 (backend 2e65a6f, frontend
with local_map 0.8.3), first in the release after 0.13.0. Heard and measured
on carnine-pc (Raspberry Pi 4, 4 GB) on 2026-10-06. Only German so far.

During navigation CarNine speaks the turn instructions: "In 300 Metern rechts
auf Bahnhofstraße abbiegen. Dann weiter auf L 3195.", then at the turn
"Rechts auf Bahnhofstraße abbiegen." The speech is made on the device by
sherpa-onnx with a Piper voice; no network is involved. The music goes down
while a sentence plays.

## Who does what

| Part | Where | Job |
|---|---|---|
| Valhalla | backend, `src/backend/src/navigation/valhalla.rs` | gives each maneuver three spoken texts: before it, at it, after it |
| Map library (local_map ≥ 0.8.3) | flutter_local_map | decides **what** is spoken and **when**; sends the sentences ahead (prepare) and at the moment (announce) |
| Frontend adapter | `GrpcAnnouncer` in `src/frontend/lib/features/maps/data/grpc_navigation_adapters.dart` | passes both on to the backend; a failed call is logged and dropped |
| Voice | backend, `src/backend/src/voice.rs` | turns text into speech on its own thread, keeps it, plays it |
| Player | backend, `src/backend/src/media_player.rs` | plays the sentence over the music and lowers the music meanwhile |

The library only hands over text. Speaking, mixing and loudness are the
backend's job, so the switch and the loudness apply to every host.

## When the library speaks

The rules live in local_map (`AnnouncementPolicy`, `AnnouncementTexts`):

- **Warning stages:** below 80 km/h one warning at **300 m**; from 80 km/h
  two, at **1 km** and **400 m**. Back to the lower class only below 70 km/h,
  so the class does not flip around 80. A stage is spoken while the car is
  between 100 % and 60 % of its distance (300 m: from 300 m down to 180 m).
  The sentence is a fixed lead-in plus Valhalla's alert text, e.g.
  "In 300 Metern" + "links auf Schellengasse abbiegen. Dann weiter auf B 62."
- **At the turn** ("jetzt"): at max(40 m, 3 s of driving) before the maneuver,
  Valhalla's text for that moment.
- **Destination:** "In 300 Metern erreichen Sie Ihr Ziel." as the warning,
  then Valhalla's sentence at the destination, e.g. "Sie haben Ihr Ziel
  erreicht." Nothing after that.
- **Each stage at most once per maneuver.** An announced maneuver never comes
  again, not even after a GPS jump back. If the car is already closer than a
  stage when the maneuver becomes the next one, that stage is skipped.
- **Nothing at standstill and nothing off the route.**
- **Recalculation:** "Die Route wird neu berechnet." once, when the new
  calculation starts (see [Karten → Von der Route abgekommen](bedienung/karte.md#während-der-fahrt));
  not for the retries after an error and never in the replay. The replay
  (`setRoute`) speaks the turns all the same.
- The text after a maneuver ("200 Meter weiter auf B 62") is off
  (`announcePost`); it would talk too much.

In an old town with turns 70 m apart three "jetzt" sentences can come within
12 s. Valhalla already links such turns ("Dann, in 70 Metern, …").

### Language: only German works

The voices are German, and the library's lead-ins are always German
(`MapsController` passes no `AnnouncementPolicy`, so local_map takes
`AnnouncementTexts.german`). Valhalla's texts, however, come in the UI
language, because the frontend asks for the route in it. With the UI set to
another language the result is a mix, e.g. "In 300 Metern Turn right onto
Bahnhofstraße.", spoken with German pronunciation. This is a known gap, not
intended; whether announcements stay silent for other languages, are always
German or get a voice of their own is still open.

### What is prepared

Synthesis takes seconds (see [Measurements](#measurements)), so the library
names the sentences ahead in an `AnnouncementPrepare` whenever a maneuver
becomes the next one, after every new route and when the speed class changes.
The list holds, in speaking order:

1. the stages of the next maneuver that can still come at this speed and
   distance (a stage the car is already past is left out),
2. its "jetzt" sentence,
3. the sentences of up to **2 following maneuvers** that start within
   **500 m** (lookahead; a stage only if the gap to the maneuver before is
   larger than 60 % of it),
4. "Die Route wird neu berechnet." at the end.

Every announcement is word for word one of the sentences prepared before
(tested in the library), so the backend finds it in its cache by the text.

## In the backend

```
PrepareAnnouncements(texts) ──► voice thread (core 3) ── synthesize one by one ──► cache (WAV, /run/carnine/voice)
Announce(text, priority) ──► in the cache? ── yes ──► play now ──► player: speech over the music
                                           └─ no ───► voice thread: synthesize, then play
```

- **One voice thread**, pinned to **core 3** before the voice loads; the
  voice is loaded once at start (about 3 s) and stays in memory. The map's
  UI and raster threads keep the other three cores.
- **Prepare:** a new list replaces the one not yet worked through. The thread
  synthesizes one sentence at a time; an announcement that was not prepared
  waits for at most the sentence in progress.
- **Announce, prepared:** the sentence plays at once from the caller's
  thread; it does not wait for the sentence the voice thread is working on.
  The sentences before it in the prepare list are dropped (they belonged to
  earlier stages and will not come).
- **Announce, not prepared:** the voice thread synthesizes it next. If
  several pile up meanwhile, only the newest is spoken. A sentence that
  finishes after a newer one has already played stays silent, so nothing
  out of date follows.
- **Cache:** same text, same file. Up to 200 sentences as WAV in
  `cache_dir` (tmpfs), the oldest go first.
- **Loudness:** the Piper voices peak at about a third of full scale; each
  sentence is raised to a peak of 0.9, at most 4 times (+12 dB), without
  clipping. `volume_percent` scales it from there.
- **Over the music:** the music goes to `music_under_percent` while a
  sentence plays and back up afterwards. Paused music stays silent.
- **Priorities:** `MANEUVER` (stages, "jetzt", destination) and `INFO`
  ("Die Route wird neu berechnet."). A turn instruction cuts a running
  information short; an information that meets a running turn instruction is
  dropped. A newer turn instruction replaces a running one.
- **Without a voice** (package missing, voice not loadable, WSL) the backend
  logs it once and runs on silently; `PrepareAnnouncements` and `Announce`
  still answer OK, so the frontend needs no special case.

### gRPC

`NavigationService` in `src/proto/carnine.proto`:

| Call | Does |
|---|---|
| `PrepareAnnouncements(texts)` | synthesizes the texts in the background |
| `Announce(text, priority)` | speaks the text; unspecified priority counts as `MANEUVER` |
| `GetVoiceSettings()` | `available` (voice loaded), `enabled`, `volume_percent`, `voice` |
| `SetVoiceSettings(enabled?, volume_percent?)` | changes and saves; a loudness above 100 is `INVALID_ARGUMENT` |

`Maneuver` carries Valhalla's texts as `verbal_alert` (7, before),
`verbal_pre` (8, at) and `verbal_post` (9, after), also in `GetReplayRoute`.
They are absent when Valhalla gives none; the library then falls back to
`instruction`.

## Voices and package

The package **carnine-voice** (1.13.8-1, arm64, about 132 MB as .deb) brings:

| Path | Content |
|---|---|
| `/usr/lib/carnine/voice/` | `libsherpa-onnx-c-api.so` and `libonnxruntime.so` (sherpa-onnx 1.13.8, shared-cpu build) |
| `/usr/share/carnine/voices/thorsten-medium/` | the default voice (`*.onnx`, `tokens.txt`, link to `espeak-ng-data`) |
| `/usr/share/carnine/voices/thorsten-low/` | the faster, simpler voice |
| `/usr/share/carnine/voices/espeak-ng-data/` | shared by both voices (19 MB) |

The voices are "thorsten" (Piper, German, CC0). Michael listened to both and
found both good; **thorsten-medium** is the default, thorsten-low is about
a third faster (see [Measurements](#measurements)). Both are in the image, so
switching needs no download.

The backend loads the library with `dlopen` at run time; it does not link
against it. The image recipe installs the package
(`resources/debos/carnine-voice.deb`). Build it with

```sh
resources/voice/package-deb.sh resources/debos/carnine-voice.deb
```

The script downloads the release files once into `build/voice-downloads/` and
checks them against pinned SHA-256 values (see
[resources/debos/README.md](../resources/debos/README.md#sprachansagen)).

## Configuration

`[voice]` in the backend configuration (template in
`resources/config/carnine.toml`); all keys are optional:

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `true` | speak at all |
| `voice` | `"thorsten-medium"` | subfolder of `voices_dir`; `"thorsten-low"` is the other one |
| `voices_dir` | `/usr/share/carnine/voices` | one subfolder per voice |
| `library_dir` | `/usr/lib/carnine/voice` | where the sherpa-onnx libraries are |
| `cpu` | `3` | core the voice thread is pinned to |
| `threads` | `1` | synthesis threads |
| `cache_dir` | `/run/carnine/voice` | synthesized sentences (tmpfs) |
| `volume_percent` | `100` | loudness of the announcements, 0–100 |
| `music_under_percent` | `30` | music level while a sentence plays, 0–100 |

To switch the voice, put it in a drop-in and restart the backend:

```toml
# /etc/carnine/config.d/40-voice.toml
[voice]
voice = "thorsten-low"
```

```sh
sudo systemctl restart carnine-backend
```

`threads` above 1 does not help while `cpu` is set: the synthesis threads
inherit the pinning and all run on that one core. Two threads on two cores
were considered and dropped (see [Measurements](#measurements)).

**Switch and loudness are saved.** `SetVoiceSettings` writes them into the
media database (schema 12, columns `voice_enabled` and `voice_volume` in
`navigation_state`); saved values win over `enabled` and `volume_percent` in
the configuration. A database from before schema 12 is migrated at start
with both empty, which means "as the configuration says". The options page
does not have the switch and the slider yet
([#110](https://github.com/DerKleinePunk/carnine2/issues/110)); until then
the example client does it:

```sh
media_grpc_client <endpoint> voice-settings                 # available=true enabled=true volume=100 voice=thorsten-medium
media_grpc_client <endpoint> set-voice-settings off         # or on
media_grpc_client <endpoint> set-voice-settings - 80        # '-' keeps the switch
media_grpc_client <endpoint> announce "Links abbiegen."     # MANEUVER; add 'info' for INFO
media_grpc_client <endpoint> prepare-announcements "Erster Satz." "Zweiter Satz."
```

`announce` plays sound from the device.

## Checking on the device

`journalctl -u carnine-backend` shows:

| Line | Meaning |
|---|---|
| `voice ready` | voice loaded, speech works |
| `no speech output: the voice did not load` | with the reason (library or voice missing); the backend runs on silently |
| `speech ready text=… synthesis_ms=… audio_ms=…` | one sentence synthesized; `synthesis_ms` against `audio_ms` shows how fast the voice is |
| `announcement spoken text=… late_ms=…` | played, `late_ms` after the library asked for it |
| `speech synthesis failed` | that sentence is skipped, the voice goes on |

`late_ms` in the tens of milliseconds means the sentence was prepared in
time; seconds mean it was synthesized on demand or waited.

## Demo

`frankfurt.demo` waits **15 s** between "Route steht" and "Losfahren". When
the route is set, the voice has to synthesize the first sentences one after
the other (about 6 s for the first); with 15 s all of them are ready before
the car moves. See [25 – Demo and Touch Tools](25-demo-and-touch-tools.md#scripted-demo).

## Measurements

All on carnine-pc (Raspberry Pi 4, 4 GB, case fan at 50 %), 2026-10-06, with
the demo drive Steinau → Frankfurt at real speed (`demo.sh`, factor 1).
"Waits" is how long the frontend's `ui` and `raster` threads wait for a free
core (schedstat), in ms per second; when they wait, the map stutters.

### Synthesis speed, voice alone

Real-time factor = synthesis time / length of the speech; six typical
sentences, no map running.

| Voice | 1 thread | 2 threads | 4 threads | longest sentence (5 s of speech) |
|---|---|---|---|---|
| thorsten-low | 0.6 | 0.36 | 0.27 | 2.9 s / 1.8 s / 1.3 s |
| **thorsten-medium** | **0.8** | 0.47 | 0.35 | 3.8 s / 2.3 s / 1.8 s |
| thorsten-medium int8 | 1.2 | 1.0 | 0.8 | slower; useless on the Pi 4 |

Loading a voice takes about 3 s, at most 175 MB RAM per process with the
model. With the map running, medium on one thread needs about as long as the
sentence lasts: 3–8 s per sentence, up to about 10 s in the first minute while the map
loads.

### Pinning protects the map

Synthesis without pause and the model reloaded every few seconds (worst
case), in 15 s blocks against blocks without speech:

| Speech | ui waits (mean) | raster waits (mean) | longest stop |
|---|---|---|---|
| off | 1.3 | 4.2 | 8 ms |
| 2 threads, not pinned | 18.9 | 16.6 | 277 ms, visible |
| **1 thread on core 3** | 6.7 (off: 1.6) | 4.5 (off: 4.9), unchanged | 194 ms, a single peak |

Hence one thread pinned to core 3.

### In the build: map unaffected

Backend 607fc6a, local_map 0.8.1, thorsten-medium; announcements 60 s on and
60 s off, 5 blocks each, sampled every 10 s:

| Announcements | ui waits (mean / max) | raster waits (mean / max) | CPU max | load |
|---|---|---|---|---|
| on | 6.3 / 85 | 5.7 / 29 | 34.6 °C | 1.90 |
| off | 5.2 / 51 | 6.6 / 41 | 34.1 °C | 1.68 |

No difference for the map. The CPU stayed between 28.7 and 34.6 °C, without
throttling; with announcements nonstop and unprepared (an earlier run) the
maximum was 35.1 °C.

### How late the announcements come

On the way every announcement came **2–51 ms** after the library asked for
it, in all versions below. The start of the drive was the hard part: the
first three maneuvers lie within a few hundred metres, and the voice has to
synthesize everything at once when the route is set. Measured with only 4 s
between "Route steht" and "Losfahren":

| Announcement | 0.8.1 | 0.8.2 | 0.8.3 | 0.8.3 + backend 2e65a6f |
|---|---|---|---|---|
| "Auf Fuchsberg Richtung Norden fahren. Dann links auf Brüder-Grimm-Straße abbiegen." | 3.5 s | 4.2 s | 0.17 s | 1.0 s |
| "Links auf Brüder-Grimm-Straße abbiegen." | 4.0 s | 4.5 s | 4.0 s | **0.26 s** |
| "In 300 Metern rechts auf Bahnhofstraße abbiegen. …" | 7.3 s | 6.1 s | 7.0 s | **0.04 s** |

- **0.8.2** added the lookahead; no change at the start, where time was
  short, not notice.
- **0.8.3** stopped preparing stages the car is already past: two sentences
  (9.1 s of synthesis) that were never spoken.
- **2e65a6f** plays a prepared sentence at once instead of after the
  sentence being synthesized.
- The first sentence is synthesized when the route is set (5.8 s in the last
  run); how late it comes depends on how soon the car moves. The 15 s in
  `frankfurt.demo` cover it.

### Decisions from the measurements

- **thorsten-medium stays the default:** on the way it is in time and the map
  does not notice it. thorsten-low would be the fallback if it got tight.
- **No second thread:** two threads are about 1.7 times as fast, not 2, would
  have cut the delays at the start only to 2–4.5 s (before 2e65a6f), and
  in the first measurement (unpinned) the UI thread waited 16.7 ms/s with
  two threads against 6.6 with one. Dropped (Michael, 2026-10-06).
- Clips recorded in advance (variant A) were the low-risk alternative; real
  speech (variant B) was chosen after the first measurement (Michael,
  2026-10-06).
