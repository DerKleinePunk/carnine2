```sh
docker pull godebos/debos
podman pull godebos/debos

cd /mnt/wsl/code/carnine2/resources

set -o pipefail
mkdir -p build-logs

# Build for all
podman run --rm -it --device /dev/kvm --mount "type=bind,source=$(pwd),destination=/work" --workdir /work --security-opt label=disable godebos/debos -t version:$(cat ../VERSION) ./debos/raspbian.yaml 2>&1 | tee "build-logs/debos-$(date +%Y%m%d-%H%M%S).log"

# Build for Waveshare
podman run --rm -it --device /dev/kvm --mount "type=bind,source=$(pwd),destination=/work" --workdir /work --security-opt label=disable godebos/debos -t display:waveshare-1024x600 -t version:$(cat ../VERSION) -t "ssh_public_key:$(cat "$HOME/.ssh/id_ed25519.pub")" ./debos/raspbian.yaml 2>&1 | tee "build-logs/debos-$(date +%Y%m%d-%H%M%S).log"

# Verify the SSH key in the resulting image
./debos/verify-image-ssh.sh raspbian-1024x600.img.gz "$HOME/.ssh/id_ed25519.pub"
```

The image is created as `raspbian.img.gz`; the block map is `raspbian.img.bmap`. The complete build log is stored below `build-logs/`. Flash the image manually from Windows after verifying the selected SD card.

On first boot, `expand-rootfs.service` expands the last root partition to the end of the SD card, reboots once, and then runs `resize2fs` on the next boot. The service disables itself after the filesystem expansion.

podman-remote system connection add windows-user unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock -d

export CONTAINER_HOST="unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock"
export DOCKER_HOST="unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock"

wget https://github.com/podman-container-tools/podman/releases/download/v6.0.2/podman-remote-static-linux_amd64.tar.gz


podman run --rm -it --device /dev/kvm --mount "type=bind,source=$(pwd),destination=/work" --workdir /work --security-opt label=disable godebos/debos raspbian.yaml

Vor dem Debos-Lauf muss `build_pi.sh` ausgeführt werden. Das Script baut die
beiden ARM64-Debian-Pakete und legt sie als `resources/debos/carnine-backend.deb`
und `resources/debos/carnine-frontend.deb` für das Image-Rezept ab. Das
Frontend-Paket enthält das ivi-homescreen-Bundle (emb_cli, ADR-020) inklusive
Engine und startet direkt über DRM/KMS; X11 oder Wayland werden nicht benötigt.
Den DRM-Zugriff vermittelt `seatd`, das `install-deb` als Abhängigkeit des
Frontend-Pakets mitinstalliert. Der Benutzer `carnine` erhält die Gruppen
`render`, `video` und `input`.
Das Image installiert außerdem `fontconfig` und `fonts-liberation` als
Systemfont-Ersatz für die vom Flutter-Engine erwartete Arial-Schrift.

### Karte und Navigation (ADR-021)

Das Rezept installiert zusätzlich `resources/debos/carnine-valhalla.deb`. Das
Paket enthält `valhalla_service` 3.9.0, `libprime_server`, die Konfiguration
`/etc/valhalla/valhalla.json` und `valhalla.service`. Die übrigen
Laufzeitbibliotheken zieht `install-deb` über die Paketabhängigkeiten nach.
Valhalla wird nicht im Build gebaut, das dauert auf dem Pi Stunden. Das Paket
entsteht aus einem Pi, auf dem Valhalla schon läuft:

```sh
resources/valhalla/package-deb.sh pi@carnine-pc resources/debos/carnine-valhalla.deb
```

Statt `user@host` geht auch ein Verzeichnis mit `valhalla_service` und
`libprime_server.so.0*`.

Außerdem legt das Rezept `/etc/carnine/config.d/10-navigation.toml` aus
`resources/config/config.d/` ab, mit Replay-Tour, Valhalla und
Namensdatenbank. `deploy_pi.sh` überschreibt nur `config.toml`, das Drop-in
bleibt erhalten.

**Die Kartendaten sind nicht im Image.** Kacheln, Namensdatenbank, Tour und
Valhalla-Kacheln sind zusammen etwa 7,5 GB groß und würden das Image mehr als
verdreifachen. Nach dem ersten Start bringt sie `deploy_maps.sh` auf das Gerät:

```sh
./deploy_maps.sh pi@carnine-pc
```

