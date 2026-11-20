# 27 – BIGTREETECH Pi2 (works, not tested regularly)

> **Works, but not tested regularly.** CarNine has run on one BIGTREETECH Pi2
> (2026-11-11 to 2026-11-15), set up by hand as described here. We do not
> test it with each release and do not build an image for it. The reference
> and the only released target stay the **Raspberry Pi 4** (docs/07). If a
> step below no longer fits, the Pi 4 is not affected.

**Last verified: 2026-11-15**

| | |
|---|---|
| CarNine | packages v0.20.1 (arm64), backend from 52ccc8f |
| System | Armbian 26.8.1 `bigtreetech-cb2`, trixie, current, kernel 6.18.44 |
| Boot | eMMC + NVMe (the Lite tried once, on 2026-11-15) |
| Device | one Pi2 with 2 GB RAM |

A newer CarNine or Armbian version is not verified until it is listed under
[Verified](#verified). Problems on the Pi2 go into a GitHub issue with the
label `pi2`.

The BIGTREETECH Pi2 is a board in the size of a Raspberry Pi with a Rockchip
RK3566, an M.2 slot for an NVMe SSD and an onboard eMMC. Our `.deb` packages
for arm64 run on it unchanged. What differs from the Pi 4 is the operating
system, the display timing, the sound card order and three pins.

## The board we tried

| | |
|---|---|
| SoC | Rockchip RK3566, GPU Mali-G52 (panfrost) |
| RAM | 2 GB |
| Storage | eMMC 29 GB, NVMe M.2 2242 (128 GB) |
| Network | Gigabit LAN, Wi-Fi/Bluetooth (BCM4345C5) |
| Display | Waveshare 7" HDMI LCD (H), 1024 × 600 |

On the board, right of the heat sink, a switch **EMMC-EN** turns the eMMC
off. **Its label reads the wrong way round.** We checked it by its effect: in
the position "eMMC off" the board does not start at all without an SD card.
Linux still sees the eMMC in that position (`mmc0: switch to bus width 8
failed`); that does no harm.

## Operating system

- **Armbian** for the board `bigtreetech-cb2` (the Pi2 uses the same image),
  Debian trixie, kernel branch "current", variant minimal. Tried with Armbian
  26.8.1 and kernel 6.18.44. Download:
  `https://dl.armbian.com/bigtreetech-cb2/Trixie_current_minimal`, checksum
  `.sha` next to it. The device tree `rockchip/rk3566-bigtreetech-pi2.dtb` is
  already set in that image.
- **Our SD-card image (debos, docs/07) does not run on the Pi2.** CarNine comes
  onto Armbian through the packages.
- **Write the Armbian image with balenaEtcher or Raspberry Pi Imager, not with
  Rufus.** Armbian's image uses GPT. After Rufus, 12 bytes of the first GPT
  header differed from the image (end moved to the card size, pointer to the
  entries on sector 2016 instead of 2). U-Boot fell back to the backup header,
  the Linux kernel did not, and stopped in `(initramfs)` with
  "UUID=… does not exist". Rewritten with `dd` from the same image, it booted.
  That Rufus did it is very likely, not proven. Our Pi 4 image uses MBR and is
  not affected; the user guide's Rufus steps stay valid for it.

### Three ways to boot

All three were tried on the device:

| Way | U-Boot and `/boot` | Root | Tried |
|---|---|---|---|
| eMMC | eMMC | eMMC | as delivered |
| **eMMC + NVMe** (recommended with eMMC) | eMMC | NVMe | 2026-11-11 to 15, CarNine ran this way |
| **Lite** (without eMMC) | SD card | NVMe | 2026-11-15, three restarts, and without the SD nothing starts |

**eMMC + NVMe:** install Armbian on the eMMC first, then move the root file
system to the NVMe by hand, while U-Boot and `/boot` stay on the eMMC.
`armbian-install` only offers `split-emmc` for this, and that erases the eMMC
as well. The steps we used:

1. Format a partition on the NVMe with ext4. Bind-mount the running root and
   copy it over with `rsync -aAXH --numeric-ids`.
2. In `/etc/fstab` **on the NVMe**: `/` on the NVMe's UUID; mount the eMMC
   partition on `/media/mmcboot` and bind `/boot` from `/media/mmcboot/boot`.
3. In `/boot/armbianEnv.txt` **on the eMMC** set `rootdev=UUID=<NVMe>`, then
   restart.

**Lite** (the way BIGTREETECH describes it, commands as in Armbian 26.8):

1. Write the image to an SD card (8 GB or more) with balenaEtcher or Raspberry
   Pi Imager.
2. Insert the SD, NVMe fitted (on a Pi2 with eMMC: EMMC-EN on "eMMC off"),
   power on. First login as `root` with password `1234`; Armbian asks for a
   new password, a user, the shell and the locale.
3. Look at the plan first, it changes nothing:
   `armbian-install --api plan --target /dev/nvme0n1 --boot sd --fs ext4`
   (expected: `table=msdos`, `part=root:100%:ext4:boot`).
4. `armbian-install --target /dev/nvme0n1 --boot sd --fs ext4 --yes`
   **erases the NVMe** (about 1.5 minutes). `/boot/armbianEnv.txt` on the SD
   then points `rootdev` to the NVMe.
5. Restart with the SD left in. Check: `findmnt /` shows `nvme0n1p1`,
   `findmnt /boot` the SD.

The mode is called `sd` ("Keep boot on current media, system on this disk").
Do not pick `split-emmc`: it erases the eMMC as well. Measured on the Lite
without CarNine: boot in 11.0 s (kernel 4.7 s, user space 6.2 s), ssh after
about 30 s.

An SD card inserted while the board runs is not detected by itself. Restart,
or unbind and bind the SD controller (`fe2b0000.mmc` under the
`dwmmc_rockchip` driver).

## Installing CarNine

- The packages of v0.20.1 for arm64 (`carnine-backend`, `carnine-frontend`,
  `carnine-valhalla`, `carnine-voice`) install unchanged with
  `apt install ./….deb`; apt pulls Mesa, ffmpeg, seatd and the rest.
- What the Pi 4 image does on top has to be done by hand: the user and group
  `carnine` (in `audio`, `render`, `video`, `input`), the folders below
  `/var/lib/carnine` and `/etc/carnine`, the configuration and the map data
  (docs/07, "Installation Steps", and the user guide, "Nach der Installation").
- Then the points in the next section.

## What is different from the Pi 4

| Topic | On the Pi2 | What to do |
|---|---|---|
| **Display** (Waveshare 1024 × 600) | The RK3566 cannot make the panel's pixel clock of 50.25 MHz; the mode is rejected (NOCLOCK). | Give the kernel an EDID with timings it can make: `waveshare-7h-74m-1980x625.bin` from the map library's repository, with the steps in its [`waveshare-1024x600-full-kms.md`, section "Rockchip RK3566"](https://github.com/DerKleinePunk/flutter_local_map/blob/master/docs/waveshare-1024x600-full-kms.md#rockchip-rk3566-bigtreetech-pi2) (the file goes into the initramfs, `extraargs=drm.edid_firmware=…` in `armbianEnv.txt`). |
| **Sound** | Card 1 is HDMI, card 0 the headphone jack. The backend sets the volume on card 0, control "PCM" (`audio_volume.rs`). | `/etc/asound.conf`: default output HDMI through a `softvol` control named "PCM" on card 0. Since #48 `[audio] output_card` can name the HDMI card instead (docs/07, "Choosing the output in the configuration"); not tried on the Pi2 yet. |
| **Camera** | `/dev/video0` is the hardware video codec, not a camera. | Set `[camera] device` in a drop-in to the grabber or webcam under `/dev/v4l/by-id/…`. |
| **Log folder** | `/var/log` is a RAM disk (armbian-ramlog). `/var/log/carnine` can be missing after a restart (we saw it twice), and then the backend does not start ("Permission denied"). From v0.21.0 the backend's systemd unit creates the folder itself before each start (`LogsDirectory=carnine`). For v0.20.1 and older: `/etc/tmpfiles.d/carnine-log.conf` with `d /var/log/carnine 0750 carnine carnine -`. |
| **Fan PWM** | Pin 12 has no PWM. | Pin 16 (GPIO4_C6, PWM13); needs an overlay, the channel `pwm@fe700010` is disabled in the device tree. Not tried with a fan. |
| **Power-supply UART** | Pins 32 and 33 swap TX and RX against the Pi 4. | Cross the two lines (wire or board option). Not tried. |
| **Power supply, IO board, clock** | Not connected. | Not tried. |

## What runs, and what we measured

With the eMMC + NVMe way and the replay tour:

- **Runs as on the Pi 4:** the UI full screen at 1024 × 600, 60 Hz, rendered
  on the GPU (panfrost), touch, navigation with Valhalla and the offline map,
  spoken turn announcements, music, and the lane data of the backend.
- **UI ready** 2.4 s after its service starts. After `reboot`, backend and UI
  come up by themselves, the first picture about 30 s later.
- **Memory:** 460 MB of 1.9 GB in use, no swap (backend 220 MB, frontend
  130 MB, Valhalla 80 MB).
- **Not measured:** the peak while zooming or routing, the time from a cold
  start to the first announcement, the synthesis time per sentence, and
  stutter while zooming.

## When it is checked again

Not with each release, and the Pi2 is not on the release checklist. It is
checked again when the maintainer asks for it, or when a change touches what
the Pi2 depends on: the packages and their dependencies, the systemd units,
the configuration format, display, sound or camera code, or a new Armbian or
Debian release.

The check takes about 15 minutes on the Pi2, boot way eMMC + NVMe only:

1. Install the packages of the version to check.
2. The UI comes up full screen at 1024 × 600.
3. Sound plays over HDMI.
4. Compute a route and hear an announcement.
5. Music plays.
6. Restart: backend and UI come up by themselves.
7. The backend's log shows no errors.

"Last verified" changes only after this list has passed. Each check adds a
row below; old rows stay.

### Verified

| Date | CarNine | Armbian, kernel | Boot | Result |
|---|---|---|---|---|
| 2026-11-15 | v0.20.1, backend 52ccc8f | 26.8.1, 6.18.44 | eMMC + NVMe | passed, points 1–6 spread over 2026-11-11 to 15, point 7 not checked separately; needs the tmpfiles line for the log folder. The Lite also booted (three restarts). |
