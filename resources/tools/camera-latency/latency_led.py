#!/usr/bin/env python3
"""Latency Pi LED -> USB camera -> (carnine) -> picture, without a person.

The camera looks at the Pi's green ACT LED. The tool switches it on and off
at irregular intervals and looks for the change in the pictures:

  raw      frames straight from the USB camera (v4l2-ctl, YUYV);
           stop carnine-frontend first.
  display  the camera picture carnine has on the display output right now
           (KMS plane in format NV16, polled every ~2 ms); carnine runs on
           the camera page.

First 6 s of calibration: the pixels that change most with the LED form the
mask. Then the measurement; latency = first frame after the switch whose
mean over the mask crosses the threshold in the new direction.

Usage: sudo python3 latency_led.py raw|display [--dev /dev/video0]
           [--size 640x480] [--led /sys/class/leds/ACT] [--secs 60]
           [--out PREFIX]
"""
import argparse
import ctypes
import ctypes.util
import mmap
import os
import random
import subprocess
import sys
import threading
import time

try:
    import numpy as np
except ImportError:  # only main() and led_mask() need it
    np = None

import latency

NV16 = 0x3631564e
MASK_POINTS = 200


def current_trigger(text):
    """Active trigger from the content of an LED's trigger file."""
    return text.split('[')[1].split(']')[0]


class Led:
    """Takes the LED from its trigger and gives it back on close()."""

    def __init__(self, path):
        self.path = path
        with open(path + '/trigger') as f:
            self.old = current_trigger(f.read())
        with open(path + '/trigger', 'w') as f:
            f.write('none')
        self.f = open(path + '/brightness', 'w')

    def set(self, on):
        self.f.write('1' if on else '0')
        self.f.flush()
        return time.monotonic()

    def close(self):
        self.set(False)
        self.f.close()
        with open(self.path + '/trigger', 'w') as f:
            f.write(self.old)


def calibration_frames(calib, marks, settle=0.25, hold=0.5):
    """(frames with LED on, frames with LED off) from the calibration.

    calib: [(time_s, frame)], marks: [(time_s, on)]. A frame counts for a
    mark when it arrived between `settle` and `hold` s after it.
    """
    on, off = [], []
    for t, y in calib:
        for a, state in marks:
            if a + settle < t < a + hold:
                (on if state else off).append(y)
                break
    return on, off


def led_mask(on, off, points=MASK_POINTS):
    """Boolean mask of the `points` pixels that get brightest with the LED."""
    diff = np.mean(on, axis=0).astype(np.float32) - np.mean(off, axis=0)
    limit = np.sort(diff.ravel())[-points]
    return diff >= limit, diff


def parse_size(text):
    w, h = text.lower().split('x')
    return int(w), int(h)


