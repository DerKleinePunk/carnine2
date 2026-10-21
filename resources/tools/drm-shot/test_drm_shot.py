import struct
import types
import unittest
import zlib

import drm_shot as ds

try:
    import numpy as np
    import drm_shot_planes as dp
except ImportError:  # python3-numpy missing: only drm_shot.py is tested
    np = dp = None


def read_png(data):
    """(width, height, colour type, raw scanlines) of a PNG written here."""
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, chunks = 8, {}
    while pos < len(data):
        n, = struct.unpack('>I', data[pos:pos + 4])
        tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        crc, = struct.unpack('>I', data[pos + 8 + n:pos + 12 + n])
        assert crc == zlib.crc32(tag + body), tag
        chunks.setdefault(tag, b'')
        chunks[tag] += body
        pos += 12 + n
    w, h, depth, ctype = struct.unpack('>IIBB', chunks[b'IHDR'][:10])
    assert depth == 8 and b'IEND' in chunks
    return w, h, ctype, zlib.decompress(chunks[b'IDAT'])


def bgrx(*pixels):
    """XRGB8888 memory (B G R X per pixel) from (r, g, b) tuples."""
    return b''.join(bytes((b, g, r, 0xff)) for r, g, b in pixels)


RED, GREEN, BLUE, WHITE = (255, 0, 0), (0, 255, 0), (0, 0, 255), (255,) * 3


class FlipsTest(unittest.TestCase):
    def test_no_rotation_flips_nothing(self):
        self.assertEqual(ds.flips(ds.ROTATE_0), (False, False))

    def test_the_mirror_ivi_homescreen_sets_flips_rows(self):
        # GL renders bottom-up, the plane is mirrored vertically.
        self.assertEqual(ds.flips(ds.ROTATE_0 | ds.REFLECT_Y), (False, True))

    def test_180_degrees_are_both_mirrors(self):
        self.assertEqual(ds.flips(ds.ROTATE_180), (True, True))
        self.assertEqual(ds.flips(ds.ROTATE_180 | ds.REFLECT_Y),
                         (True, False))

    def test_90_degrees_are_refused(self):
        with self.assertRaises(ValueError):
            ds.flips(0x2)


class RgbRowsTest(unittest.TestCase):
    # 2x2 with a pitch of 12 bytes (4 bytes padding per row).
    RAW = bgrx(RED, GREEN) + b'\0' * 4 + bgrx(BLUE, WHITE) + b'\0' * 4

    def rows(self, flip_x, flip_y):
        return ds.rgb_rows(self.RAW, 2, 2, 12, flip_x, flip_y)

    def test_bgrx_becomes_rgb_and_padding_is_dropped(self):
        self.assertEqual(self.rows(False, False),
                         b'\0' + bytes(RED + GREEN) +
                         b'\0' + bytes(BLUE + WHITE))

    def test_flip_y_reverses_the_rows(self):
        self.assertEqual(self.rows(False, True),
                         b'\0' + bytes(BLUE + WHITE) +
                         b'\0' + bytes(RED + GREEN))

    def test_flip_x_reverses_the_pixels(self):
        self.assertEqual(self.rows(True, False),
                         b'\0' + bytes(GREEN + RED) +
                         b'\0' + bytes(WHITE + BLUE))


class PngTest(unittest.TestCase):
    def test_a_valid_rgb_png(self):
        rows = b'\0' + bytes(RED + GREEN) + b'\0' + bytes(BLUE + WHITE)
        self.assertEqual(read_png(ds.png(2, 2, rows)), (2, 2, 2, rows))


