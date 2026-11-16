# Country routing packages for Valhalla

`routing_paket.py` cuts the routing tiles of one country out of a whole Valhalla graph. On the device, `carnine-install-maps` loads such a package next to the others:

- Germany and Switzerland can be loaded one at a time.
- Once both are installed, Valhalla routes across the border as if it had the whole graph.

## Making a package

```sh
python3 routing_paket.py <valhalla_tiles> germany.poly --land de \
    --bau europa-2026-11-02 --valhalla 3.9.1 --out <folder>
```

- `<valhalla_tiles>` is the tile tree of the whole graph (Valhalla's `tile_dir`).
- `germany.poly` is the country border from Geofabrik, for example `https://download.geofabrik.de/europe/germany.poly`.
- `--bau` names the build of the graph. Every package cut from the same build carries the same name.
- The output is `<folder>/routing-de/`, in the same format as the map packages: `routing-de.info.zst`, `routing-de.tar.zst`, `INHALT`, `SHA256SUMS` and `SHA256SUMS.entpackt`.

**Which tiles a country gets:** a tile belongs to it when one of its corners or its centre lies inside the border, or a point of the border lies inside the tile. Tiles at the border therefore end up in both neighbouring packages.

## On the device

```sh
sudo carnine-install-maps --dir /media/stick/routing-de --package routing-de
sudo carnine-install-maps --link <share-link> --package routing-ch
carnine-install-maps --list-routing
sudo carnine-install-maps --remove-routing de
```

**Same build only.** All countries must come from the same build. A package from another build is refused (exit code 4), because the border tiles of two separate builds do not fit together.

**What the installer does:**
- All installed countries together make up one `valhalla_tiles.tar`, which Valhalla reads just as it reads a whole-area one: memory-mapped, and kept in the system's page cache.
  - **The first country:** a whole-area tar is moved aside as `valhalla_tiles.tar.vor-laenderpaketen`.
  - **Every change rewrites the tar:** each country added or removed writes the tar anew, the way `valhalla_build_extract` writes it, with `index.bin` in front. The index lists each tile's data offset, graph id and size, so Valhalla starts as fast as with a whole-area extract.
    - The tiles are copied straight from the old tar and the package; nothing is unpacked.
    - Each tile is in the tar once.
    - While the new tar is written, there must be room for it next to the old one.
- Each country's info and tile list go to `/var/lib/valhalla/pakete/`.
- Only Valhalla restarts.

**Removing a country** takes out only the tiles that no other installed country needs. The last country takes the tar away with it, and the whole-area tar comes back.

**A whole-area map package installed later** replaces the countries. Their records go, and the tar put aside for them is then out of date.

## Why one tar and not loose tiles

The first version (#184) put the tiles loose into Valhalla's `tile_dir`. On jeep-pi on 2026-11-16 (Germany and Switzerland, 9 routes, Valhalla 3.9.0) that was slower once warm:

| | Whole-area tar | Loose tiles |
|---|---|---|
| Cold (empty page cache) | 13.4 s | 12.5 s |
| Warm | 4.2 s | 6.4–7.0 s |

The likely cause, not proven: Valhalla holds loose tiles in its own cache, which `max_cache_size` caps at 1 GB while the graph has 6 GB, and drops them again.

Michael's rule (2026-11-16): country packages must not be slower than the single file. Hence one tar.

**Why the index:** the next version (one tar, still without `index.bin`) was as fast as the whole-area tar once warm, 4.19 s. But Valhalla needed 16.4 s from start to the first route instead of 1.5 s, because without the index it reads every tar header first. With the index, written as `valhalla_build_extract` does it, a DE+CH tar routed warm in 4.24–4.27 s on jeep-pi, against 4.22–4.30 s for the DACH tar.

## Tested

- 2026-11-16, the trial by flutter-local-map: Germany and Switzerland, cut from the DACH graph of 2026-11-02 with this rule and served by Valhalla 3.9.0 on jeep-pi, gave the same routes to the metre as the whole graph. Among them were Zürich–München, Basel–Freiburg and Lugano–Berlin.
- 2026-11-16, device test of the loose-tile version (#184) on jeep-pi (flutter-local-map):
  - Germany (949 tiles, 2:33 min) and Switzerland (134 tiles, 0:16 min) installed, and only Valhalla restarted.
  - All border routes worked.
  - Removing both countries brought the whole-area tar back.
- The tests run in CI: `test_routing_paket.py` here, and the routing part of `resources/debos/tests/carnine-install-maps-test.sh`, which installs packages made by this script.