def raw_frames(args, stop, sink):
    """Y plane (height x width) of each camera frame, with arrival time."""
    width, height = args.size
    proc = subprocess.Popen(
        ['v4l2-ctl', '-d', args.dev,
         f'--set-fmt-video=width={width},height={height},pixelformat=YUYV',
         '--stream-mmap=4', '--stream-to=-'],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    size = width * height * 2
    buf = bytearray(size)
    view = memoryview(buf)
    try:
        while not stop.is_set():
            got = 0
            while got < size:
                n = proc.stdout.readinto(view[got:])
                if not n:
                    return
                got += n
            t = time.monotonic()
            sink(t, np.frombuffer(buf, np.uint8)[0::2].reshape(height, width))
    finally:
        proc.kill()


# --- KMS: the picture on the video plane right now ---------------------------

class PlaneRes(ctypes.Structure):
    _fields_ = [('count_planes', ctypes.c_uint32),
                ('planes', ctypes.POINTER(ctypes.c_uint32))]


class Plane(ctypes.Structure):
    _fields_ = [('count_formats', ctypes.c_uint32),
                ('formats', ctypes.POINTER(ctypes.c_uint32)),
                ('plane_id', ctypes.c_uint32), ('crtc_id', ctypes.c_uint32),
                ('fb_id', ctypes.c_uint32), ('crtc_x', ctypes.c_uint32),
                ('crtc_y', ctypes.c_uint32), ('x', ctypes.c_uint32),
                ('y', ctypes.c_uint32), ('possible_crtcs', ctypes.c_uint32),
                ('gamma_size', ctypes.c_uint32)]


class FB2(ctypes.Structure):
    _fields_ = [('fb_id', ctypes.c_uint32), ('width', ctypes.c_uint32),
                ('height', ctypes.c_uint32), ('pixel_format', ctypes.c_uint32),
                ('modifier', ctypes.c_uint64), ('flags', ctypes.c_uint32),
                ('handles', ctypes.c_uint32 * 4),
                ('pitches', ctypes.c_uint32 * 4),
                ('offsets', ctypes.c_uint32 * 4)]


def open_card(drm, cards):
    """First card with planes (vc4 is card0 or card1 depending on boot)."""
    for card in cards:
        try:
            fd = os.open(card, os.O_RDWR | os.O_CLOEXEC)
        except OSError:
            continue
        drm.drmSetClientCap(fd, 2, 1)  # DRM_CLIENT_CAP_UNIVERSAL_PLANES
        if drm.drmModeGetPlaneResources(fd):
            return fd
        os.close(fd)
    sys.exit(f'no DRM card with planes in {", ".join(cards)}')


def scanout_frames(args, stop, sink):
    """Y plane of each new NV16 framebuffer on any plane, with time seen."""
    drm = ctypes.CDLL(ctypes.util.find_library('drm') or 'libdrm.so.2')
    drm.drmModeGetPlaneResources.restype = ctypes.POINTER(PlaneRes)
    drm.drmModeGetPlane.restype = ctypes.POINTER(Plane)
    drm.drmModeGetFB2.restype = ctypes.POINTER(FB2)
    fd = open_card(drm, [args.card] if args.card
                   else ['/dev/dri/card0', '/dev/dri/card1'])
    res = drm.drmModeGetPlaneResources(fd)
    plane_ids = [res.contents.planes[i] for i in range(res.contents.count_planes)]
    maps = {}  # fb_id -> (mmap, pitch, offset, width, height) or None
    last = None
    while not stop.is_set():
        for pid in plane_ids:
            p = drm.drmModeGetPlane(fd, pid)
            if not p or not p.contents.fb_id:
                continue
            fb_id = p.contents.fb_id
            if fb_id not in maps:
                fb = drm.drmModeGetFB2(fd, fb_id)
                if not fb or fb.contents.pixel_format != NV16:
                    maps[fb_id] = None
                    continue
                fbc = fb.contents
                prime = ctypes.c_int()
                drm.drmPrimeHandleToFD(fd, fbc.handles[0],
                                       os.O_CLOEXEC | os.O_RDWR,
                                       ctypes.byref(prime))
                size = os.lseek(prime.value, 0, os.SEEK_END)
                m = mmap.mmap(prime.value, size, mmap.MAP_SHARED,
                              mmap.PROT_READ)
                maps[fb_id] = (m, fbc.pitches[0], fbc.offsets[0],
                               fbc.width, fbc.height)
            entry = maps[fb_id]
            if entry is None or fb_id == last:
                continue
            t = time.monotonic()
            m, pitch, off, w, h = entry
            y = np.frombuffer(m, np.uint8, count=pitch * h, offset=off)
            sink(t, y.reshape(h, pitch)[:, :w])
            last = fb_id
        time.sleep(0.002)


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('mode', choices=['raw', 'display'])
    ap.add_argument('--dev', default='/dev/video0', help='USB camera (raw)')
    ap.add_argument('--size', type=parse_size, default=(640, 480),
                    help='camera frame size (raw)')
    ap.add_argument('--card', default=None,
                    help='DRM card (display), default card0 or card1')
    ap.add_argument('--led', default='/sys/class/leds/ACT')
    ap.add_argument('--secs', type=float, default=60)
    ap.add_argument('--out', default=None,
                    help='write PREFIX.txt, PREFIX.csv and PREFIX-raw.csv')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if np is None:
        sys.exit('needs python3-numpy')

    led = Led(args.led)
    stop = threading.Event()
    calib, frames = [], []
    mask = [None]
    calibrating = [True]

    def sink(t, y):
        if calibrating[0]:
            calib.append((t, y[::2, ::2].copy()))
        elif mask[0] is not None:
            frames.append((t, float(y[::2, ::2][mask[0]].mean())))

    src = raw_frames if args.mode == 'raw' else scanout_frames
    threading.Thread(target=src, args=(args, stop, sink), daemon=True).start()
    toggles = []
    try:
        # calibration: 0.5 s on, 0.5 s off, six times
        marks = []
        time.sleep(1)
        for i in range(12):
            marks.append((led.set(i % 2 == 0), i % 2 == 0))
            time.sleep(0.5)
        on, off = calibration_frames(calib, marks)
        if len(on) < 3 or len(off) < 3:
            sys.exit(f'too few frames to calibrate ({len(calib)})')
        mask[0], diff = led_mask(on, off)
        print(f'calibration: {len(calib)} frames, mask {MASK_POINTS} points, '
              f'brightness difference {diff[mask[0]].mean():.0f}')
        calibrating[0] = False
        state = False
        time.sleep(0.5)
        end = time.monotonic() + args.secs
        while time.monotonic() < end:
            state = not state
            toggles.append((led.set(state), state))
            time.sleep(random.uniform(0.5, 0.9))
        time.sleep(0.8)
    finally:
        stop.set()
        led.close()

    text, lat = latency.evaluate(args.mode, frames, toggles,
                                 levels=('LED off', 'on'))
    print(text)
    if args.out:
        latency.write_results(args.out, text, frames, toggles, lat)


if __name__ == '__main__':
    main()
