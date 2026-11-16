#!/usr/bin/env python3
"""Cuts a country routing package out of a full Valhalla tile tree.

    routing_paket.py <valhalla_tiles> <land.poly> --land de \
        --bau dach-2026-11-02 --valhalla 3.9.1 --out <folder>

writes <folder>/routing-<land>/ in the format carnine-install-maps reads (the
same as the map packages of pack_maps.sh): routing-<land>.tar.zst with the
tiles that touch the country, routing-<land>.info.zst (country, build, Valhalla
version, tile count), INHALT, SHA256SUMS and SHA256SUMS.entpackt.

Packages only fit together when they come from the same build of one graph
(e.g. all of Europe): their border tiles are then identical, and a route
crosses from one country into the other as on the whole graph. Packages from
two builds do not; carnine-install-maps refuses to mix them by the build name.

The rule follows the trial of flutter-local-map (2026-11-16, DE+CH from the
DACH graph route to the metre like the whole graph): a tile belongs to the
country when one of its corners or its centre lies inside the polygon, or a
point of the polygon lies inside the tile. The polygon is a Geofabrik .poly
file (osmosis format).
"""

import argparse
import hashlib
import io
import os
import subprocess
import sys
import tarfile

# Valhalla tile levels and their size in degrees.
SIZE = {0: 4.0, 1: 1.0, 2: 0.25}


def read_poly(text):
    """The rings of an osmosis .poly file as (is_hole, [(lon, lat), ...])."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    rings = []
    i = 1  # the first line is the name
    while i < len(lines) and lines[i] != 'END':
        hole = lines[i].startswith('!')
        i += 1
        ring = []
        while lines[i] != 'END':
            lon, lat = lines[i].split()[:2]
            ring.append((float(lon), float(lat)))
            i += 1
        rings.append((hole, ring))
        i += 1
    return rings


def _inside_ring(x, y, ring):
    inside = False
    j = len(ring) - 1
    for i, (xi, yi) in enumerate(ring):
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def inside(x, y, rings):
    return (any(_inside_ring(x, y, r) for hole, r in rings if not hole)
            and not any(_inside_ring(x, y, r) for hole, r in rings if hole))


def tile_of(rel_path):
    """(level, id) of a tile path such as 2/000/791/360.gph."""
    parts = rel_path[:-len('.gph')].split('/')
    return int(parts[0]), int(''.join(parts[1:]))


def bbox(level, tile_id):
    size = SIZE[level]
    row, col = divmod(tile_id, int(360 / size))
    x0, y0 = -180 + col * size, -90 + row * size
    return x0, y0, x0 + size, y0 + size


def tiles_for(tile_paths, rings):
    """The tile paths that belong to the country, sorted."""
    points = [p for _, ring in rings for p in ring]
    with_point = {}
    for level, size in SIZE.items():
        cols = int(360 / size)
        with_point[level] = {int((lat + 90) // size) * cols + int((lon + 180) // size)
                             for lon, lat in points}
    chosen = []
    for rel in tile_paths:
        level, tile_id = tile_of(rel)
        if level not in SIZE:
            continue
        x0, y0, x1, y1 = bbox(level, tile_id)
        probes = ((x0, y0), (x1, y0), (x0, y1), (x1, y1), ((x0 + x1) / 2, (y0 + y1) / 2))
        if tile_id in with_point[level] or any(inside(x, y, rings) for x, y in probes):
            chosen.append(rel)
    return sorted(chosen)


def list_tiles(root):
    found = []
    for base, _, files in os.walk(root):
        for name in files:
            if name.endswith('.gph'):
                found.append(os.path.relpath(os.path.join(base, name), root).replace(os.sep, '/'))
    return found


def write_tar(root, tiles, path):
    """A reproducible tar: sorted, no owner, mtime 0, mode 0644."""
    with tarfile.open(path, 'w', format=tarfile.GNU_FORMAT) as tar:
        for rel in tiles:
            with open(os.path.join(root, rel), 'rb') as f:
                data = f.read()
            info = tarfile.TarInfo(rel)
            info.size = len(data)
            info.mode = 0o644
            info.mtime = 0
            info.uid = info.gid = 0
            info.uname = info.gname = ''
            tar.addfile(info, io.BytesIO(data))


def info_text(land, bau, valhalla, count):
    return (f'# CarNine Routing-Paket\nland={land}\nbau={bau}\n'
            f'valhalla={valhalla}\nkacheln={count}\n')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def write_package(root, tiles, land, bau, valhalla, out, zstd='zstd'):
    """Writes out/routing-<land>/ and returns its path."""
    name = f'routing-{land}'
    folder = os.path.join(out, name)
    os.makedirs(folder, exist_ok=True)
    plain = {}
    plain[f'{name}.info'] = os.path.join(folder, f'{name}.info')
    with open(plain[f'{name}.info'], 'w', encoding='utf-8') as f:
        f.write(info_text(land, bau, valhalla, len(tiles)))
    plain[f'{name}.tar'] = os.path.join(folder, f'{name}.tar')
    write_tar(root, tiles, plain[f'{name}.tar'])

    rows, sums, sums_plain = [], [], []
    # The info first: the installer reads it before it touches anything.
    for file_name in (f'{name}.info', f'{name}.tar'):
        source = plain[file_name]
        packed = source + '.zst'
        subprocess.run([zstd, '-q', '-f', '-T0', source, '-o', packed], check=True)
        rows.append(f'{file_name}.zst\t{os.path.getsize(packed)}\t{os.path.getsize(source)}')
        sums.append(f'{sha256(packed)}  {file_name}.zst')
        sums_plain.append(f'{sha256(source)}  {file_name}')
        os.remove(source)
    for file_name, lines in (('SHA256SUMS', sums), ('SHA256SUMS.entpackt', sums_plain)):
        with open(os.path.join(folder, file_name), 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines) + '\n')
    # INHALT last, as in pack_maps.sh: a package without it is not finished.
    with open(os.path.join(folder, 'INHALT'), 'w', encoding='utf-8') as f:
        f.write('# datei\tgepackt\tentpackt\n' + '\n'.join(rows) + '\n')
    return folder


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('tiles', help='the full Valhalla tile tree (tile_dir)')
    ap.add_argument('poly', help='the country border as Geofabrik .poly')
    ap.add_argument('--land', required=True, help='short name, e.g. de, ch, at')
    ap.add_argument('--bau', required=True,
                    help='name of the graph build, the same for all packages of it')
    ap.add_argument('--valhalla', required=True, help='Valhalla version of the build')
    ap.add_argument('--out', required=True)
    args = ap.parse_args(argv)

    if not args.land.isalnum() or not args.land.islower():
        ap.error('--land: lower-case letters and digits only, e.g. de')
    if any(c.isspace() or c in '=/' for c in args.bau + args.valhalla):
        ap.error('--bau and --valhalla must not contain spaces, "=" or "/"')
    with open(args.poly, encoding='utf-8') as f:
        rings = read_poly(f.read())
    tiles = tiles_for(list_tiles(args.tiles), rings)
    if not tiles:
        print('no tile touches the polygon', file=sys.stderr)
        return 1
    folder = write_package(args.tiles, tiles, args.land, args.bau, args.valhalla, args.out)
    print(f'{folder}: {len(tiles)} tiles')
    return 0


if __name__ == '__main__':
    sys.exit(main())
