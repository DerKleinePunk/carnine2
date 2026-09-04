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
Frontend-Paket enthält das `flutter-pi`-Bundle inklusive Runtime und startet
direkt über DRM/KMS; X11 oder Wayland werden nicht benötigt. Der Benutzer
`carnine` erhält dafür die Gruppen `render`, `video` und `input`.
Das Image installiert außerdem `fontconfig` und `fonts-liberation` als
Systemfont-Ersatz für die vom Flutter-Engine erwartete Arial-Schrift.

Für den Waveshare-Entwicklungs-Pi kann der native Displaymodus aktiviert werden:

```sh
debos -t display=waveshare-1024x600 raspbian.yaml
```

Ohne diesen Parameter bleibt `display=auto` aktiv und die HDMI-Auflösung wird
weiterhin automatisch anhand der Display-Erkennung gewählt.

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