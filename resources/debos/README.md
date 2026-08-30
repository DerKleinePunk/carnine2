```sh
docker pull godebos/debos
podman pull godebos/debos

cd /mnt/wsl/code/carnine2/resources

set -o pipefail
mkdir -p build-logs
podman run --rm -it --device /dev/kvm --mount "type=bind,source=$(pwd),destination=/work" --workdir /work --security-opt label=disable debos ./debos/raspbian.yaml 2>&1 | tee "build-logs/debos-$(date +%Y%m%d-%H%M%S).log"
```

The image is created as `raspbian.img.gz`; the block map is `raspbian.img.bmap`. The complete build log is stored below `build-logs/`. Flash the image manually from Windows after verifying the selected SD card.

podman-remote system connection add windows-user unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock -d

export CONTAINER_HOST="unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock"
export DOCKER_HOST="unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock"

wget https://github.com/podman-container-tools/podman/releases/download/v6.0.2/podman-remote-static-linux_amd64.tar.gz


podman run --rm -it --device /dev/kvm --mount "type=bind,source=$(pwd),destination=/work" --workdir /work --security-opt label=disable godebos/debos raspbian.yaml

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