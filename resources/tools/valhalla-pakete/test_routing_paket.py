import hashlib
import os
import subprocess
import tarfile
import tempfile
import unittest

import routing_paket as rp

# A square around Basel (lon 7.3-7.7, lat 47.3-47.7). It touches four level-2
# tiles (0.25 deg): rows 549/550, columns 749/750 -> ids row * 1440 + col.
SQUARE = """basel
1
   7.3 47.3
   7.7 47.3
   7.7 47.7
   7.3 47.7
   7.3 47.3
END
END
"""

INSIDE = ['2/000/791/309.gph', '2/000/791/310.gph',   # 549 * 1440 + 749/750
          '2/000/792/749.gph', '2/000/792/750.gph',   # 550 * 1440 + 749/750
          '1/049/507.gph',                            # level 1, row 137, col 187
          '0/003/106.gph']                            # level 0, row 34, col 46
OUTSIDE = ['2/000/807/160.gph',                       # lon 10, lat 50
           '2/000/791/308.gph']                       # the neighbour to the west


def make_tree(root, paths):
    for rel in paths:
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(rel.encode() * 10)


class GeometryTest(unittest.TestCase):
    def test_tile_paths_give_level_and_id(self):
        self.assertEqual(rp.tile_of('2/000/792/750.gph'), (2, 792750))
        self.assertEqual(rp.tile_of('0/003/106.gph'), (0, 3106))

    def test_the_bounding_box_of_a_level_2_tile(self):
        self.assertEqual(rp.bbox(2, 792750), (7.5, 47.5, 7.75, 47.75))

    def test_the_tiles_touching_the_square_and_no_others(self):
        rings = rp.read_poly(SQUARE)
        self.assertEqual(rp.tiles_for(INSIDE + OUTSIDE, rings), sorted(INSIDE))

    def test_a_big_tile_counts_although_none_of_its_probes_is_inside(self):
        # The square lies inside the level-0 tile but covers none of its
        # corners nor its centre (the tile spans lon 4-8, lat 46-50).
        rings = rp.read_poly(SQUARE)
        x0, y0, x1, y1 = rp.bbox(0, 3106)
        self.assertFalse(any(rp.inside(x, y, rings) for x, y in
                             ((x0, y0), (x1, y1), ((x0 + x1) / 2, (y0 + y1) / 2))))
        self.assertEqual(rp.tiles_for(['0/003/106.gph'], rings), ['0/003/106.gph'])

    def test_a_tile_inside_a_hole_does_not_count(self):
        rings = rp.read_poly("""ring
1
 0 0
 10 0
 10 10
 0 10
END
!2
 4 4
 6 4
 6 6
 4 6
END
END
""")
        self.assertEqual(len(rings), 2)
        self.assertTrue(rings[1][0])
        # lon 4.75-5.0, lat 4.75-5.0: all probes in the hole, no polygon point.
        hole_tile = (int((4.75 + 90) / 0.25)) * 1440 + int((4.75 + 180) / 0.25)
        ring_tile = (int((1 + 90) / 0.25)) * 1440 + int((1 + 180) / 0.25)
        path = lambda i: '2/%03d/%03d/%03d.gph' % (i // 1000000, i // 1000 % 1000, i % 1000)
        self.assertEqual(rp.tiles_for([path(hole_tile), path(ring_tile)], rings),
                         [path(ring_tile)])


class PackageTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.dir.name, 'tiles')
        make_tree(self.root, INSIDE + OUTSIDE)
        self.out = os.path.join(self.dir.name, 'out')

    def tearDown(self):
        self.dir.cleanup()

    def unpack(self, folder, name):
        return subprocess.run(['zstd', '-q', '-d', '-c', os.path.join(folder, name + '.zst')],
                              check=True, capture_output=True).stdout

    def test_the_package_has_the_files_the_installer_reads(self):
        tiles = rp.tiles_for(rp.list_tiles(self.root), rp.read_poly(SQUARE))
        folder = rp.write_package(self.root, tiles, 'ch', 'dach-2026-11-02', '3.9.1', self.out)
        self.assertEqual(sorted(os.listdir(folder)),
                         ['INHALT', 'SHA256SUMS', 'SHA256SUMS.entpackt',
                          'routing-ch.info.zst', 'routing-ch.tar.zst'])
        with open(os.path.join(folder, 'INHALT')) as f:
            rows = [line.split('\t') for line in f.read().splitlines()[1:]]
        # The info comes first, sizes are packed and unpacked.
        self.assertEqual([r[0] for r in rows], ['routing-ch.info.zst', 'routing-ch.tar.zst'])
        info = self.unpack(folder, 'routing-ch.info')
        self.assertEqual(info.decode(), '# CarNine Routing-Paket\nland=ch\nbau=dach-2026-11-02\n'
                                        'valhalla=3.9.1\nkacheln=6\n')
        self.assertEqual(int(rows[0][2]), len(info))
        tar_bytes = self.unpack(folder, 'routing-ch.tar')
        self.assertEqual(int(rows[1][2]), len(tar_bytes))
        with open(os.path.join(folder, 'SHA256SUMS.entpackt')) as f:
            self.assertIn(f'{hashlib.sha256(tar_bytes).hexdigest()}  routing-ch.tar', f.read())
        with open(os.path.join(folder, 'SHA256SUMS')) as f:
            line = f.read().splitlines()[1]
        with open(os.path.join(folder, 'routing-ch.tar.zst'), 'rb') as f:
            self.assertEqual(line, f'{hashlib.sha256(f.read()).hexdigest()}  routing-ch.tar.zst')

    def test_the_tar_holds_the_tiles_unchanged_without_an_owner(self):
        tiles = rp.tiles_for(rp.list_tiles(self.root), rp.read_poly(SQUARE))
        folder = rp.write_package(self.root, tiles, 'ch', 'b1', '3.9.0', self.out)
        tar_path = os.path.join(self.dir.name, 'x.tar')
        with open(tar_path, 'wb') as f:
            f.write(self.unpack(folder, 'routing-ch.tar'))
        with tarfile.open(tar_path) as tar:
            members = tar.getmembers()
            self.assertEqual([m.name for m in members], sorted(INSIDE))
            self.assertTrue(all(m.uid == 0 and m.mode == 0o644 and m.mtime == 0 for m in members))
            self.assertEqual(tar.extractfile('2/000/792/750.gph').read(),
                             b'2/000/792/750.gph' * 10)

    def test_the_same_input_gives_the_same_package(self):
        tiles = rp.tiles_for(rp.list_tiles(self.root), rp.read_poly(SQUARE))
        sums = []
        for out in ('a', 'b'):
            folder = rp.write_package(self.root, tiles, 'ch', 'b1', '3.9.0',
                                      os.path.join(self.dir.name, out))
            with open(os.path.join(folder, 'SHA256SUMS.entpackt')) as f:
                sums.append(f.read())
        self.assertEqual(sums[0], sums[1])

    def test_main_refuses_a_bad_country_name_and_an_empty_cut(self):
        poly = os.path.join(self.dir.name, 'x.poly')
        with open(poly, 'w') as f:
            f.write(SQUARE)
        with self.assertRaises(SystemExit):
            rp.main([self.root, poly, '--land', 'DE', '--bau', 'b', '--valhalla', 'v',
                     '--out', self.out])
        far = os.path.join(self.dir.name, 'far.poly')
        with open(far, 'w') as f:
            f.write('far\n1\n -70 -40\n -69 -40\n -69 -39\n -70 -40\nEND\nEND\n')
        self.assertEqual(rp.main([self.root, far, '--land', 'xx', '--bau', 'b',
                                  '--valhalla', 'v', '--out', self.out]), 1)
        self.assertEqual(rp.main([self.root, poly, '--land', 'ch', '--bau', 'b',
                                  '--valhalla', 'v', '--out', self.out]), 0)


if __name__ == '__main__':
    unittest.main()
