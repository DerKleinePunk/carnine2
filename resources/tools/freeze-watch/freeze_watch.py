#!/usr/bin/env python3
"""Freeze and heat watch for a Carnine device (carnine-pc, jeep-pi).

Once a minute it appends one line to the log: whether the picture on the
panel changed since the last minute, temperature, ARM clock, throttling,
load, memory of frontend and backend, and MemAvailable.

A frozen user interface is told by the picture: the top bar's clock changes
every minute, so two scanouts at least 60 s apart differ while the frontend
draws. Identical scanouts while the frontend runs mean it is frozen. The
earlier watch counted "LayerScene commit" in the frontend's journal, which
the release frontend no longer writes (blind since 2026-09-28).

Runs as root (the DRM handles of the scanout need CAP_SYS_ADMIN, vcgencmd
the video group); processes are found in /proc, so it works whether the
frontend runs as a systemd unit or was started by hand.

Usage: freeze_watch.py [LOG] [--interval SECONDS] [--once]
"""
import argparse
import ctypes
import ctypes.util
import glob
import hashlib
import mmap
import os
import subprocess
import sys
import time

DEFAULT_LOG = '/var/log/carnine-freeze-watch.log'
FRONTEND = 'homescreen'
BACKEND = 'carnine-backend'

XR24, AR24 = 0x34325258, 0x34325241


def scanout_digest(cards=None):
    """SHA-1 of the framebuffer on the panel, or None without one."""
    drm = ctypes.CDLL(ctypes.util.find_library('drm') or 'libdrm.so.2')

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
                    ('handles', ctypes.c_uint32 * 4), ('pitches', ctypes.c_uint32 * 4),
                    ('offsets', ctypes.c_uint32 * 4)]

    drm.drmModeGetPlaneResources.restype = ctypes.POINTER(PlaneRes)
    drm.drmModeGetPlane.restype = ctypes.POINTER(Plane)
    drm.drmModeGetFB2.restype = ctypes.POINTER(FB2)

    for card in cards or sorted(glob.glob('/dev/dri/card*')):
        fd = os.open(card, os.O_RDWR | os.O_CLOEXEC)
        try:
            drm.drmSetClientCap(fd, 2, 1)  # DRM_CLIENT_CAP_UNIVERSAL_PLANES
            res = drm.drmModeGetPlaneResources(fd)
            if not res:
                continue
            for i in range(res.contents.count_planes):
                plane = drm.drmModeGetPlane(fd, res.contents.planes[i])
                if not (plane and plane.contents.fb_id and plane.contents.crtc_id):
                    continue
                fb = drm.drmModeGetFB2(fd, plane.contents.fb_id)
                if not (fb and fb.contents.pixel_format in (XR24, AR24)
                        and fb.contents.handles[0]):
                    continue
                prime = ctypes.c_int()
                if drm.drmPrimeHandleToFD(fd, fb.contents.handles[0],
                                          os.O_CLOEXEC | os.O_RDWR, ctypes.byref(prime)):
                    continue
                try:
                    start = fb.contents.offsets[0]
                    size = start + fb.contents.pitches[0] * fb.contents.height
                    with mmap.mmap(prime.value, size, mmap.MAP_SHARED, mmap.PROT_READ) as m:
                        return hashlib.sha1(m[start:size]).hexdigest()
                finally:
                    os.close(prime.value)
        finally:
            os.close(fd)
    return None


def find_pid(name, proc='/proc'):
    """The oldest process whose comm is `name`, or None."""
    found = []
    for entry in os.listdir(proc):
        if not entry.isdigit():
            continue
        try:
            with open(os.path.join(proc, entry, 'comm')) as comm:
                if comm.read().strip() == name:
                    found.append(int(entry))
        except OSError:
            continue
    return min(found) if found else None


def rss_mb(pid, proc='/proc'):
    """Resident memory of `pid` in MB, 0 without the process."""
    if pid is None:
        return 0
    try:
        with open(os.path.join(proc, str(pid), 'status')) as status:
            for line in status:
                if line.startswith('VmRSS:'):
                    return int(line.split()[1]) // 1024
    except OSError:
        pass
    return 0


def mem_available_mb(meminfo='/proc/meminfo'):
    with open(meminfo) as info:
        for line in info:
            if line.startswith('MemAvailable:'):
                return int(line.split()[1]) // 1024
    return 0


def vcgencmd_value(output):
    """`temp=30.6'C` -> `30.6'C`; `frequency(48)=1500345728` -> `1500345728`."""
    return output.strip().partition('=')[2]


def vcgencmd(*args):
    try:
        out = subprocess.run(['vcgencmd', *args], capture_output=True, text=True,
                             timeout=5, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ''
    return vcgencmd_value(out)


def picture(previous, current, frontend_running, previous_running):
    """How the picture compares with the last minute, and whether that means
    frozen. Only a frontend running in both samples can be frozen."""
    if current is None:
        return 'none', False
    if previous is None:
        return 'new', False
    if current != previous:
        return 'changed', False
    return 'same', frontend_running and previous_running


def format_line(when, picture_state, frozen, temp, mhz, throttled, load, ui_rss,
                be_rss, avail, frontend_pid, backend_pid):
    flags = ''
    if frozen:
        flags += ' FROZEN'
    if throttled not in ('', '0x0'):
        flags += ' THROTTLED'
    state = 'active' if frontend_pid else 'inactive'
    return (f'{when} picture={picture_state} temp={temp} arm={mhz}MHz throttled={throttled} '
            f'load={load} ui_rss={ui_rss}MB be_rss={be_rss}MB avail={avail}MB '
            f'state={state} pid={frontend_pid or 0} be_pid={backend_pid or 0}{flags}')


def sample(previous):
    """One minute's line; `previous` is (digest, frontend_running)."""
    frontend = find_pid(FRONTEND)
    backend = find_pid(BACKEND)
    try:
        digest = scanout_digest()
    except OSError:
        digest = None
    state, frozen = picture(previous[0], digest, frontend is not None, previous[1])
    try:
        mhz = int(vcgencmd('measure_clock', 'arm') or 0) // 1_000_000
    except ValueError:
        mhz = 0
    with open('/proc/loadavg') as loadavg:
        load = loadavg.read().split()[0]
    line = format_line(time.strftime('%Y-%m-%d %H:%M:%S', time.gmtime()), state, frozen,
                       vcgencmd('measure_temp'), mhz, vcgencmd('get_throttled'), load,
                       rss_mb(frontend), rss_mb(backend), mem_available_mb(),
                       frontend, backend)
    return line, (digest, frontend is not None)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('log', nargs='?', default=DEFAULT_LOG)
    parser.add_argument('--interval', type=int, default=60)
    parser.add_argument('--once', action='store_true', help='one line to stdout')
    args = parser.parse_args(argv)
    if args.interval < 60:
        parser.error('--interval must be at least 60 s, or the clock may not have changed')
    previous = (None, False)
    if args.once:
        print(sample(previous)[0])
        return 0
    while True:
        time.sleep(args.interval)
        line, previous = sample(previous)
        with open(args.log, 'a') as log:
            log.write(line + '\n')


if __name__ == '__main__':
    sys.exit(main())
