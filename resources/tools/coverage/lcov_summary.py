#!/usr/bin/env python3
"""Summarise an lcov.info coverage report as Markdown.

CI writes the summary into the job overview ($GITHUB_STEP_SUMMARY) and keeps
the (filtered) lcov.info as an artifact. There is no threshold: the report is
there to be read, not to fail a build (Michael, 2026-11-15).

    lcov_summary.py lcov.info --title Backend --root src/backend \
        [--exclude lib/lib/] [--output filtered.info] [--gaps 10]

--root makes absolute paths (cargo llvm-cov writes them) relative to the
project. --exclude drops files whose relative path starts with the prefix,
e.g. the generated gRPC code of the frontend. --output writes the remaining
records as a new lcov.info.
"""

import argparse
import os
import sys


class FileRecord:
    """One SF..end_of_record block: the lines as written, plus the counts."""

    def __init__(self, path):
        self.path = path
        self.lines = []
        self.found = 0
        self.hit = 0
        self._da_found = 0
        self._da_hit = 0
        self._has_totals = False

    def add(self, line):
        self.lines.append(line)
        if line.startswith('DA:'):
            parts = line[3:].split(',')
            self._da_found += 1
            if len(parts) > 1 and parts[1].strip() not in ('0', ''):
                self._da_hit += 1
        elif line.startswith('LF:'):
            self.found = int(line[3:])
            self._has_totals = True
        elif line.startswith('LH:'):
            self.hit = int(line[3:])
            self._has_totals = True

    def finish(self):
        # A report without LF/LH (some writers leave them out) is counted
        # from its DA lines.
        if not self._has_totals:
            self.found = self._da_found
            self.hit = self._da_hit


def parse(text, root=None):
    """The file records of an lcov report, paths relative to root."""
    records = []
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith('SF:'):
            path = line[3:]
            if root and os.path.isabs(path):
                path = os.path.relpath(path, root)
            current = FileRecord(path.replace(os.sep, '/'))
        elif line == 'end_of_record':
            if current is not None:
                current.finish()
                records.append(current)
            current = None
        elif current is not None:
            current.add(line)
    return records


def exclude(records, prefixes):
    return [r for r in records
            if not any(r.path.startswith(p) for p in prefixes)]


def percent(hit, found):
    return '-' if found == 0 else f'{100.0 * hit / found:.1f} %'


def group_key(path, depth):
    """The folder a file is counted under: the first `depth` folders."""
    parts = path.split('/')
    folders = parts[:-1][:depth]
    return '/'.join(folders) + '/' if folders else '(top level)'


def summary(records, title, gaps=10, depth=3):
    found = sum(r.found for r in records)
    hit = sum(r.hit for r in records)
    out = [f'## Coverage: {title}', '',
           f'**{percent(hit, found)} of lines** ({hit} of {found}, '
           f'{len(records)} files). No threshold, report only.', '']
    if not records:
        return '\n'.join(out) + '\n'

    # Three folders: lib/features/media/ in Flutter, src/navigation/ in Rust.
    groups = {}
    for r in records:
        g = groups.setdefault(group_key(r.path, depth), [0, 0])
        g[0] += r.hit
        g[1] += r.found
    out += ['| Folder | Lines | Covered |', '|---|---:|---:|']
    for name, (h, f) in sorted(groups.items(),
                               key=lambda kv: (-(kv[1][1] - kv[1][0]), kv[0])):
        out.append(f'| `{name}` | {h} / {f} | {percent(h, f)} |')
    out.append('')

    worst = sorted((r for r in records if r.found > r.hit),
                   key=lambda r: (-(r.found - r.hit), r.path))[:gaps]
    if worst:
        out += [f'Largest gaps (uncovered lines, top {len(worst)}):', '',
                '| File | Uncovered | Covered |', '|---|---:|---:|']
        for r in worst:
            out.append(f'| `{r.path}` | {r.found - r.hit} | '
                       f'{percent(r.hit, r.found)} |')
        out.append('')
    return '\n'.join(out) + '\n'


def write_lcov(records):
    blocks = []
    for r in records:
        blocks.append('\n'.join(['SF:' + r.path] + r.lines + ['end_of_record']))
    return '\n'.join(blocks) + ('\n' if blocks else '')


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('lcov')
    ap.add_argument('--title', required=True)
    ap.add_argument('--root', help='make absolute paths relative to this')
    ap.add_argument('--exclude', action='append', default=[],
                    help='drop files starting with this relative path')
    ap.add_argument('--output', help='write the filtered lcov.info here')
    ap.add_argument('--gaps', type=int, default=10)
    args = ap.parse_args(argv)

    with open(args.lcov, encoding='utf-8') as f:
        records = parse(f.read(), os.path.abspath(args.root) if args.root else None)
    if not records:
        print(f'{args.lcov}: no coverage records', file=sys.stderr)
        return 1
    records = exclude(records, args.exclude)
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(write_lcov(records))
    sys.stdout.write(summary(records, args.title, args.gaps))
    return 0


if __name__ == '__main__':
    sys.exit(main())
