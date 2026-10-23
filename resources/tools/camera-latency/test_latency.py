import argparse
import contextlib
import io
import os
import tempfile
import unittest

import latency
import latency_led as led
import latency_panel as panel

try:
    import numpy as np
except ImportError:  # python3-numpy missing: the frame tests are skipped
    np = None

needs_numpy = unittest.skipIf(np is None, 'needs python3-numpy')


def square_wave(toggles, delay, fps=30.0, end=None, lo=10.0, hi=90.0):
    """Frames at `fps` that follow the toggles `delay` s late."""
    end = end if end is not None else toggles[-1][0] + 1
    frames, t = [], 0.0
    while t < end:
        seen = [on for ts, on in toggles if ts + delay <= t]
        frames.append((t, hi if seen and seen[-1] else lo))
        t += 1 / fps
    return frames


class ThresholdTest(unittest.TestCase):
    def test_halfway_between_ten_and_ninety_percent(self):
        lo, hi, thr = latency.threshold(list(range(100)))
        self.assertEqual((lo, hi, thr), (10, 90, 50))

    def test_few_frames(self):
        self.assertEqual(latency.threshold([5, 7]), (5, 7, 6))

    def test_outliers_do_not_move_it(self):
        values = [10] * 50 + [90] * 50 + [1000]
        self.assertEqual(latency.threshold(values)[2], 50)

    def test_no_frames(self):
        with self.assertRaises(ValueError):
            latency.threshold([])


class LatenciesTest(unittest.TestCase):
    TOGGLES = [(1.0, True), (2.0, False), (3.0, True)]

    def test_follows_the_delay(self):
        frames = square_wave(self.TOGGLES, delay=0.07, fps=1000)
        lat = latency.latencies(self.TOGGLES, frames, 50)
        self.assertEqual(len(lat), 3)
        for v in lat:
            self.assertAlmostEqual(v, 70, delta=1.5)

    def test_frame_after_next_switch_does_not_count(self):
        toggles = [(1.0, True), (1.5, False)]
        frames = [(1.6, 90.0)]  # bright only after the switch back
        self.assertEqual(latency.latencies(toggles, frames, 50), [])

    def test_last_switch_has_a_tail(self):
        toggles = [(1.0, True)]
        self.assertEqual(latency.latencies(toggles, [(3.5, 90.0)], 50), [])
        self.assertEqual(latency.latencies(toggles, [(2.5, 90.0)], 50), [1500])

    def test_direction_matters(self):
        toggles = [(1.0, False)]
        self.assertEqual(latency.latencies(toggles, [(1.1, 90.0)], 50), [])
        lat = latency.latencies(toggles, [(1.1, 90.0), (1.2, 10.0)], 50)
        self.assertAlmostEqual(lat[0], 200)


class SummaryTest(unittest.TestCase):
    def test_spread(self):
        med, p10, p90 = latency.spread(list(range(1, 101)))
        self.assertEqual(med, 50.5)
        self.assertAlmostEqual(p10, 10.1)
        self.assertAlmostEqual(p90, 90.9)

    def test_spread_of_one(self):
        self.assertEqual(latency.spread([42]), (42, 42, 42))

    def test_frame_rate(self):
        frames = [(i / 25, 0) for i in range(50)]
        self.assertAlmostEqual(latency.frame_rate(frames), 25)
        self.assertEqual(latency.frame_rate([(0, 0)]), 0)

    def test_evaluate(self):
        toggles = [(1 + i * 0.7, i % 2 == 0) for i in range(20)]
        frames = square_wave(toggles, delay=0.068)
        text, lat = latency.evaluate('v4l2', frames, toggles)
        self.assertEqual(len(lat), 20)
        self.assertIn('v4l2: ', text)
        self.assertIn('30.0 frames/s', text)
        self.assertIn('latency over 20 of 20 switches', text)
        # 30 frames/s: seen on the first frame 68..101 ms after the switch
        self.assertTrue(all(68 <= v < 102 for v in lat), lat)

    def test_evaluate_without_switches_stops(self):
        with self.assertRaises(SystemExit):
            latency.evaluate('x', [(0, 5.0), (1, 5.0)], [(0.5, True)])

    def test_write_results(self):
        frames, toggles = [(1.0, 10.0), (1.1, 90.0)], [(1.05, True)]
        with tempfile.TemporaryDirectory() as d:
            prefix = os.path.join(d, 'run')
            latency.write_results(prefix, 'text', frames, toggles, [50.0])
            with open(prefix + '.txt') as f:
                self.assertEqual(f.read(), 'text\n')
            with open(prefix + '.csv') as f:
                self.assertEqual(f.read(), 'latency_ms\n50.0\n')
            with open(prefix + '-raw.csv') as f:
                self.assertEqual(f.read(), 'kind,t_ms,value\n'
                                 'frame,-50.0,10.0\nframe,50.0,90.0\n'
                                 'switch,0.0,1\n')


