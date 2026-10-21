#!/usr/bin/env python3
"""Screenshot of the DRM scanout across all planes (Pi 4, vc4).

Under drm-kms-egl ivi-homescreen spreads a scene with a platform view over
several KMS planes (Flutter parts and the video separately). A capture of the
primary plane alone is then black. This script reads every used plane of the
active CRTC, stacks them by zpos (ARGB with alpha, NV16/NV12 as BT.601
limited) and writes a PNG.

Usage: sudo python3 drm_shot_planes.py output.png [/dev/dri/cardN] [-v]
Needs python3-numpy and root (DRM handles).
"""
import ctypes
import ctypes.util
import glob
import mmap
import os
import struct
import sys
import zlib

import numpy as np

drm = None  # libdrm, loaded in main() so the tests run without it


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


def libdrm():
    lib = ctypes.CDLL(ctypes.util.find_library('drm') or 'libdrm.so.2')
    lib.drmModeObjectGetProperties.restype = ctypes.POINTER(ObjProps)
    lib.drmModeGetProperty.restype = ctypes.POINTER(Prop)
    lib.drmModeGetPlaneResources.restype = ctypes.POINTER(PlaneRes)
    lib.drmModeGetPlane.restype = ctypes.POINTER(Plane)
    lib.drmModeGetFB2.restype = ctypes.POINTER(FB2)
    return lib


XR24, AR24, XB24, AB24 = 0x34325258, 0x34325241, 0x34324258, 0x34324241
NV12, NV16 = 0x3231564e, 0x3631564e
PLANE_OBJ = 0xeeeeeeee
ROTATE_180, REFLECT_X, REFLECT_Y = 0x4, 0x10, 0x20


def props(fd, plane_id):
    out = {}
    p = drm.drmModeObjectGetProperties(fd, plane_id, PLANE_OBJ)
    if not p:
        return out
    for i in range(p.contents.count_props):
        prop = drm.drmModeGetProperty(fd, p.contents.props[i])
        if prop:
            out[prop.contents.name.decode()] = p.contents.prop_values[i]
    return out


def read_fb(fd, fb):
    prime = ctypes.c_int()
    if drm.drmPrimeHandleToFD(fd, fb.handles[0], os.O_CLOEXEC | os.O_RDWR,
                              ctypes.byref(prime)):
        raise RuntimeError('drmPrimeHandleToFD')
    size = os.lseek(prime.value, 0, os.SEEK_END)
    with mmap.mmap(prime.value, size, mmap.MAP_SHARED, mmap.PROT_READ) as m:
        data = np.frombuffer(m, dtype=np.uint8).copy()
    os.close(prime.value)
    return data


def to_rgba(fb, data):
    """Returns an HxWx4 image (RGBA, float 0..1)."""
    w, h = fb.width, fb.height
    fmt = fb.pixel_format
    if fmt in (XR24, AR24, XB24, AB24):
        pitch, off = fb.pitches[0], fb.offsets[0]
        px = data[off:off + pitch * h].reshape(h, pitch)[:, :w * 4]
        px = px.reshape(h, w, 4).astype(np.float32) / 255.0
        if fmt in (XR24, AR24):  # B G R A in memory
            rgb = px[..., [2, 1, 0]]
        else:                    # R G B A
            rgb = px[..., [0, 1, 2]]
        a = px[..., 3:4] if fmt in (AR24, AB24) else np.ones((h, w, 1),
                                                             np.float32)
        return np.concatenate([rgb, a], axis=2)
    if fmt in (NV12, NV16):
        yp, yo = fb.pitches[0], fb.offsets[0]
        cp, co = fb.pitches[1], fb.offsets[1]
        y = data[yo:yo + yp * h].reshape(h, yp)[:, :w].astype(np.float32)
        ch = h if fmt == NV16 else h // 2
        c = data[co:co + cp * ch].reshape(ch, cp)[:, :w].astype(np.float32)
        cb = np.repeat(c[:, 0::2], 2, axis=1)[:, :w]
        cr = np.repeat(c[:, 1::2], 2, axis=1)[:, :w]
        if fmt == NV12:
            cb, cr = np.repeat(cb, 2, axis=0)[:h], np.repeat(cr, 2, axis=0)[:h]
        yy = (y - 16) * 1.164
        r = yy + 1.596 * (cr - 128)
        g = yy - 0.392 * (cb - 128) - 0.813 * (cr - 128)
        b = yy + 2.017 * (cb - 128)
        rgb = np.clip(np.stack([r, g, b], axis=2) / 255.0, 0, 1)
        return np.concatenate([rgb, np.ones((h, w, 1), np.float32)], axis=2)
    raise ValueError(f'format {fmt:#x} not supported')


def apply_rotation(img, rot):
    if rot & ROTATE_180:
        rot ^= REFLECT_X | REFLECT_Y
    if rot & REFLECT_Y:
        img = img[::-1]
    if rot & REFLECT_X:
        img = img[:, ::-1]
    return img


