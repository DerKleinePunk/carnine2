import os
import tempfile
import unittest

import freeze_watch as fw


class PictureTest(unittest.TestCase):
    def test_a_changed_picture_is_not_frozen(self):
        self.assertEqual(fw.picture('a', 'b', True, True), ('changed', False))

    def test_the_same_picture_with_a_running_frontend_is_frozen(self):
        self.assertEqual(fw.picture('a', 'a', True, True), ('same', True))

    def test_the_same_picture_without_a_frontend_is_not_frozen(self):
        # Frontend stopped (maintenance mode, restart): the panel keeps the
        # last picture, but nothing is frozen.
        self.assertEqual(fw.picture('a', 'a', False, True), ('same', False))
        self.assertEqual(fw.picture('a', 'a', True, False), ('same', False))

    def test_the_first_sample_and_a_missing_scanout_say_so(self):
        self.assertEqual(fw.picture(None, 'a', True, False), ('new', False))
        self.assertEqual(fw.picture('a', None, True, True), ('none', False))


class ProcTest(unittest.TestCase):
    def setUp(self):
        self.proc = tempfile.mkdtemp()

    def add(self, pid, comm, rss_kb=None):
        os.makedirs(os.path.join(self.proc, str(pid)))
        with open(os.path.join(self.proc, str(pid), 'comm'), 'w') as f:
            f.write(comm + '\n')
        if rss_kb is not None:
            with open(os.path.join(self.proc, str(pid), 'status'), 'w') as f:
                f.write(f'Name:\t{comm}\nVmRSS:\t  {rss_kb} kB\n')

    def test_the_oldest_process_with_that_name_is_found(self):
        self.add(812, 'homescreen')
        self.add(747, 'homescreen')
        self.add(695, 'carnine-backend')
        os.makedirs(os.path.join(self.proc, 'self'))
        self.assertEqual(fw.find_pid('homescreen', self.proc), 747)
        self.assertEqual(fw.find_pid('carnine-backend', self.proc), 695)
        self.assertIsNone(fw.find_pid('valhalla_service', self.proc))

    def test_resident_memory_in_mb(self):
        self.add(747, 'homescreen', rss_kb=298740)
        self.assertEqual(fw.rss_mb(747, self.proc), 291)
        self.assertEqual(fw.rss_mb(None, self.proc), 0)
        self.assertEqual(fw.rss_mb(999, self.proc), 0)

    def test_mem_available(self):
        path = os.path.join(self.proc, 'meminfo')
        with open(path, 'w') as f:
            f.write('MemTotal:  3884000 kB\nMemAvailable:  3289000 kB\n')
        self.assertEqual(fw.mem_available_mb(path), 3211)


class LineTest(unittest.TestCase):
    def test_vcgencmd_values(self):
        self.assertEqual(fw.vcgencmd_value("temp=30.6'C\n"), "30.6'C")
        self.assertEqual(fw.vcgencmd_value('frequency(48)=1500345728'), '1500345728')
        self.assertEqual(fw.vcgencmd_value('throttled=0x0'), '0x0')

    def test_a_frozen_throttled_line_carries_both_flags(self):
        line = fw.format_line('2026-10-14 07:00:00', 'same', True, "71.0'C", 1500, '0x20002',
                              '2.10', 291, 161, 3211, 747, 695)
        self.assertEqual(
            line,
            "2026-10-14 07:00:00 picture=same temp=71.0'C arm=1500MHz throttled=0x20002 "
            'load=2.10 ui_rss=291MB be_rss=161MB avail=3211MB state=active pid=747 be_pid=695 '
            'FROZEN THROTTLED')

    def test_a_quiet_line_has_no_flags_and_no_frontend_reads_inactive(self):
        line = fw.format_line('t', 'changed', False, "30.6'C", 1500, '0x0', '1.0', 0, 161,
                              3211, None, 695)
        self.assertTrue(line.endswith('state=inactive pid=0 be_pid=695'), line)

    def test_the_interval_must_let_the_clock_change(self):
        with self.assertRaises(SystemExit):
            fw.main(['--interval', '30', '--once'])


if __name__ == '__main__':
    unittest.main()
