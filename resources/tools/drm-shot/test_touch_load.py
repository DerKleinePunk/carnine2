import struct
import unittest

import touch_load as tl


class UserDevTest(unittest.TestCase):
    def test_layout_of_uinput_user_dev(self):
        dev = tl.user_dev()
        # name[80] + input_id (4 x u16) + ff_effects_max + 4 x 64 ints
        self.assertEqual(len(dev), 80 + 8 + 4 + 4 * 64 * 4)
        self.assertTrue(dev.startswith(b'freeze-soak-touch\0'))
        absmax = struct.unpack_from('64i', dev, 92)
        self.assertEqual(absmax[tl.ABS_MT_POSITION_X], 1023)
        self.assertEqual(absmax[tl.ABS_MT_POSITION_Y], 599)
        self.assertEqual(absmax[tl.ABS_MT_SLOT], 1)
        self.assertEqual(set(dev[92 + 256:]), {0})  # absmin, fuzz, flat


class InputEventTest(unittest.TestCase):
    def test_timeval_type_code_value(self):
        ev = tl.input_event(tl.EV_ABS, tl.ABS_MT_TRACKING_ID, -1, t=12.5)
        self.assertEqual(struct.unpack('llHHi', ev),
                         (12, 500000, tl.EV_ABS, tl.ABS_MT_TRACKING_ID, -1))


class FrameEventsTest(unittest.TestCase):
    def test_one_finger_down(self):
        self.assertEqual(tl.frame_events([(0, 7, 46.6, 466.2)]), [
            (tl.EV_ABS, tl.ABS_MT_SLOT, 0),
            (tl.EV_ABS, tl.ABS_MT_TRACKING_ID, 7),
            (tl.EV_ABS, tl.ABS_MT_POSITION_X, 46),
            (tl.EV_ABS, tl.ABS_MT_POSITION_Y, 466),
            (tl.EV_KEY, tl.BTN_TOUCH, 1),
            (tl.EV_ABS, tl.ABS_X, 46),
            (tl.EV_ABS, tl.ABS_Y, 466),
            (tl.EV_SYN, tl.SYN_REPORT, 0)])

    def test_lifting_releases_the_touch(self):
        self.assertEqual(tl.frame_events([(0, -1), (1, -1)]), [
            (tl.EV_ABS, tl.ABS_MT_SLOT, 0),
            (tl.EV_ABS, tl.ABS_MT_TRACKING_ID, -1),
            (tl.EV_ABS, tl.ABS_MT_SLOT, 1),
            (tl.EV_ABS, tl.ABS_MT_TRACKING_ID, -1),
            (tl.EV_KEY, tl.BTN_TOUCH, 0),
            (tl.EV_SYN, tl.SYN_REPORT, 0)])

    def test_two_fingers_report_the_first_as_single_touch(self):
        ev = tl.frame_events([(0, 1, 100, 200), (1, 2, 300, 200)])
        self.assertIn((tl.EV_ABS, tl.ABS_MT_SLOT, 1), ev)
        self.assertEqual(ev[-3:], [(tl.EV_ABS, tl.ABS_X, 100),
                                   (tl.EV_ABS, tl.ABS_Y, 200),
                                   (tl.EV_SYN, tl.SYN_REPORT, 0)])


class GestureTest(unittest.TestCase):
    def setUp(self):
        self.frames = []
        self._frame, self._sleep = tl.frame, tl.time.sleep
        tl.frame = lambda fd, fingers: self.frames.append(fingers)
        tl.time.sleep = lambda s: None

    def tearDown(self):
        tl.frame, tl.time.sleep = self._frame, self._sleep

    def test_a_tap_is_a_swipe_on_the_spot_then_a_lift(self):
        tl.swipe(None, 46, 466, 46, 466, steps=3)
        self.assertEqual(len(self.frames), 5)
        self.assertEqual({f[0][2:] for f in self.frames[:-1]}, {(46, 466)})
        self.assertEqual(len({f[0][1] for f in self.frames[:-1]}), 1)
        self.assertEqual(self.frames[-1], [(0, -1)])

    def test_pinch_moves_two_fingers_apart(self):
        tl.pinch(None, 600, 335, 60, 250, steps=2)
        first, last = self.frames[0], self.frames[-2]
        self.assertEqual([f[2] for f in first], [540, 660])
        self.assertEqual([f[2] for f in last], [350, 850])
        self.assertEqual(self.frames[-1], [(0, -1), (1, -1)])


class LogPathTest(unittest.TestCase):
    def test_override_and_default(self):
        self.assertEqual(tl.log_path({'TOUCH_LOAD_LOG': '/tmp/x.log'}),
                         '/tmp/x.log')
        self.assertTrue(tl.log_path({}).endswith('/freeze/load.log'))


if __name__ == '__main__':
    unittest.main()
