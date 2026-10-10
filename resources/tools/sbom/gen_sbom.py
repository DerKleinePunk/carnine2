#!/usr/bin/env python3
"""SBOM and VEX for the ivi-homescreen checkout the frontend is built with.

ivi-homescreen vendors its C++ dependencies as git submodules. They carry no
package metadata, so syft finds nothing in the bundle and the frontend's CVE
report says nothing about them. This reads the pinned submodule commits out of
git and writes them as CycloneDX components; the ones NVD lists carry a CPE,
because grype matches CPEs and no pkg:github PURL.

  gen_sbom.py --repo-root DIR --output SBOM.cdx.json --vex-output VEX.openvex.json

  grype sbom:SBOM.cdx.json --vex VEX.openvex.json

Written for carnine2 after ivi-homescreen #665 / #746 (2f004565), which does the
same in scripts/gen_sbom.py; our pin (92c2353a) predates that script. The CPE
and VEX tables follow #746, rechecked against our pin (2026-10-10).

Only reads git (.gitmodules, ls-tree, describe, merge-base) and writes the two
files. A submodule missing from DEPENDENCIES is an error: an SBOM without it
would read as "scanned, nothing found".
"""
import argparse
import configparser
import datetime
import json
import re
import subprocess
import sys
import uuid
from pathlib import Path

# Per submodule: SPDX license (from the license file at our pin), the NVD CPE
# as vendor:product or None where NVD has no entry, and the CycloneDX scope.
# "excluded" is not in the delivered binary: googletest only builds the unit
# tests, sanitizers-cmake only brings CMake modules.
DEPENDENCIES = {
    "third_party/asio": ("BSL-1.0", None, "required"),
    "third_party/sanitizers-cmake": ("MIT", None, "excluded"),
    "third_party/cxxopts": ("MIT", None, "required"),
    "third_party/rapidjson": ("MIT", "tencent:rapidjson", "required"),
    "third_party/tomlplusplus": ("MIT", None, "required"),
    "third_party/Vulkan-Headers": ("Apache-2.0 AND MIT", None, "required"),
    "third_party/drm-cxx": ("MIT", None, "required"),
    "third_party/wayland-cxx-scanner": ("MIT", None, "required"),
    "third_party/fmt": ("MIT", "fmt:fmt", "required"),
    "third_party/googletest": ("BSD-3-Clause", None, "excluded"),
}

# Advisories a CPE above matches that do not apply to the pinned commit.
# rapidjson had no release after 1.1.0, so its CPE says 1.1.0 while the pin is
# hundreds of commits later. A not_affected entry names the fixing commit and
# is checked against the pin on every run: a pin moved back before the fix
# stops the run instead of keeping the claim.
# CVE-2024-39684 has no upstream fixing commit to check against and so gets no
# entry; it stays in the report (Michael, 2026-10-10).
VEX = {
    "third_party/rapidjson": [
        {
            "id": "CVE-2024-38517",
            "fixed_by": "8269bc2bc289e9d343bae51cdf6d23ef0950e001",
            "detail": "Integer underflow in GenericReader::ParseNumber(), fixed "
                      "upstream by 8269bc2b \"Prevent int underflow when parsing "
                      "exponents\". The pinned commit descends from it.",
        },
    ],
}

NVD_URL = "https://nvd.nist.gov/vuln/detail/"


def git(args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, check=True,
                          capture_output=True, text=True).stdout.strip()


def submodules(root):
    config = configparser.ConfigParser()
    config.read(Path(root) / ".gitmodules")
    return [(config[s]["path"], config[s]["url"])
            for s in config.sections() if s.startswith("submodule ")]


def pinned_commit(root, path):
    line = git(["ls-tree", "HEAD", path], root)
    if not line:
        raise SystemExit(f"gen_sbom: {path} is in .gitmodules but not in the tree")
    return line.split()[2]


def normalize_version(tag):
    """A tag as a CPE version: v3.3.1 -> 3.3.1, asio-1-36-0 -> 1.36.0."""
    for prefix in ("release-", "v"):
        if tag.startswith(prefix):
            tag = tag[len(prefix):]
            break
    match = re.match(r"^[A-Za-z][A-Za-z0-9_]*-(\d+(?:-\d+)+)$", tag)
    return match.group(1).replace("-", ".") if match else tag


def release_of(work):
    """(version, exact): the tag on the pin, else the last tag before it."""
    try:
        return normalize_version(git(["describe", "--tags", "--exact-match"], work)), True
    except subprocess.CalledProcessError:
        pass
    try:
        return normalize_version(git(["describe", "--tags", "--abbrev=0"], work)), False
    except subprocess.CalledProcessError:
        return None, False


def descends_from(work, commit):
    """"yes", "no" or "unknown" (commit not in the object store, e.g. shallow)."""
    try:
        git(["cat-file", "-e", f"{commit}^{{commit}}"], work)
    except subprocess.CalledProcessError:
        return "unknown"
    try:
        git(["merge-base", "--is-ancestor", commit, "HEAD"], work)
        return "yes"
    except subprocess.CalledProcessError:
        return "no"