Das Skript liest aus `~/develop/carnine-maps` (anders mit `CARNINE_MAPS_DIR`),
prüft jede Datei gegen die `SHA256SUMS` in ihrem Ordner, vorher auch den Platz
auf dem Gerät, und startet danach Valhalla, Backend und Frontend neu. Vorgabe
ist Hessen wie im Paket für Tester; mit `--dach` kommen Deutschland,
Österreich und die Schweiz aus `~/develop/carnine-maps/dach` (anders mit
`CARNINE_DACH_DIR`), so laufen unsere eigenen Testgeräte. `map_region` im
Drop-in folgt der Region.

Ohne Entwicklungsrechner, z. B. bei Testern, holt sich das Gerät ein
Kartenpaket selbst:

```sh
sudo carnine-install-maps                 # fragt nach dem Freigabe-Link
sudo carnine-install-maps --dir /media/…  # Paketordner, z. B. auf einem USB-Stick
```

Ein Paket (Vorgabe `karten-hessen`) ist ein Ordner mit je einer `.zst` pro
Datei, `INHALT` (Größen gepackt/entpackt), `SHA256SUMS` und
`SHA256SUMS.entpackt`. Der Link (Nextcloud-Freigabe) steht nicht im Image, ihn
gibt heraus, wer das Paket weitergibt. Das Skript prüft vorher den Platz, setzt
abgebrochene Downloads beim nächsten Aufruf fort, stoppt die Dienste erst,
wenn alles geladen und geprüft ist, und überspringt Dateien, die schon
installiert sind. Tests: `sh tests/carnine-install-maps-test.sh`.

Gebaut werden die Daten nicht in carnine2, sondern mit den Skripten im
Kartenprojekt `DerKleinePunk/flutter_local_map` (`scripts/tilemaker.sh`,
`scripts/extract_names_to_sqlite.py`, `scripts/valhalla/`). Welche Datei
woher kommt und wie neue Daten auf das Gerät gelangen, steht in
`docs/07-deployment.md`, Abschnitt „Where the map data comes from“. Die
fertigen Dateien liegen in keinem Repository, sondern nur in
`~/develop/carnine-maps` und auf den Geräten.

Bis die Daten da sind, gilt:

- `valhalla.service` bleibt inaktiv, weil seine Bedingung
  `ConditionPathExists` noch nicht erfüllt ist.
- Das Backend meldet, dass das Replay nicht gestartet wurde, und läuft ohne
  GPS-Fix weiter.
- Die Kartenseite zeigt ihren Fehlerhinweis.

Die SD-Karte braucht deshalb mindestens 16 GB, besser 32 GB.
Messestand und Testgerät haben 64 GB.

Für den Waveshare-Entwicklungs-Pi kann der native Displaymodus aktiviert werden:

```sh
debos -t display=waveshare-1024x600 raspbian.yaml
```

Ohne diesen Parameter bleibt `display=auto` aktiv und die HDMI-Auflösung wird
weiterhin automatisch anhand der Display-Erkennung gewählt.

