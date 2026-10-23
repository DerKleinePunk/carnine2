#!/usr/bin/env python3
"""Latency panel -> camera -> analog grabber -> Pi, without a person.

The camera looks at the panel. The tool turns the panel black and white
through the framebuffer (at irregular intervals, so nothing locks to the
frame rate) and reads the grabber's raw frames at the same time. For each
switch it takes the first frame whose share of bright pixels crosses the
threshold in the new direction.

Measured is panel + camera + grabber + driver, without carnine. The panel is
the same for every grabber, so the difference between two runs is the
difference between the grabbers.

Stop carnine-frontend first, the panel must be free.

Usage:
  sudo python3 latency_panel.py somagic [--input 1] [--somagic-capture PATH]
  sudo python3 latency_panel.py v4l2 [--dev /dev/video0]
  common: [--norm ntsc|pal] [--fb /dev/fb0] [--secs 60] [--out PREFIX]
The Somagic grabber needs its firmware loaded (somagic-init) and
somagic-capture from PATH, from --somagic-capture or from $SOMAGIC_CAPTURE.
"""
import argparse
import os
import random
import subprocess
import sys
import threading
import time

try:
    import numpy as np
except ImportError:  # only main() and bright_permille() need it
    np = None

import latency

WIDTH = 720


def frame_geometry(norm):
    """(width, height, bytes per frame) of a UYVY frame."""
    height = 480 if norm == 'ntsc' else 576
    return WIDTH, height, WIDTH * height * 2


def capture_command(args, width, height):
    """Command that writes raw UYVY frames to stdout."""
    if args.kind == 'somagic':
        return [args.somagic_capture, '-c', '-i', str(args.input)] + (
            ['-n'] if args.norm == 'ntsc' else [])
    return ['v4l2-ctl', '-d', args.dev,
            f'--set-fmt-video=width={width},height={height},pixelformat=UYVY',
            '--stream-mmap=4', '--stream-to=-']


def fb_bytes(virtual_size, stride):
    """Bytes of the visible framebuffer from its sysfs files.

    virtual_size: content of virtual_size ("1024,600"), stride: of stride.
    """
    height = int(virtual_size.strip().split(',')[1])
    return int(stride.strip()) * height


def read_fb_bytes(fb):
    sysfs = f'/sys/class/graphics/{os.path.basename(fb)}'
    with open(sysfs + '/virtual_size') as v, open(sysfs + '/stride') as s:
        return fb_bytes(v.read(), s.read())


def bright_permille(y):
    """Share of bright pixels (> 200) in promille, every second pixel.

    Over the whole frame: it does not matter where the panel lies in the
    picture or whether the picture slips sideways.
    """
    return float((y[::2, ::2] > 200).mean() * 1000)


def reader(proc, width, height, frames, stop):
    """Reads whole frames, keeps arrival time and bright share."""
    size = width * height * 2
    buf = bytearray(size)
    view = memoryview(buf)
    while not stop.is_set():
        got = 0
        while got < size:
            n = proc.stdout.readinto(view[got:])
            if not n:
                return
            got += n
        t = time.monotonic()
        y = np.frombuffer(buf, np.uint8)[1::2].reshape(height, width)  # UYVY
        frames.append((t, bright_permille(y)))


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('kind', choices=['somagic', 'v4l2'])
    ap.add_argument('--input', type=int, default=1,
                    help='Somagic input (1 = CVBS)')
    ap.add_argument('--somagic-capture',
                    default=os.environ.get('SOMAGIC_CAPTURE', 'somagic-capture'))
    ap.add_argument('--dev', default='/dev/video0', help='v4l2 grabber')
    ap.add_argument('--norm', choices=['ntsc', 'pal'], default='ntsc')
    ap.add_argument('--fb', default='/dev/fb0')
    ap.add_argument('--secs', type=float, default=60)
    ap.add_argument('--out', default=None,
                    help='write PREFIX.txt, PREFIX.csv and PREFIX-raw.csv')
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if np is None:
        sys.exit('needs python3-numpy')
    width, height, _ = frame_geometry(args.norm)

    size = read_fb_bytes(args.fb)
    fb = os.open(args.fb, os.O_RDWR)
    black, white = bytes(size), b'\xff' * size

    if args.kind == 'v4l2':
        subprocess.run(['v4l2-ctl', '-d', args.dev, '-s', args.norm],
                       capture_output=True)
    proc = subprocess.Popen(capture_command(args, width, height),
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            bufsize=0)
    frames, stop = [], threading.Event()
    threading.Thread(target=reader, args=(proc, width, height, frames, stop),
                     daemon=True).start()

    toggles = []
    try:
        os.pwrite(fb, black, 0)
        time.sleep(3)  # let camera and grabber settle
        bright = False
        end = time.monotonic() + args.secs
        while time.monotonic() < end:
            bright = not bright
            os.pwrite(fb, white if bright else black, 0)
            toggles.append((time.monotonic(), bright))
            time.sleep(random.uniform(0.6, 1.0))
        time.sleep(1)
    finally:
        stop.set()
        proc.kill()
        os.pwrite(fb, black, 0)
        os.close(fb)

    if len(frames) < 10:
        sys.exit(f'only {len(frames)} frames from the grabber')
    text, lat = latency.evaluate(args.kind, frames, toggles)
    print(text)
    if args.out:
        latency.write_results(args.out, text, frames, toggles, lat)


if __name__ == '__main__':
    main()
