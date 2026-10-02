# User guide as PDF

`build.sh` turns the pages of the user guide (`docs/bedienung/*.md`) into one
PDF with a title page, a table of contents with page numbers, PDF bookmarks
and working links between the pages.

```bash
docs/bedienung/pdf/build.sh                 # -> build/bedienungsanleitung.pdf
docs/bedienung/pdf/build.sh /tmp/guide.pdf  # other output file
```

The title page shows `git describe` and the date of the last commit;
`GUIDE_VERSION` and `GUIDE_DATE` override them. Links to files outside the
guide (e.g. `docs/07-deployment.md`) point at that commit on GitHub.

## Tools

| Tool | Version | Ubuntu 24.04 |
|---|---|---|
| pandoc | 3.1.3 | `apt-get install pandoc` |
| WeasyPrint | 61.1 (with pydyf 0.9.0) | `apt-get install weasyprint` |
| DejaVu fonts | | `apt-get install fonts-dejavu-core` |

Without root, the same versions go into the home directory:

```bash
mkdir -p ~/.local/opt ~/.local/bin && cd ~/.local/opt
curl -fsSL https://github.com/jgm/pandoc/releases/download/3.1.3/pandoc-3.1.3-linux-amd64.tar.gz | tar xz
ln -sf ~/.local/opt/pandoc-3.1.3/bin/pandoc ~/.local/bin/pandoc
python3 -m venv weasyprint-61.1
weasyprint-61.1/bin/pip install weasyprint==61.1 pydyf==0.9.0
ln -sf ~/.local/opt/weasyprint-61.1/bin/weasyprint ~/.local/bin/weasyprint
```

WeasyPrint 61 fails with pydyf 0.10 or newer (`PDF.__init__() takes 1
positional argument`), hence the pin.

## Files

| File | Purpose |
|---|---|
| `build.sh` | page order, version, checks, calls pandoc and WeasyPrint |
| `guide.lua` | pandoc filter: one identifier space for all pages, links between pages, headings one level down |
| `guide.html` | pandoc template: title page and table of contents |
| `guide.css` | print layout: A4, page numbers, chapter in the footer, pictures, tables |

## Checks

The build fails when

* a page in `docs/bedienung/` is missing from the page list in `build.sh`
  (a new page has to be added there, in the order of the README's contents),
* a link inside the guide has no target (e.g. a renamed heading).

## In CI (later)

A job on `ubuntu-24.04` needs no more than:

```yaml
user-guide-pdf:
  runs-on: ubuntu-24.04
  steps:
    - uses: actions/checkout@v7
      with:
        fetch-depth: 0   # git describe needs the tags
    - run: sudo apt-get update && sudo apt-get install -y pandoc weasyprint fonts-dejavu-core
    - run: docs/bedienung/pdf/build.sh
    - uses: actions/upload-artifact@v7
      with:
        name: bedienungsanleitung
        path: build/bedienungsanleitung.pdf
```