Der Hostname ist `carnine-pc`, änderbar mit `-t target_hostname:<name>`. Beim
ersten Start hängt `carnine-hostname.service` die letzten vier Stellen der
Seriennummer an, z. B. `carnine-pc-1a2b`, damit mehrere Geräte im selben Netz
unterscheidbar sind (#62). Das passiert einmal. Ein inzwischen von Hand
gesetzter Name bleibt. Tests: `sh tests/carnine-hostname-test.sh`.
Umbenennen am Gerät: `sudo carnine-rename <name>` setzt `/etc/hostname`, die
Zeile `127.0.1.1` in `/etc/hosts` und den laufenden Namen in einem Schritt und
prüft, dass der Name für DHCP und mDNS taugt (Kleinbuchstaben, Ziffern, `-`).
Im Netz gilt er nach einem Neustart. Tests: `sh tests/carnine-rename-test.sh`.

Der Benutzer ist `pi` mit dem Passwort `raspberry`, änderbar mit
`-t rootpassword:<passwort>`. SSH nimmt das Passwort an. Solange `pi` noch
`raspberry` hat, warnt jede Anmeldung (Konsole und SSH) und nennt `passwd`.
Die Prüfung macht `carnine-password-check.service` als root beim Start und
nach jeder Änderung an `/etc/shadow` (`carnine-password-check.path`), die
Meldung kommt aus `/etc/profile.d/carnine-password.sh`. Nach `passwd` ist sie
ohne Neustart weg. Tests: `sh tests/carnine-password-test.sh`. Passwort und
Namen am Gerät ändern: `docs/bedienung/nach-der-installation.md`.

Für ein Gerät mit dem Kfz-Netzteil AuPrV1_1 kommt `-t power_supply:auprv1`
dazu. Dann trägt das Rezept `dtoverlay=gpio-poweroff,active_low=1,gpiopin=5`
ein, das Signal „Pi ist angehalten“ an Dig3. Ohne Netzteil darf das Overlay
nicht aktiv sein (Kernel-BUG beim Ausschalten), deshalb steht es sonst nur
auskommentiert in `config.txt`. Den UART für das Netzteil (`uart5`, GPIO
12/13) schaltet das Image immer ein, siehe `docs/23-power-supply.md`.

Der Ton kommt ab Werk über HDMI0 (ALSA-Karte 0). Für ein Display ohne
Lautsprecher, z. B. das Waveshare 7C, kommt `-t audio_output:jack` dazu. Dann
wird die Klinke des Pi Karte 0 (`options snd slots=snd_bcm2835,vc4,vc4` in
`/etc/modprobe.d/carnine-audio.conf`), und das Backend spielt und regelt dort.
Erlaubt sind `hdmi` (Vorgabe) und `jack`, ein anderer Wert bricht den Bau ab
(#64). Umstellen ohne neues Image: `docs/bedienung/ton-klinke.md`. Tests:
`sh tests/carnine-audio-output-test.sh`.

Das Waveshare-Profil läuft unter **Full KMS** (`vc4-kms-v3d`). Das Panel bringt
ein geklontes EDID mit ungeraden Timings mit, die der vc4-Treiber ablehnt — er
fällt dann auf 1920x1080 zurück und das Panel skaliert selbst herunter. Das
Rezept schiebt deshalb per `drm.edid_firmware` ein passendes EDID unter — im
Rootfs *und* über `/etc/dracut.conf.d/carnine-edid.conf` in der Initramfs, weil
vc4 dort schon lädt. Vorgabe ist seit 29.09.2026 das EDID von Waveshare selbst,
`edid/waveshare-7h-260929.bin`. Unser korrigiertes Klon-EDID
`edid/waveshare-1024x600.bin` liegt daneben im Image. Zurück geht es, indem man
in `cmdline.txt` den Dateinamen tauscht. Begründung, Gegenproben und wie der Blob neu erzeugt wird, stehen in
[docs/22-waveshare-display-1024x600.md](../../docs/22-waveshare-display-1024x600.md).

**SBOM und CVE-Bericht des Images (#41):** Das Rezept legt die Paketliste des Images (`/var/lib/dpkg/status` und
`os-release`) neben das Image in `<image>.<audio_output>.sbom-input/`, mit Netzteil zusätzlich `.auprv1`
(`raspbian-1024x600.img.jack.sbom-input`). So überschreibt der Bau der zweiten Variante die erste nicht. Daraus macht
auf dem Host, der syft und grype hat,

```sh
sh debos/image-sbom.sh raspbian-1024x600.img.hdmi.sbom-input
```

`<ordner>.cdx.json`, `.spdx.json` und den Bericht `.grype.txt`. Das ist nur ein Bericht, er bricht nie ab: Die
Debian-Basis hat immer offene CVEs ohne Fix, und die Kernel-Pakete von Raspberry Pi gleicht grype gegen alle
Debian-Kernel-CVEs ab (auf carnine-pc 7308 von 8553 Funden). Zu handeln ist bei Funden mit „FIXED IN“. Die Pakete
`carnine-backend`/`carnine-frontend` bekommen ihre SBOM schon in `build_pi.sh`.

Hinweis zur YAML-Pruefung:

`raspbian.yaml` ist ein Debos-Template und enthaelt deshalb zusaetzlich
Template-Ausdruecke wie `{{ ... }}`. Diese Datei wird nicht mit `yamllint`
geprueft. Die Runtime-Konfiguration liegt als TOML-Datei unter
`resources/config/carnine.toml` und wird durch das Rust-Backend validiert.
Das Image-Rezept installiert sie nach `/etc/carnine/config.toml` und legt den
dedizierten Systembenutzer `carnine` sowie die benoetigten Rechte an.

WSL Share teilen

wichtig der mount point muss unter /mnt/wsl liegen da das geteilt wird zwischen alle wsl instancen und machinen

https://wsl-ui.octasoft.co.uk/blog/podman-desktop-with-remote-client-in-wsl
https://gist.github.com/omarmciver/0c85f5a68448aa6c94fee381e5fdbe9b

Debian Packes Pinnen / Cachen

https://www.aptly.info/

https://salsa.debian.org/debconf-team/public/share/miniconfs/-/raw/main/2026-minidebconf-winterthur/slides/24-you-probably-dont-need-yocto-and-thats-fine-using-debian-for-embedded-systems.pdf?inline=false