# 22 – Waveshare 1024x600 Display under Full KMS

**Status:** verified on hardware, 2026-09-22 (Raspberry Pi 4 Model B, Debian 13,
kernel 6.18.50, Waveshare 7" HDMI LCD (H)). Re-verified the same day over a cold
boot with the running carnine stack (Plymouth + flutter-pi): no EDID or mode
errors in `dmesg`, `fb0` and the flutter-pi scanout plane both at 1024x600,
touch working.

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
[`resources/debos/edid/waveshare-1024x600.bin`](../resources/debos/edid/waveshare-1024x600.bin)
and installed by the debos recipe. To regenerate it from a connected panel:

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
`hdmi_group`, `hdmi_mode` and `hdmi_cvt` lines are dropped. `cmdline.txt` gets:

```
drm.edid_firmware=HDMI-A-1:edid/waveshare-1024x600.bin
```

**Watch the parameter name.** The older `drm_kms_helper.edid_firmware` is
silently ignored by current kernels — the only hint is
`drm_kms_helper: unknown parameter 'edid_firmware' ignored` in `dmesg`. It now
lives under `drm.edid_firmware`.

**Keep `disable_fw_kms_setup=1`.** pi-gen's `config.txt` ships that line, and
the fkms variant of the recipe used to delete it. Without it the VideoCore
firmware prepends its own `video=HDMI-A-1:...` to the kernel command line — on
this panel `720x576M@50`. The connector still ends up at 1024x600 once
flutter-pi sets its mode, but `fb0` and with it the Plymouth splash stay at the
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
install_items+=" /usr/lib/firmware/edid/waveshare-1024x600.bin "
```

followed by `dracut --regenerate-all --force`. Check with
`lsinitrd /boot/firmware/initramfs8 | grep edid`.

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
connector may still report 1024x600 because flutter-pi sets that mode itself.

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
name stays `LEN L1950wD`, because only the timings were corrected.

## Touch input

The touch controller needs no configuration. On the test unit it enumerates
over USB as `WaveShare WS170120` (USB ID `0eef:0005`, eGalax) with
`INPUT_PROP_DIRECT` (`PROP=2` in `/proc/bus/input/devices`). flutter-pi opens
the event node itself through its libinput/udev seat0 path, without any extra
rule. At the native mode, touch and image coordinates map one to one.