@unittest.skipIf(np is None, 'python3-numpy missing')
class ToRgbaTest(unittest.TestCase):
    def fb(self, fmt, w, h, pitches, offsets=(0, 0)):
        return types.SimpleNamespace(pixel_format=fmt, width=w, height=h,
                                     pitches=pitches, offsets=offsets)

    def test_xr24_is_opaque_and_ar24_keeps_alpha(self):
        data = np.frombuffer(bytes((10, 20, 30, 128)) * 2, np.uint8)
        x = dp.to_rgba(self.fb(dp.XR24, 2, 1, (8,)), data)
        a = dp.to_rgba(self.fb(dp.AR24, 2, 1, (8,)), data)
        np.testing.assert_allclose(x[0, 0] * 255, (30, 20, 10, 255))
        np.testing.assert_allclose(a[0, 0] * 255, (30, 20, 10, 128))

    def test_xb24_is_already_rgb(self):
        data = np.frombuffer(bytes((10, 20, 30, 0)), np.uint8)
        img = dp.to_rgba(self.fb(dp.XB24, 1, 1, (4,)), data)
        np.testing.assert_allclose(img[0, 0] * 255, (10, 20, 30, 255))

    def test_nv12_grey_and_limited_range(self):
        # 2x2: Y plane (pitch 2) then one interleaved CbCr pair.
        y = bytes((16, 235, 126, 126))
        data = np.frombuffer(y + bytes((128, 128)), np.uint8)
        img = dp.to_rgba(self.fb(dp.NV12, 2, 2, (2, 2), (0, 4)), data)
        self.assertEqual(img.shape, (2, 2, 4))
        np.testing.assert_allclose(img[0, 0, :3], 0, atol=1e-3)   # black
        np.testing.assert_allclose(img[0, 1, :3], 1, atol=3e-3)   # white
        self.assertTrue(np.allclose(img[1, 0, 0], img[1, 0, 1:3]))  # grey

    def test_nv16_red(self):
        # BT.601 limited red: Y 81, Cb 90, Cr 240.
        data = np.frombuffer(bytes((81, 81, 90, 240)), np.uint8)
        img = dp.to_rgba(self.fb(dp.NV16, 2, 1, (2, 2), (0, 2)), data)
        np.testing.assert_allclose(img[0, 1, :3], (1, 0, 0), atol=0.01)

    def test_unknown_format_is_refused(self):
        with self.assertRaises(ValueError):
            dp.to_rgba(self.fb(0x12345678, 1, 1, (4,)), np.zeros(4, np.uint8))


@unittest.skipIf(np is None, 'python3-numpy missing')
class GeometryTest(unittest.TestCase):
    def setUp(self):
        self.IMG = np.arange(6).reshape(2, 3)

    def test_rotation_matches_drm_shot(self):
        for rot, want in ((ds.ROTATE_0, self.IMG),
                          (dp.REFLECT_Y, self.IMG[::-1]),
                          (dp.REFLECT_X, self.IMG[:, ::-1]),
                          (dp.ROTATE_180, self.IMG[::-1, ::-1])):
            np.testing.assert_array_equal(dp.apply_rotation(self.IMG, rot),
                                          want)

    def test_scale_is_nearest_neighbour(self):
        np.testing.assert_array_equal(dp.scale(self.IMG, 6, 2),
                                      [[0, 0, 1, 1, 2, 2], [3, 3, 4, 4, 5, 5]])
        self.assertIs(dp.scale(self.IMG, 3, 2), self.IMG)

    def test_crtc_position_is_signed(self):
        self.assertEqual(dp.signed32(0xffffffff), -1)
        self.assertEqual(dp.signed32(12), 12)


@unittest.skipIf(np is None, 'python3-numpy missing')
class BlendTest(unittest.TestCase):
    def setUp(self):
        self.DST = np.full((1, 1, 3), 0.5, np.float32)

    def test_opaque_covers(self):
        part = np.array([[[1, 0, 0, 1]]], np.float32)
        np.testing.assert_allclose(dp.blend(self.DST, part, 0xffff, True),
                                   [[[1, 0, 0]]])

    def test_transparent_premultiplied_keeps_what_is_below(self):
        part = np.zeros((1, 1, 4), np.float32)
        np.testing.assert_allclose(dp.blend(self.DST, part, 0xffff, True),
                                   self.DST)

    def test_half_alpha_coverage(self):
        part = np.array([[[1, 1, 1, 0.5]]], np.float32)
        np.testing.assert_allclose(dp.blend(self.DST, part, 0xffff, False),
                                   [[[0.75] * 3]])

    def test_plane_alpha_scales(self):
        part = np.array([[[1, 1, 1, 1]]], np.float32)
        np.testing.assert_allclose(dp.blend(self.DST, part, 0, True),
                                   self.DST)


@unittest.skipIf(np is None, 'python3-numpy missing')
class WritePngTest(unittest.TestCase):
    def test_same_scanlines_as_drm_shot(self):
        import os
        import tempfile
        rgb = np.array([[RED, GREEN], [BLUE, WHITE]], np.uint8)
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, 'a.png')
            dp.write_png(path, rgb)
            with open(path, 'rb') as f:
                got = read_png(f.read())
        self.assertEqual(got, (2, 2, 2, ds.rgb_rows(
            bgrx(RED, GREEN, BLUE, WHITE), 2, 2, 8, False, False)))


if __name__ == '__main__':
    unittest.main()
