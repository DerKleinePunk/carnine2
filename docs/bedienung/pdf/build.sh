#!/usr/bin/env bash
# Build the user guide (docs/bedienung/*.md) as one PDF.
#
# Needs pandoc (>= 3.1) and WeasyPrint (>= 61). On Ubuntu 24.04, as in CI:
#   sudo apt-get install -y pandoc weasyprint fonts-dejavu-core
#
# Usage: docs/bedienung/pdf/build.sh [output.pdf]
#   Default output: build/bedienungsanleitung.pdf in the repository root.
#   GUIDE_VERSION overrides the version on the title page (default: git describe).
#   GUIDE_DATE overrides the date (default: date of the last commit).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
guide="$(dirname "$here")"
root="$(git -C "$guide" rev-parse --show-toplevel)"
out="${1:-$root/build/bedienungsanleitung.pdf}"

# Chapter order, as in the table of contents of README.md: the pages in the
# order of the side menu, then the rest.
pages=(
  README.md
  karte.md
  medien.md
  kamera.md
  technik.md
  optionen.md
  tastatur.md
  verhalten.md
  ton-klinke.md
  image-schreiben.md
  nach-der-installation.md
  befehle.md
)

# A new page must be added above, or it would be missing from the PDF.
for f in "$guide"/*.md; do
  name="$(basename "$f")"
  if [[ ! " ${pages[*]} " == *" $name "* ]]; then
    echo "error: $name is not in the page list of $0" >&2
    exit 1
  fi
done

version="${GUIDE_VERSION:-$(git -C "$root" describe --tags --always --dirty)}"
date="${GUIDE_DATE:-$(git -C "$root" log -1 --format=%cs)}"
# Links to files outside the guide point at the commit the PDF is built from.
repo_url="https://github.com/DerKleinePunk/carnine2/blob/$(git -C "$root" rev-parse HEAD)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Each page on its own, so that the filter knows which page a heading or link is on.
for name in "${pages[@]}"; do
  pandoc --from gfm --to json \
    --metadata repo_url="$repo_url" \
    --lua-filter "$here/guide.lua" \
    --output "$work/${name%.md}.json" \
    "$guide/$name"
done

json=()
for name in "${pages[@]}"; do
  json+=("$work/${name%.md}.json")
done

pandoc --from json --file-scope --to html5 --standalone \
  --template "$here/guide.html" \
  --toc --toc-depth 3 \
  --metadata title="Bedienungsanleitung carnine2" \
  --metadata subtitle="Für Entwickler und Tester" \
  --metadata version="$version" \
  --metadata date="$date" \
  --metadata lang=de \
  --output "$work/guide.html" \
  "${json[@]}"

# Every link inside the guide must have a target.
missing="$(comm -23 \
  <(grep -o 'href="#[^"]*"' "$work/guide.html" | sed 's/^href="#//; s/"$//' | sort -u) \
  <(grep -o ' id="[^"]*"' "$work/guide.html" | sed 's/^ id="//; s/"$//' | sort -u))"
if [[ -n "$missing" ]]; then
  echo "error: links without a target:" >&2
  echo "$missing" >&2
  exit 1
fi

# Every picture must be there. The pictures are in Git LFS; a checkout
# without LFS leaves small text pointers, and WeasyPrint would only log them.
while read -r src; do
  if [[ ! -f "$guide/$src" ]]; then
    echo "error: picture $src is missing" >&2
    exit 1
  fi
  if head -c 40 "$guide/$src" | grep -q "git-lfs"; then
    echo "error: $src is a Git LFS pointer, run 'git lfs pull' (in CI: checkout with lfs: true)" >&2
    exit 1
  fi
done < <(grep -o '<img src="[^"]*"' "$work/guide.html" | sed 's/^<img src="//; s/"$//' | sort -u)

mkdir -p "$(dirname "$out")"
# Base URL is the guide's folder, so that bilder/... resolves. WeasyPrint does
# not fail on a broken picture or stylesheet, it logs ERROR - so the build does.
status=0
weasyprint --base-url "$guide/" --stylesheet "$here/guide.css" \
  "$work/guide.html" "$out" 2> "$work/weasyprint.log" || status=$?
cat "$work/weasyprint.log" >&2
if [[ $status -ne 0 ]] || grep -q "ERROR" "$work/weasyprint.log"; then
  echo "error: WeasyPrint reported errors (see above)" >&2
  exit 1
fi

echo "$out"