def github_slug(url):
    match = re.match(r"^https://github\.com/([^/]+/[^/]+?)(?:\.git)?/?$", url)
    return match.group(1) if match else None


def cpe_for(vendor_product, version):
    vendor, product = vendor_product.split(":")
    return f"cpe:2.3:a:{vendor}:{product}:{version}:*:*:*:*:*:*:*"


def license_entry(spdx):
    if " " in spdx:
        return [{"expression": spdx}]
    return [{"license": {"id": spdx}}]


def build(root):
    """(CycloneDX document, OpenVEX statements) for the checkout at root."""
    root = Path(root)
    found = submodules(root)
    unknown = [path for path, _ in found if path not in DEPENDENCIES]
    if unknown:
        raise SystemExit("gen_sbom: no entry in DEPENDENCIES for " + ", ".join(unknown)
                         + ". Add it with the license file it ships and its NVD CPE.")

    components, vulnerabilities, statements, untagged = [], [], [], []
    for path, url in found:
        spdx, cpe_name, scope = DEPENDENCIES[path]
        commit = pinned_commit(root, path)
        name = Path(path).name
        ref = f"{name}@{commit[:12]}"
        work = root / path
        release, exact = release_of(work) if (work / ".git").exists() else (None, False)
        if cpe_name and not release:
            untagged.append(path)
            continue
        slug = github_slug(url)
        purl = f"pkg:github/{slug}@{commit}" if slug else f"pkg:generic/{name}@{commit}"
        entry = {"bom-ref": ref, "type": "library", "name": name,
                 "version": release if exact else commit, "purl": purl,
                 "scope": scope, "licenses": license_entry(spdx),
                 "externalReferences": [{"type": "vcs", "url": url}]}
        if cpe_name:
            entry["cpe"] = cpe_for(cpe_name, release)
        components.append(entry)

        for vex in VEX.get(path, []) if cpe_name else []:
            state = descends_from(work, vex["fixed_by"])
            if state == "no":
                raise SystemExit(f"gen_sbom: {path} at {commit[:12]} does not contain "
                                 f"{vex['fixed_by'][:12]}, the fix for {vex['id']}. "
                                 "The pin moved; recheck the advisory and VEX.")
            if state == "unknown":
                raise SystemExit(f"gen_sbom: {vex['fixed_by'][:12]} is not in {path}, so "
                                 f"{vex['id']} cannot be checked. Fetch its history: "
                                 f"git -C {work} fetch --unshallow --tags origin")
            vulnerabilities.append({
                "id": vex["id"],
                "source": {"name": "NVD", "url": NVD_URL + vex["id"]},
                "analysis": {"state": "not_affected", "justification": "code_not_present",
                             "detail": vex["detail"]},
                "affects": [{"ref": ref}]})
            # grype matches the product against the component's PURL.
            statements.append({
                "vulnerability": {"name": vex["id"]},
                "products": [{"@id": purl}],
                "status": "not_affected",
                "justification": "vulnerable_code_not_present",
                "impact_statement": vex["detail"]})

    if untagged:
        raise SystemExit("gen_sbom: no tag reachable in " + ", ".join(untagged)
                         + ", so no CPE version. Fetch the tags: "
                         "git submodule foreach 'git fetch --tags origin'")

    try:
        described = git(["describe", "--tags", "--always", "--dirty"], root)
    except subprocess.CalledProcessError:
        described = git(["rev-parse", "HEAD"], root)
    document = {
        "bomFormat": "CycloneDX", "specVersion": "1.6",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}", "version": 1,
        "metadata": {
            "tools": {"components": [{"type": "application", "name": "carnine2 gen_sbom.py"}]},
            "component": {"type": "application", "name": "ivi-homescreen",
                          "version": described,
                          "purl": f"pkg:github/toyota-connected/ivi-homescreen@{described}"}},
        "components": components}
    if vulnerabilities:
        document["vulnerabilities"] = vulnerabilities
    return document, statements


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo-root", required=True, help="the ivi-homescreen checkout")
    parser.add_argument("--output", required=True, help="CycloneDX SBOM to write")
    parser.add_argument("--vex-output", required=True, help="OpenVEX document to write")
    args = parser.parse_args()

    document, statements = build(args.repo_root)
    # One timestamp for both, so they read as a pair.
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    document["metadata"]["timestamp"] = now
    openvex = {"@context": "https://openvex.dev/ns/v0.2.0",
               "@id": f"urn:uuid:{uuid.uuid4()}", "author": "carnine2 build_pi.sh",
               "timestamp": now, "version": 1, "statements": statements}
    for statement in statements:
        statement["timestamp"] = now
    Path(args.output).write_text(json.dumps(document, indent=2) + "\n")
    Path(args.vex_output).write_text(json.dumps(openvex, indent=2) + "\n")
    with_cpe = sum(1 for c in document["components"] if "cpe" in c)
    print(f"gen_sbom: {len(document['components'])} components ({with_cpe} with a CPE), "
          f"{len(statements)} VEX statement(s)")


if __name__ == "__main__":
    sys.exit(main())
