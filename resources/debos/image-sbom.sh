#!/bin/sh
# SBOM and CVE report of an image (#41), from the package list the recipe
# keeps next to it (<image>.<audio_output>.sbom-input: var/lib/dpkg/status,
# etc/os-release).
# Only a report: the Debian base always has open CVEs without a fix, so this
# never fails on a finding.
#
#   sh resources/debos/image-sbom.sh resources/raspbian-1024x600.img.hdmi.sbom-input
#
# Writes <input>.cdx.json, <input>.spdx.json and <input>.grype.txt next to it.
# syft and grype come from PATH, or from CARNINE_SYFT / CARNINE_GRYPE.
set -eu

input=${1:?usage: image-sbom.sh <image>.sbom-input}
syft=${CARNINE_SYFT:-syft}
grype=${CARNINE_GRYPE:-grype}
config="$(dirname "$0")/../../.grype.yaml"

if [ ! -f "$input/var/lib/dpkg/status" ] || [ ! -f "$input/etc/os-release" ]; then
  echo "image-sbom: $input has no var/lib/dpkg/status and etc/os-release" >&2
  exit 1
fi
for tool in "$syft" "$grype"; do
  command -v "$tool" >/dev/null 2>&1 || { echo "image-sbom: $tool not found" >&2; exit 1; }
done

out=${input%/}
"$syft" scan "dir:$input" -q --source-name "$(basename "$out" .sbom-input)" \
  -o cyclonedx-json="$out.cdx.json" -o spdx-json="$out.spdx.json"
"$grype" "sbom:$out.cdx.json" -q -c "$config" -o table > "$out.grype.txt" 2>&1 || true
echo "image-sbom: $out.cdx.json, CVE report $out.grype.txt"
grep -oE ' (Critical|High|Medium|Low|Negligible|Unknown) ' "$out.grype.txt" | sort | uniq -c || true