def scale(img, w, h):
    sh, sw = img.shape[:2]
    if (sw, sh) == (w, h):
        return img
    ys = (np.arange(h) * sh / h).astype(int)
    xs = (np.arange(w) * sw / w).astype(int)
    return img[ys][:, xs]


def signed32(v):
    """CRTC_X/CRTC_Y arrive as u64 property values but are signed."""
    return int(np.int32(np.uint32(v)))


def blend(dst, part, plane_alpha, premultiplied):
    """Lays the RGBA `part` over the RGB `dst` (same size) and returns it.
    plane_alpha is the plane's `alpha` property (0..0xffff)."""
    alpha = part[..., 3:4] * (plane_alpha / 0xffff)
    if premultiplied:
        return part[..., :3] * (alpha / np.maximum(part[..., 3:4], 1e-6)) + \
            dst * (1 - alpha)
    return part[..., :3] * alpha + dst * (1 - alpha)


def shoot(card, verbose):
    fd = os.open(card, os.O_RDWR | os.O_CLOEXEC)
    drm.drmSetClientCap(fd, 2, 1)  # UNIVERSAL_PLANES
    drm.drmSetClientCap(fd, 3, 1)  # ATOMIC (zpos, SRC_*/CRTC_* readable)
    res = drm.drmModeGetPlaneResources(fd)
    if not res:
        return None
    layers = []
    for i in range(res.contents.count_planes):
        p = drm.drmModeGetPlane(fd, res.contents.planes[i])
        if not p or not p.contents.fb_id or not p.contents.crtc_id:
            continue
        fb = drm.drmModeGetFB2(fd, p.contents.fb_id)
        if not fb:
            continue
        pr = props(fd, p.contents.plane_id)
        layers.append((pr.get('zpos', 0), p.contents.plane_id, fb.contents, pr))
    if not layers:
        return None
    layers.sort(key=lambda l: (l[0], l[1]))
    # Screen size: largest extent of the planes on the CRTC.
    sw = max(int(l[3].get('CRTC_X', 0)) + int(l[3].get('CRTC_W', l[2].width))
             for l in layers)
    sh = max(int(l[3].get('CRTC_Y', 0)) + int(l[3].get('CRTC_H', l[2].height))
             for l in layers)
    out = np.zeros((sh, sw, 3), np.float32)
    for zpos, pid, fb, pr in layers:
        if fb.modifier != 0:
            print(f'plane {pid}: modifier {fb.modifier:#x} skipped')
            continue
        if not fb.handles[0]:
            sys.exit('no handle - run as root')
        img = to_rgba(fb, read_fb(fd, fb))
        sx, sy = pr.get('SRC_X', 0) >> 16, pr.get('SRC_Y', 0) >> 16
        sw_, sh_ = pr.get('SRC_W', fb.width << 16) >> 16, pr.get(
            'SRC_H', fb.height << 16) >> 16
        img = img[sy:sy + sh_, sx:sx + sw_]
        img = apply_rotation(img, pr.get('rotation', 1))
        cx = signed32(pr.get('CRTC_X', 0))
        cy = signed32(pr.get('CRTC_Y', 0))
        cw, ch = int(pr.get('CRTC_W', fb.width)), int(pr.get('CRTC_H',
                                                              fb.height))
        img = scale(img, cw, ch)
        x0, y0 = max(cx, 0), max(cy, 0)
        x1, y1 = min(cx + cw, sw), min(cy + ch, sh)
        if x1 <= x0 or y1 <= y0:
            continue
        part = img[y0 - cy:y1 - cy, x0 - cx:x1 - cx]
        # pixel blend mode 1 = Premultiplied (the kernel's default)
        out[y0:y1, x0:x1] = blend(out[y0:y1, x0:x1], part,
                                  pr.get('alpha', 0xffff),
                                  pr.get('pixel blend mode', 1) == 1)
        if verbose:
            print(f'plane {pid} zpos={zpos} fmt={fb.pixel_format:#x} '
                  f'{fb.width}x{fb.height} -> {cw}x{ch}@{cx},{cy}')
    os.close(fd)
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


def write_png(path, rgb):
    h, w = rgb.shape[:2]
    rows = b''.join(b'\0' + rgb[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data)))
    png = (b'\x89PNG\r\n\x1a\n' +
           chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) +
           chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(png)


def main():
    global drm
    args = [a for a in sys.argv[1:] if a != '-v']
    verbose = '-v' in sys.argv
    if not args:
        sys.exit(__doc__.split('Usage: ')[1].strip())
    drm = libdrm()
    out = args[0]
    cards = args[1:] or sorted(glob.glob('/dev/dri/card*'))
    img = next((i for i in (shoot(c, verbose) for c in cards)
                if i is not None), None)
    if img is None:
        sys.exit('no used plane found')
    write_png(out, img)
    print(f'{out}: {img.shape[1]}x{img.shape[0]}')


if __name__ == '__main__':
    main()
