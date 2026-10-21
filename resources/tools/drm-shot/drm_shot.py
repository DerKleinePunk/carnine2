#!/usr/bin/env python3
"""Reads the picture on the panel from the DRM scanout and writes a PNG.

For the Pi with drm-kms-egl: there is no compositor that could take a
screenshot. Needs root (DRM handles only with CAP_SYS_ADMIN) and a linear
framebuffer (vc4 with modifier 0). Reads the primary plane only and no
python3-numpy; for a page with a platform view (camera, video) use
drm_shot_planes.py.
The plane's `rotation` property is applied: ivi-homescreen renders with GL
bottom-up and has the plane mirrored (REFLECT_Y), so the PNG shows what the
panel shows.

Usage: sudo python3 drm_shot.py output.png [/dev/dri/cardN]
"""
import ctypes
import ctypes.util
import glob
import mmap
import os
import struct
import sys
import zlib


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


class ObjProps(ctypes.Structure):
    _fields_ = [('count_props', ctypes.c_uint32),
                ('props', ctypes.POINTER(ctypes.c_uint32)),
                ('prop_values', ctypes.POINTER(ctypes.c_uint64))]


class Prop(ctypes.Structure):
    _fields_ = [('prop_id', ctypes.c_uint32), ('flags', ctypes.c_uint32),
                ('name', ctypes.c_char * 32)]


XR24, AR24 = 0x34325258, 0x34325241
PLANE = 0xeeeeeeee
ROTATE_0, ROTATE_180, REFLECT_X, REFLECT_Y = 0x1, 0x4, 0x10, 0x20


def libdrm():
    """libdrm with the return types used here; loaded on first use only, so
    the tests run on a machine without it."""
    drm = ctypes.CDLL(ctypes.util.find_library('drm') or 'libdrm.so.2')
    drm.drmModeObjectGetProperties.restype = ctypes.POINTER(ObjProps)
    drm.drmModeGetProperty.restype = ctypes.POINTER(Prop)
    drm.drmModeGetPlaneResources.restype = ctypes.POINTER(PlaneRes)
    drm.drmModeGetPlane.restype = ctypes.POINTER(Plane)
    drm.drmModeGetFB2.restype = ctypes.POINTER(FB2)
    return drm


def rotation(drm, fd, plane_id):
    props = drm.drmModeObjectGetProperties(fd, plane_id, PLANE)
    if not props:
        return ROTATE_0
    for i in range(props.contents.count_props):
        prop = drm.drmModeGetProperty(fd, props.contents.props[i])
        if prop and prop.contents.name == b'rotation':
            return props.contents.prop_values[i]
    return ROTATE_0


def scanout(drm, card):
    fd = os.open(card, os.O_RDWR | os.O_CLOEXEC)
    drm.drmSetClientCap(fd, 2, 1)  # DRM_CLIENT_CAP_UNIVERSAL_PLANES
    res = drm.drmModeGetPlaneResources(fd)
    if not res:
        os.close(fd)
        return None
    for i in range(res.contents.count_planes):
        p = drm.drmModeGetPlane(fd, res.contents.planes[i])
        if p and p.contents.fb_id and p.contents.crtc_id:
            fb = drm.drmModeGetFB2(fd, p.contents.fb_id)
            if fb and fb.contents.pixel_format in (XR24, AR24):
                return fd, fb.contents, rotation(drm, fd, p.contents.plane_id)
    os.close(fd)
    return None


def flips(rot):
    """(flip_x, flip_y) for a plane rotation; ROTATE_180 is both mirrors.
    Raises ValueError for 90/270 degrees."""
    if rot & ~(ROTATE_0 | REFLECT_X | REFLECT_Y | ROTATE_180):
        raise ValueError(f'rotation {rot:#x} not supported')
    if rot & ROTATE_180:
        rot ^= REFLECT_X | REFLECT_Y
    return bool(rot & REFLECT_X), bool(rot & REFLECT_Y)


def rgb_rows(raw, w, h, pitch, flip_x, flip_y):
    """PNG scanlines (filter byte 0 + RGB) from XRGB8888 memory (B G R X)."""
    rows = bytearray()
    for y in (range(h - 1, -1, -1) if flip_y else range(h)):
        line = raw[y * pitch:y * pitch + w * 4]
        if flip_x:
            px = [line[i:i + 4] for i in range(0, len(line), 4)]
            line = b''.join(reversed(px))
        rgb = bytearray(w * 3)
        rgb[0::3], rgb[1::3], rgb[2::3] = line[2::4], line[1::4], line[0::4]
        rows += b'\0' + rgb
    return bytes(rows)


def png(w, h, rows):
    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data)))
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__.split('Usage: ')[1].strip())
    out = sys.argv[1]
    cards = sys.argv[2:] or sorted(glob.glob('/dev/dri/card*'))
    drm = libdrm()
    found = next((s for s in (scanout(drm, c) for c in cards) if s), None)
    if not found:
        sys.exit('no active framebuffer (XR24/AR24) found')
    fd, fb, rot = found
    try:
        flip_x, flip_y = flips(rot)
    except ValueError as e:
        sys.exit(str(e))
    if fb.modifier != 0:
        sys.exit(f'framebuffer not linear (modifier {fb.modifier:#x})')
    if not fb.handles[0]:
        sys.exit('no handle - run as root')
    prime = ctypes.c_int()
    if drm.drmPrimeHandleToFD(fd, fb.handles[0], os.O_CLOEXEC | os.O_RDWR,
                              ctypes.byref(prime)):
        sys.exit('drmPrimeHandleToFD failed')
    w, h, pitch = fb.width, fb.height, fb.pitches[0]
    size = fb.offsets[0] + pitch * h
    with mmap.mmap(prime.value, size, mmap.MAP_SHARED, mmap.PROT_READ) as m:
        raw = m[fb.offsets[0]:size]
    os.close(prime.value)
    os.close(fd)
    with open(out, 'wb') as f:
        f.write(png(w, h, rgb_rows(raw, w, h, pitch, flip_x, flip_y)))
    print(f'{out}: {w}x{h}, rotation {rot:#x}')


if __name__ == '__main__':
    main()
