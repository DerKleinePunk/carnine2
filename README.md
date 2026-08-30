# Build an CarPC Software for Raspberry 4
Yes i Try Build in with KI this is the Second Reason for create this Repro

## Setup

Before building, ensure you have the required build dependencies installed. See the specific README files for each component:

- [Backend Setup](src/backend/README.md#build-dependencies)
- [Frontend Setup](src/frontend/README.md#build-dependencies)

The root build scripts `build_linux.sh` and `build_pi.sh` generate Dart gRPC stubs from the shared schema at `src/proto/carnine.proto`.

## Build the Raspberry Pi Image

The Raspberry Pi image is built with Debos in the `godebos/debos` container. The repository must be mounted from `/mnt/wsl` when using Podman Desktop with WSL, so that the files are available to the Podman machine.

From the repository's `resources` directory, run:

```sh
cd /mnt/wsl/code/carnine2/resources
set -o pipefail
mkdir -p build-logs
podman run --rm -it --device /dev/kvm \
	--mount "type=bind,source=$(pwd),destination=/work" \
	--workdir /work \
	--security-opt label=disable \
	debos ./debos/raspbian.yaml 2>&1 | \
	tee "build-logs/debos-$(date +%Y%m%d-%H%M%S).log"
```

The recipe uses Dracut and includes the Plymouth `pix` theme. Kernel installation is separated from the final Dracut regeneration to avoid repeated initramfs builds in the ARM64 Fakemachine. A complete build produces `resources/raspbian.img.gz` and `resources/raspbian.img.bmap`. The full build log is kept in `resources/build-logs/`.

On the first boot from an SD card larger than the 3 GiB image, the enabled `expand-rootfs.service` first expands the last root partition and reboots once. On the following boot it expands the ext4 filesystem with `resize2fs` and disables itself. This makes the remaining SD-card capacity available to the system.

The generated image can be written to an SD card manually from Windows. Verify the target device carefully before flashing because writing the image replaces all data on the SD card.

## Architecture Documentation

See the [Arc42 documentation](docs/README.md) for detailed architectural information about the project.

## Resources

- [Sound Resources](resources/sounds/README.md) - Audio files for notifications and UI feedback
