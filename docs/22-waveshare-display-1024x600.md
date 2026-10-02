# 22 – Waveshare 1024x600 Display under Full KMS

**Status:** verified on hardware, 2026-09-22 (Raspberry Pi 4 Model B, Debian 13,
kernel 6.18.50, Waveshare 7" HDMI LCD (H)). Re-verified the same day over a cold
boot with the running carnine stack (Plymouth + flutter-pi): no EDID or mode
errors in `dmesg`, `fb0` and the flutter-pi scanout plane both at 1024x600,
touch working. (Verified under flutter-pi; since ADR-020 the frontend runs
under ivi-homescreen, which sets the mode and reads touch the same way.)

**Result:** the panel runs at its native 1024x600 with `dtoverlay=vc4-kms-v3d`.
Neither `vc4-fkms-v3d` nor the `hdmi_cvt` / `hdmi_mode` lines are needed.

## Why this matters

Firmware KMS (`vc4-fkms-v3d`) does not offer atomic modeset, overlay planes and
explicit sync in the same way full KMS does. The ivi-homescreen runtime
evaluated in [19 – ivi-homescreen Evaluation](19-ivi-homescreen-evaluation.md)
uses its `drm-kms-egl` backend on exactly those features. Staying on full KMS
keeps that option open.

## The problem

The panel ships a **cloned EDID**. It identifies itself as a Lenovo monitor —
vendor code `LEN`, name `LEN L1950wD`, year 2011, image size 41 x 26 cm (that
would be a 19" screen), serial number `0x01010101`. Only the first detailed
timing block carries the panel's real values:

```
1024x600, pixel clock 49000 kHz
h: active 1024, front porch 5, sync width 13, total 1312
v: active  600, front porch 2, sync width  3, total  622
```

That gives `hsync_start = 1024 + 5 = 1029`, which is **odd**. The HDMI
controller of the Pi 4 (bcm2711) cannot drive odd horizontal timings; the vc4
driver marks this as `unsupported_odd_h_timings` and rejects the mode:

```
vc4-drm gpu: [drm] User-defined mode not supported:
"1024x600": 60 49000 1024 1029 1042 1312 600 602 605 622
```

`/sys/class/drm/card*-HDMI-A-1/modes` then contains **no** 1024x600 entry at
all. The driver falls back to the 1920x1080 modes from the cloned EDID's CEA
extension block, the panel receives 1920x1080 and scales it down itself. There
is a picture, but a soft one, and any small text — map labels, status rows —
becomes unreadable.

Forcing the mode on the kernel command line does not help:
`video=HDMI-A-1:1024x600M@60D` produces the very same timings and is rejected
for the very same reason. `MR` (reduced blanking) does not change the
calculation either.

## The fix: override the EDID with even timings

Two bytes in the detailed timing block are enough — front porch 5 → 6 and sync
width 13 → 12:

```
hsync_start = 1030  (even)
hsync_end   = 1042  (even)
htotal      = 1312  (unchanged)
```

Pixel clock and refresh rate stay identical, the image shifts by one pixel.
Everything else in the EDID is left untouched, including the cloned vendor
strings — the driver only needs valid timings.

The resulting blob is checked in at
[`resources/debos/edid/waveshare-1024x600.bin`](../resources/debos/edid/waveshare-1024x600.bin).
Since 2026-09-29 the image uses Waveshare's own EDID instead,
[`resources/debos/edid/waveshare-7h-260929.bin`](../resources/debos/edid/waveshare-7h-260929.bin)
(256 bytes, sha256 `07ee8b83…3edd`): the same CEA block with audio, 1024x600 at
59.82 Hz with even horizontal timings, and the real image size of 154 x 86 mm.
It was checked on jeep-pi (sharp image, sound on card 0). Our blob stays in the
image as a fallback; to go back, change the file name in `cmdline.txt`.
To regenerate our blob from a connected panel:

```python
e = bytearray(open("/sys/class/drm/card1-HDMI-A-1/edid", "rb").read())
d = 54                      # first detailed timing block
e[d + 8] = 6                # front porch 5 -> 6
e[d + 9] = 12               # sync width 13 -> 12
s = 0
for i in range(127):
    s = (s + e[i]) & 0xFF
e[127] = (256 - s) & 0xFF   # recompute block 0 checksum
open("waveshare-1024x600.bin", "wb").write(bytes(e))
```

## Image configuration

`config.txt` keeps `dtoverlay=vc4-kms-v3d`; the `hdmi_force_hotplug`,
`hdmi_group`, `hdmi_mode` and `hdmi_cvt` lines are dropped. When the image is
built with `-t display:waveshare-1024x600` (the default is `auto`),
`cmdline.txt` gets:

```
drm.edid_firmware=HDMI-A-1:edid/waveshare-7h-260929.bin
```

**Watch the parameter name.** The older `drm_kms_helper.edid_firmware` is
silently ignored by current kernels — the only hint is
`drm_kms_helper: unknown parameter 'edid_firmware' ignored` in `dmesg`. It now
lives under `drm.edid_firmware`.

**Keep `disable_fw_kms_setup=1`.** pi-gen's `config.txt` ships that line, and
the fkms variant of the recipe used to delete it. Without it the VideoCore
firmware prepends its own `video=HDMI-A-1:...` to the kernel command line — on
this panel `720x576M@50`. The connector still ends up at 1024x600 once
the embedder (then flutter-pi, now ivi-homescreen) sets its mode, but `fb0` and with it the Plymouth splash stay at the
firmware's mode for the whole boot.

### The blob has to be in the initramfs, not just in the rootfs

`/lib/firmware/edid/` alone is **not** enough. Dracut pulls `vc4.ko` into the
initramfs for the Plymouth splash, so the driver probes and asks for the EDID
while the initramfs is still the root filesystem:

```
vc4-drm gpu: Direct firmware load for edid/waveshare-1024x600.bin failed with error -2
vc4-drm gpu: [drm] *ERROR* [CONNECTOR:35:HDMI-A-1] Requesting EDID firmware
             "edid/waveshare-1024x600.bin" failed (err=-2)
```

The override then only takes effect on a later re-probe, after the real root is
mounted — the panel runs the whole early boot in the fallback mode, and the
result depends on something re-detecting the connector. The recipe therefore
also puts the blob into the initramfs:

```
# /etc/dracut.conf.d/carnine-edid.conf
install_items+=" /usr/lib/firmware/edid/waveshare-7h-260929.bin /usr/lib/firmware/edid/waveshare-1024x600.bin "
```

followed by `dracut --regenerate-all --force`. Check with
`lsinitrd /boot/firmware/initramfs8 | grep edid`.

Both files go into the initramfs, so switching between them in `cmdline.txt`
needs no `dracut` run.

## Verification after boot

```bash
head -1 /sys/class/drm/card1-HDMI-A-1/modes   # -> 1024x600
cat /sys/class/graphics/fb0/virtual_size      # -> 1024,600
dmesg | grep "not supported"                  # -> no output
dmesg | grep "Requesting EDID firmware"       # -> no output (blob in initramfs)
dmesg | grep -m1 "Kernel command line"        # -> no firmware-injected video=
```

`fb0` at 1024x600 is the tell-tale for the two mistakes above: it stays at the
firmware's mode when `disable_fw_kms_setup=1` is missing, and it starts in the
fallback mode when the blob is missing from the initramfs — in both cases the
connector may still report 1024x600 because the embedder sets that mode itself.

Under the running frontend, `/sys/kernel/debug/dri/1/state` shows the scanout
plane at the native size:

```
plane[91]: plane-3
	crtc=pixelvalve-2
		allocated by = io.flutter.rast
		size=1024x600
```

ivi-homescreen then reports `mode=1024x600@60Hz` and
`Display metadata: 1024x600 logical -> 1024x600 px, pixel_ratio=1`. The panel
name stays `LEN L1950wD` with both blobs: in ours only the timings were
corrected, and Waveshare's `waveshare-7h-260929.bin` carries the same name.

## Reading a panel's own EDID

For another panel, such as the Waveshare 7C, we need its own EDID to decide
whether it needs an override and which one. As long as `drm.edid_firmware` is
set, sysfs shows the override file, not the panel, so the override has to go
first. The display must be on **HDMI 0** (on the Pi 4 the port next to USB-C),
the only connector the override and the path below refer to; the Pi 3 has only
this one.

1. Keep a copy of the command line:
   `sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak`
2. In `/boot/firmware/cmdline.txt` (a single line) delete the whole
   ` drm.edid_firmware=HDMI-A-1:edid/…` part, **whatever file name follows**:
   images up to v0.9.1 set `waveshare-1024x600.bin`, from v0.9.2 (24cfd6d)
   `waveshare-7h-260929.bin`. Reboot.
3. Note whether the image is sharp.
4. Save the EDID and the kernel's view of it (`dmesg` needs root on Debian,
   `kernel.dmesg_restrict=1`):
   ```bash
   cat /sys/class/drm/card*-HDMI-A-1/edid > ~/edid-panel.bin
   sudo dmesg | grep -iE "edid|not supported" > ~/edid-panel-dmesg.txt
   ```
5. Restore: `sudo cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt`
   and reboot.

Without the override the image may be soft or, at worst, black. Without a
picture and without SSH, put the SD card into a PC: the small **FIRMWARE**
partition is FAT and opens on Windows too. Delete `cmdline.txt` there and
rename `cmdline.txt.bak` to `cmdline.txt`.

Both override files in the image announce HDMI audio. On a panel without
speakers (the 7C) the Pi therefore sends sound over HDMI into nothing, with no
error anywhere. Such a panel needs the sound on the Pi's jack, see
[Ton über die Klinke](bedienung/ton-klinke.md) in the user guide and "Audio
output" in [07 – Deployment](07-deployment.md#audio-output).

## Waveshare 7C

A tester's Waveshare 7C (no speakers) was read out with the steps above on
2026-10-02 (`edid-panel-carnine-pc-843d.bin`, 128 bytes, sha256
`727d3e18…7c35`). Its own EDID is quite different from the 7H's:

| | 7C (own EDID) | 7H (`waveshare-7h-260929.bin`) |
|---|---|---|
| Size | 128 bytes, **no extension block** | 256 bytes, CEA extension |
| Vendor, product | `ADA`, 0x0004, year 2007 | `LEN`, `LEN L1950wD`, year 2011 (cloned) |
| Audio | none announced (no CEA block) | HDMI audio announced |
| Pixel clock | 49.00 MHz | 50.25 MHz |
| Horizontal | 1024 + 48 + 96, total 1312 | 1024 + 44 + 88, total 1344 |
| Vertical | 600 + 3 + 10, total 624 | 600 + 3 + 6, total 625 |
| Refresh | 59.85 Hz | 59.82 Hz |
| Sync polarity | −h −v | −h +v |
| Image size | 154 x 86 mm | 154 x 86 mm |
| Name, range descriptors | none (three empty descriptors) | name, range limits, serial |

What follows from the EDID alone (not yet checked on a 7C):

- **The timings are usable as they are.** All horizontal values are even
  (`hsync_start` 1072, `hsync_end` 1168, `htotal` 1312), so the vc4 driver's
  odd-timing check that rejected the 7H's cloned EDID does not apply. The 7C
  should run at 1024x600 with no `drm.edid_firmware` at all.
- **No HDMI audio.** Without a CEA block the Pi treats the panel as a DVI
  sink and announces no audio, which matches a panel without speakers.
  Sound belongs on the jack ([Ton über die Klinke](bedienung/ton-klinke.md),
  or the `waveshare-jack` image).
- **The image currently forces the 7H's timings on the 7C.** With
  `display:waveshare-1024x600` it sends 50.25 MHz and a total of 1344 x 625
  instead of the 7C's own 49 MHz and 1312 x 624, and the opposite vertical
  sync polarity. The tester reports a flickering picture on the 7C; whether
  these timings are the cause is open.

Still to check on a 7C: whether the picture is sharp and steady with its own
EDID (override removed), and with the 7H override for comparison;
`/sys/class/drm/card*-HDMI-A-1/modes`, `fb0` and `dmesg` as under
"Verification after boot". The dmesg capture of step 4 did not come with the
EDID file.

## Touch input

The touch controller needs no configuration. On the test unit it enumerates
over USB as `WaveShare WS170120` (USB ID `0eef:0005`, eGalax) with
`INPUT_PROP_DIRECT` (`PROP=2` in `/proc/bus/input/devices`). The embedder
(flutter-pi when this was verified, ivi-homescreen now) opens the event node itself through its libinput/udev seat0 path, without any extra
rule. At the native mode, touch and image coordinates map one to one.
