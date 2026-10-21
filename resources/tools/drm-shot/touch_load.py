#!/usr/bin/env python3
"""A virtual touch panel over /dev/uinput: single taps, or map load for the
freeze soak test (rounds of strong swipes and two-finger zooms).

Usage: sudo python3 touch_load.py [pause_s]     rounds, 20 s apart by default
       sudo python3 touch_load.py tap X Y       one tap (panel 0..1023/0..599)
       sudo python3 touch_load.py hold X Y S [COMMAND]
                                    press, run COMMAND while held (e.g. a
                                    picture), release after S seconds
Every round is logged with its UTC time to ~/freeze/load.log of the user
behind sudo (TOUCH_LOAD_LOG overrides).

Each call creates a new input device; the frontend keeps one file descriptor
per device it has seen. For many taps or long runs use touchplay (one
process, resources/tools/demo/).
"""
import fcntl
import os
import random
import struct
import sys
import time

EV_SYN, EV_KEY, EV_ABS = 0x00, 0x01, 0x03
SYN_REPORT = 0
BTN_TOUCH = 0x14A
ABS_X, ABS_Y = 0x00, 0x01
ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = \
    0x2F, 0x35, 0x36, 0x39
INPUT_PROP_DIRECT = 0x01
MAX_X, MAX_Y = 1023, 599

UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_SET_ABSBIT = 0x40045567
UI_SET_PROPBIT = 0x4004556E
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502


def log_path(environ=os.environ):
    if 'TOUCH_LOAD_LOG' in environ:
        return environ['TOUCH_LOAD_LOG']
    home = os.path.expanduser('~' + environ.get('SUDO_USER', ''))
    return os.path.join(home, 'freeze', 'load.log')


def user_dev(name=b'freeze-soak-touch'):
    """struct uinput_user_dev: name[80], input_id (4 x u16), ff_effects_max,
    absmax[64], absmin[64], absfuzz[64], absflat[64]."""
    absmax = [0] * 64
    absmax[ABS_X] = absmax[ABS_MT_POSITION_X] = MAX_X
    absmax[ABS_Y] = absmax[ABS_MT_POSITION_Y] = MAX_Y
    absmax[ABS_MT_SLOT] = 1
    absmax[ABS_MT_TRACKING_ID] = 65535
    dev = struct.pack('80sHHHHi', name, 0x03, 0x1234, 0x5678, 1, 0)
    dev += struct.pack('64i', *absmax)
    dev += struct.pack('64i', *([0] * 64)) * 3
    return dev


def open_device():
    fd = os.open('/dev/uinput', os.O_WRONLY | os.O_NONBLOCK)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
    fcntl.ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH)
    fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
    for code in (ABS_X, ABS_Y, ABS_MT_SLOT, ABS_MT_POSITION_X,
                 ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID):
        fcntl.ioctl(fd, UI_SET_ABSBIT, code)
    fcntl.ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
    os.write(fd, user_dev())
    fcntl.ioctl(fd, UI_DEV_CREATE)
    time.sleep(1.5)  # libinput picks the device up
    return fd


def close_device(fd):
    fcntl.ioctl(fd, UI_DEV_DESTROY)
    os.close(fd)


def input_event(etype, code, value, t=None):
    """struct input_event on a 64-bit kernel (timeval, type, code, value)."""
    t = time.time() if t is None else t
    return struct.pack('llHHi', int(t), int((t % 1) * 1e6), etype, code,
                       value)


def frame_events(fingers):
    """Events of one frame. fingers: (slot, tracking_id, x, y) for a finger
    on the panel, (slot, -1) to lift it."""
    ev = []
    for f in fingers:
        ev.append((EV_ABS, ABS_MT_SLOT, f[0]))
        if f[1] < 0:
            ev.append((EV_ABS, ABS_MT_TRACKING_ID, -1))
        else:
            ev.append((EV_ABS, ABS_MT_TRACKING_ID, f[1]))
            ev.append((EV_ABS, ABS_MT_POSITION_X, int(f[2])))
            ev.append((EV_ABS, ABS_MT_POSITION_Y, int(f[3])))
    down = [f for f in fingers if f[1] >= 0]
    ev.append((EV_KEY, BTN_TOUCH, 1 if down else 0))
    if down:
        ev.append((EV_ABS, ABS_X, int(down[0][2])))
        ev.append((EV_ABS, ABS_Y, int(down[0][3])))
    ev.append((EV_SYN, SYN_REPORT, 0))
    return ev


def frame(fd, fingers):
    os.write(fd, b''.join(input_event(*e) for e in frame_events(fingers)))


_tid = 0


def next_id():
    global _tid
    _tid = (_tid + 1) % 60000
    return _tid


def swipe(fd, x0, y0, x1, y1, steps=40, dt=0.012):
    tid = next_id()
    for i in range(steps + 1):
        a = i / steps
        frame(fd, [(0, tid, x0 + (x1 - x0) * a, y0 + (y1 - y0) * a)])
        time.sleep(dt)
    frame(fd, [(0, -1)])
    time.sleep(0.05)


def pinch(fd, cx, cy, r0, r1, steps=40, dt=0.012):
    t0, t1 = next_id(), next_id()
    for i in range(steps + 1):
        r = r0 + (r1 - r0) * i / steps
        frame(fd, [(0, t0, cx - r, cy), (1, t1, cx + r, cy)])
        time.sleep(dt)
    frame(fd, [(0, -1), (1, -1)])
    time.sleep(0.05)


def main(argv):
    if len(argv) >= 4 and argv[0] == 'hold':
        fd = open_device()
        x, y, sec = float(argv[1]), float(argv[2]), float(argv[3])
        frame(fd, [(0, next_id(), x, y)])
        time.sleep(sec)
        if len(argv) > 4:
            import subprocess
            subprocess.run(argv[4], shell=True)
        frame(fd, [(0, -1)])
        time.sleep(0.5)
        close_device(fd)
        return
    if len(argv) == 3 and argv[0] == 'tap':
        fd = open_device()
        x, y = float(argv[1]), float(argv[2])
        swipe(fd, x, y, x, y, steps=3, dt=0.03)
        time.sleep(0.5)
        close_device(fd)
        return
    pause = float(argv[0]) if argv else 20.0
    # Work in the map area only: leave out the top bar and the navigation on
    # the left of the carnine user interface.
    xmin, xmax, ymin, ymax = 250, 950, 150, 520
    log = log_path()
    os.makedirs(os.path.dirname(log), exist_ok=True)
    fd = open_device()
    rounds = 0
    try:
        while True:
            rounds += 1
            for _ in range(6):
                x0, y0 = random.uniform(xmin, xmax), random.uniform(ymin, ymax)
                x1, y1 = random.uniform(xmin, xmax), random.uniform(ymin, ymax)
                swipe(fd, x0, y0, x1, y1, steps=random.randint(15, 40))
            cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2
            for _ in range(3):
                pinch(fd, cx, cy, 60, 250)   # zoom in
                pinch(fd, cx, cy, 250, 60)   # zoom out
            with open(log, 'a') as f:
                f.write(f"{time.strftime('%F %T', time.gmtime())} "
                        f"round={rounds}\n")
            time.sleep(pause)
    finally:
        close_device(fd)


if __name__ == '__main__':
    main(sys.argv[1:])