class PanelTest(unittest.TestCase):
    def test_frame_geometry(self):
        self.assertEqual(panel.frame_geometry('ntsc'), (720, 480, 691200))
        self.assertEqual(panel.frame_geometry('pal'), (720, 576, 829440))

    def test_fb_bytes(self):
        self.assertEqual(panel.fb_bytes('1024,600\n', '2048\n'), 1228800)

    def test_somagic_command(self):
        args = panel.parse_args(['somagic', '--somagic-capture', '/x/cap'])
        self.assertEqual(panel.capture_command(args, 720, 480),
                         ['/x/cap', '-c', '-i', '1', '-n'])
        args = panel.parse_args(['somagic', '--norm', 'pal', '--input', '2'])
        self.assertEqual(panel.capture_command(args, 720, 576)[1:],
                         ['-c', '-i', '2'])

    def test_somagic_from_environment(self):
        old = os.environ.get('SOMAGIC_CAPTURE')
        os.environ['SOMAGIC_CAPTURE'] = '/env/cap'
        try:
            self.assertEqual(panel.parse_args(['somagic']).somagic_capture,
                             '/env/cap')
        finally:
            if old is None:
                del os.environ['SOMAGIC_CAPTURE']
            else:
                os.environ['SOMAGIC_CAPTURE'] = old

    def test_v4l2_command(self):
        args = panel.parse_args(['v4l2', '--dev', '/dev/video3'])
        cmd = panel.capture_command(args, 720, 480)
        self.assertEqual(cmd[:3], ['v4l2-ctl', '-d', '/dev/video3'])
        self.assertIn('--set-fmt-video=width=720,height=480,pixelformat=UYVY',
                      cmd)

    @needs_numpy
    def test_bright_permille(self):
        y = np.zeros((480, 720), np.uint8)
        self.assertEqual(panel.bright_permille(y), 0)
        y[:240] = 255
        self.assertEqual(panel.bright_permille(y), 500)
        y[:] = 200  # not above 200
        self.assertEqual(panel.bright_permille(y), 0)


class LedTest(unittest.TestCase):
    def test_current_trigger(self):
        self.assertEqual(led.current_trigger('none [mmc0] timer heartbeat\n'),
                         'mmc0')

    def test_parse_size(self):
        self.assertEqual(led.parse_size('1280x720'), (1280, 720))
        self.assertEqual(led.parse_args(['raw']).size, (640, 480))

    def test_mode_is_checked(self):
        with self.assertRaises(SystemExit), \
                contextlib.redirect_stderr(io.StringIO()):
            led.parse_args(['roh'])

    def test_led_round_trip(self):
        with tempfile.TemporaryDirectory() as d:
            with open(d + '/trigger', 'w') as f:
                f.write('none [mmc0] timer\n')
            open(d + '/brightness', 'w').close()
            l = led.Led(d)
            with open(d + '/trigger') as f:
                self.assertEqual(f.read(), 'none')
            l.set(True)
            with open(d + '/brightness') as f:
                self.assertEqual(f.read(), '1')
            l.close()
            with open(d + '/trigger') as f:
                self.assertEqual(f.read(), 'mmc0')

    def test_calibration_frames(self):
        marks = [(0.0, True), (0.5, False)]
        calib = [(0.1, 'early'), (0.3, 'on'), (0.6, 'early2'), (0.8, 'off'),
                 (1.2, 'late')]
        self.assertEqual(led.calibration_frames(calib, marks),
                         (['on'], ['off']))

    @needs_numpy
    def test_led_mask_finds_the_led(self):
        off = [np.full((60, 80), 20, np.uint8) for _ in range(3)]
        on = [f.copy() for f in off]
        for f in on:
            f[10:20, 30:50] = 220  # the LED: 200 pixels
            f[50, 5] = 60  # a little noise
        mask, diff = led.led_mask(on, off)
        self.assertEqual(int(mask.sum()), 200)
        self.assertTrue(mask[10:20, 30:50].all())
        self.assertFalse(mask[50, 5])
        self.assertEqual(float(diff[mask].mean()), 200)


class ArgsTest(unittest.TestCase):
    def test_defaults(self):
        a = panel.parse_args(['v4l2'])
        self.assertEqual((a.norm, a.fb, a.secs, a.out),
                         ('ntsc', '/dev/fb0', 60, None))
        b = led.parse_args(['display', '--card', '/dev/dri/card1'])
        self.assertEqual((b.card, b.led), ('/dev/dri/card1',
                                           '/sys/class/leds/ACT'))
        self.assertIsInstance(a, argparse.Namespace)


if __name__ == '__main__':
    unittest.main()
