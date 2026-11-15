import os
import tempfile
import unittest

import lcov_summary as ls

REPORT = """TN:
SF:/work/src/backend/src/main.rs
FN:1,main
DA:1,1
DA:2,0
DA:3,5
LF:3
LH:2
end_of_record
SF:/work/src/backend/src/navigation/places.rs
DA:1,1
DA:2,1
LF:2
LH:2
end_of_record
"""

FLUTTER = """SF:lib/features/media/data/repo.dart
DA:1,0
DA:2,0
DA:3,1
DA:4,0
LF:4
LH:1
end_of_record
SF:lib/lib/carnine.pb.dart
DA:1,0
DA:2,0
LF:2
LH:0
end_of_record
SF:lib/main.dart
DA:1,1
end_of_record
"""


class ParseTest(unittest.TestCase):
    def test_absolute_paths_become_relative_to_the_root(self):
        records = ls.parse(REPORT, '/work/src/backend')
        self.assertEqual([r.path for r in records],
                         ['src/main.rs', 'src/navigation/places.rs'])

    def test_counts_come_from_lf_and_lh(self):
        main = ls.parse(REPORT, '/work/src/backend')[0]
        self.assertEqual((main.hit, main.found), (2, 3))

    def test_a_record_without_lf_lh_is_counted_from_its_da_lines(self):
        main_dart = ls.parse(FLUTTER)[2]
        self.assertEqual((main_dart.hit, main_dart.found), (1, 1))

    def test_relative_paths_stay_as_they_are(self):
        self.assertEqual(ls.parse(FLUTTER)[0].path,
                         'lib/features/media/data/repo.dart')


class ExcludeTest(unittest.TestCase):
    def test_the_generated_grpc_code_drops_out_of_the_total(self):
        records = ls.exclude(ls.parse(FLUTTER), ['lib/lib/'])
        self.assertEqual([r.path for r in records],
                         ['lib/features/media/data/repo.dart', 'lib/main.dart'])
        text = ls.summary(records, 'Frontend')
        # 2 of 5 lines, not 2 of 7 with the generated file.
        self.assertIn('**40.0 % of lines** (2 of 5, 2 files)', text)


class SummaryTest(unittest.TestCase):
    def test_total_folders_and_gaps(self):
        text = ls.summary(ls.parse(REPORT, '/work/src/backend'), 'Backend')
        self.assertIn('## Coverage: Backend', text)
        self.assertIn('**80.0 % of lines** (4 of 5, 2 files)', text)
        self.assertIn('| `src/` | 2 / 3 | 66.7 % |', text)
        self.assertIn('| `src/navigation/` | 2 / 2 | 100.0 % |', text)
        # A fully covered file is no gap.
        self.assertIn('| `src/main.rs` | 1 | 66.7 % |', text)
        self.assertNotIn('`src/navigation/places.rs`', text)

    def test_folders_go_three_levels_deep(self):
        text = ls.summary(ls.parse(FLUTTER), 'Frontend')
        self.assertIn('| `lib/features/media/` | 1 / 4 | 25.0 % |', text)
        self.assertIn('| `lib/` | 1 / 1 | 100.0 % |', text)

    def test_the_largest_gap_comes_first_and_the_list_is_capped(self):
        text = ls.summary(ls.parse(FLUTTER), 'Frontend', gaps=1)
        self.assertIn('top 1', text)
        self.assertIn('`lib/features/media/data/repo.dart` | 3 |', text)
        self.assertNotIn('`lib/lib/carnine.pb.dart` | 2 |', text)

    def test_an_empty_report_says_nothing_is_covered(self):
        self.assertIn('**- of lines** (0 of 0, 0 files)', ls.summary([], 'X'))


class MainTest(unittest.TestCase):
    def test_writes_the_filtered_report_that_parses_back(self):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, 'lcov.info')
            out = os.path.join(d, 'filtered.info')
            with open(src, 'w') as f:
                f.write(FLUTTER)
            self.assertEqual(ls.main([src, '--title', 'F', '--exclude',
                                      'lib/lib/', '--output', out]), 0)
            with open(out) as f:
                again = ls.parse(f.read())
        self.assertEqual([r.path for r in again],
                         ['lib/features/media/data/repo.dart', 'lib/main.dart'])
        self.assertEqual([(r.hit, r.found) for r in again], [(1, 4), (1, 1)])

    def test_a_report_without_records_fails(self):
        with tempfile.TemporaryDirectory() as d:
            src = os.path.join(d, 'lcov.info')
            open(src, 'w').close()
            self.assertEqual(ls.main([src, '--title', 'F']), 1)


if __name__ == '__main__':
    unittest.main()
