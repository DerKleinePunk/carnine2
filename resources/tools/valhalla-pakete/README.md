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
- The tiles go loose into Valhalla's `tile_dir` (`/var/lib/valhalla/valhalla_tiles`).
- Each country's info and tile list go to `/var/lib/valhalla/pakete/`.
- A whole-area `valhalla_tiles.tar` would win over the loose tiles, so it is moved aside as `valhalla_tiles.tar.vor-laenderpaketen`. It comes back when the last country is removed.
- Only Valhalla restarts.

**Removing a country** deletes only the tiles that no other installed country needs.

## Known limit: loose tiles are slower when warm

Measured on jeep-pi on 2026-11-16 with Germany and Switzerland, 9 routes against Valhalla, 3.9.0:

| | Whole-area tar | Loose tiles |
|---|---|---|
| Cold (empty page cache) | 13.4 s | 12.5 s |
| Warm | 4.2 s | 6.4–7.0 s |

The likely cause is not proven. Valhalla reads loose tiles into its own cache, which is capped by `max_cache_size` at 1 GB while the graph has 6 GB, and drops them again. The tar, by contrast, is memory-mapped and stays in the system's page cache.

There are two ways out, neither built yet:
- build an indexed tar from the folder after installing,
- raise `max_cache_size`.

## Tested

- 2026-11-16, the trial by flutter-local-map: Germany and Switzerland, cut from the DACH graph of 2026-11-02 with this rule and served by Valhalla 3.9.0 on jeep-pi, gave the same routes to the metre as the whole graph. Among them were Zürich–München, Basel–Freiburg and Lugano–Berlin.
- 2026-11-16, device test of this installer on jeep-pi (flutter-local-map):
  - Germany (949 tiles, 2:33 min) and Switzerland (134 tiles, 0:16 min) installed, and only Valhalla restarted.
  - Valhalla used the loose tiles, and all border routes worked.
  - Removing both countries brought the whole-area tar back.
- The tests run in CI: `test_routing_paket.py` here, and the routing part of `resources/debos/tests/carnine-install-maps-test.sh`, which installs packages made by this script.
