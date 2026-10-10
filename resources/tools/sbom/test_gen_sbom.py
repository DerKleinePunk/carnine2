#!/usr/bin/env python3
"""Tests for gen_sbom.py. Run: python3 -m unittest test_gen_sbom.py

Each test builds a small superproject with real git submodules in a temporary
directory, so the git calls run as they do on the ivi-homescreen checkout.
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import gen_sbom

GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid",
           "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
           "GIT_ALLOW_PROTOCOL": "file"}


def git(cwd, *args):
    return subprocess.run(["git", "-c", "protocol.file.allow=always", *args], cwd=cwd,
                          check=True, capture_output=True, text=True,
                          env={**os.environ, **GIT_ENV}).stdout.strip()


def commit(repo, name):
    (Path(repo) / name).write_text(name)
    git(repo, "add", name)
    git(repo, "commit", "-q", "-m", name)
    return git(repo, "rev-parse", "HEAD")


class Fixture(unittest.TestCase):
    """A superproject with rapidjson (tag v1.1.0, fix, two commits on) and fmt."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.upstream = {}
        rapidjson = base / "up-rapidjson"
        rapidjson.mkdir()
        git(rapidjson, "init", "-q", "-b", "main")
        commit(rapidjson, "a")
        git(rapidjson, "tag", "v1.1.0")
        self.fix = commit(rapidjson, "fix")
        commit(rapidjson, "b")
        fmt = base / "up-fmt"
        fmt.mkdir()
        git(fmt, "init", "-q", "-b", "main")
        commit(fmt, "a")
        git(fmt, "tag", "11.2.0")
        self.upstream = {"third_party/rapidjson": rapidjson, "third_party/fmt": fmt}

        self.root = base / "ivi-homescreen"
        self.root.mkdir()
        git(self.root, "init", "-q", "-b", "main")
        commit(self.root, "README")
        git(self.root, "tag", "v1.0.0")
        for path, up in self.upstream.items():
            git(self.root, "submodule", "add", "-q", str(up), path)
        git(self.root, "commit", "-q", "-m", "submodules")

        self.deps = mock.patch.dict(gen_sbom.DEPENDENCIES, {
            "third_party/rapidjson": ("MIT", "tencent:rapidjson", "required"),
            "third_party/fmt": ("MIT", "fmt:fmt", "required")}, clear=True)
        self.vex = mock.patch.dict(gen_sbom.VEX, {"third_party/rapidjson": [
            {"id": "CVE-2024-38517", "fixed_by": self.fix, "detail": "fixed"}]}, clear=True)
        self.deps.start()
        self.vex.start()

    def tearDown(self):
        self.vex.stop()
        self.deps.stop()
        self.tmp.cleanup()

    def component(self, document, name):
        return next(c for c in document["components"] if c["name"] == name)


class BuildTest(Fixture):
    def test_cpe_carries_the_last_tag_and_version_the_commit_past_it(self):
        document, _ = gen_sbom.build(self.root)
        rapidjson = self.component(document, "rapidjson")
        self.assertEqual(rapidjson["cpe"], "cpe:2.3:a:tencent:rapidjson:1.1.0:*:*:*:*:*:*:*")
        pinned = git(self.root / "third_party/rapidjson", "rev-parse", "HEAD")
        self.assertEqual(rapidjson["version"], pinned)
        self.assertEqual(rapidjson["purl"], f"pkg:generic/rapidjson@{pinned}")

    def test_exact_tag_is_the_version(self):
        document, _ = gen_sbom.build(self.root)
        fmt = self.component(document, "fmt")
        self.assertEqual(fmt["version"], "11.2.0")
        self.assertEqual(fmt["cpe"], "cpe:2.3:a:fmt:fmt:11.2.0:*:*:*:*:*:*:*")

    def test_vex_for_a_fix_the_pin_contains(self):
        document, statements = gen_sbom.build(self.root)
        rapidjson = self.component(document, "rapidjson")
        self.assertEqual([s["vulnerability"]["name"] for s in statements], ["CVE-2024-38517"])
        self.assertEqual(statements[0]["products"], [{"@id": rapidjson["purl"]}])
        self.assertEqual(statements[0]["status"], "not_affected")
        self.assertEqual(document["vulnerabilities"][0]["affects"], [{"ref": rapidjson["bom-ref"]}])

    def test_pin_before_the_fix_stops(self):
        work = self.root / "third_party/rapidjson"
        git(work, "checkout", "-q", "v1.1.0")
        git(self.root, "commit", "-q", "-am", "pin back")
        with self.assertRaisesRegex(SystemExit, "does not contain"):
            gen_sbom.build(self.root)

    def test_fix_missing_from_the_object_store_stops(self):
        gen_sbom.VEX["third_party/rapidjson"][0]["fixed_by"] = "0" * 40
        with self.assertRaisesRegex(SystemExit, "cannot be checked"):
            gen_sbom.build(self.root)

    def test_unknown_submodule_stops(self):
        del gen_sbom.DEPENDENCIES["third_party/fmt"]
        with self.assertRaisesRegex(SystemExit, "third_party/fmt"):
            gen_sbom.build(self.root)

    def test_no_tag_for_a_cpe_component_stops(self):
        work = self.root / "third_party/fmt"
        git(work, "tag", "-d", "11.2.0")
        with self.assertRaisesRegex(SystemExit, "no tag reachable in third_party/fmt"):
            gen_sbom.build(self.root)

    def test_missing_checkout_stops(self):
        with self.assertRaisesRegex(SystemExit, "no ivi-homescreen checkout"):
            gen_sbom.build(Path(self.tmp.name) / "nowhere")

    def test_superproject_version(self):
        document, _ = gen_sbom.build(self.root)
        self.assertRegex(document["metadata"]["component"]["version"], r"^v1\.0\.0-1-g")


class LicenseTest(Fixture):
    def setUp(self):
        super().setUp()
        (self.root / "LICENSE").write_text("Apache text\n")
        (self.root / "third_party/rapidjson/license.txt").write_text("rapidjson text\n")
        (self.root / "third_party/fmt/LICENSE").write_text("fmt text\n")
        self.files = mock.patch.dict(gen_sbom.LICENSE_FILES, {
            "": ["LICENSE"], "third_party/rapidjson": ["license.txt"],
            "third_party/fmt": ["LICENSE"]}, clear=True)
        self.files.start()

    def tearDown(self):
        self.files.stop()
        super().tearDown()

    def test_texts_of_ivi_homescreen_and_each_submodule(self):
        text = gen_sbom.license_text(self.root)
        self.assertIn("ivi-homescreen (Apache-2.0), LICENSE\n\nApache text\n", text)
        self.assertIn("rapidjson (MIT), license.txt\n\nrapidjson text\n", text)
        self.assertIn("fmt (MIT), LICENSE\n\nfmt text\n", text)
        self.assertLess(text.index("Apache text"), text.index("rapidjson text"))

    def test_missing_license_file_stops(self):
        (self.root / "third_party/fmt/LICENSE").unlink()
        with self.assertRaisesRegex(SystemExit, "fmt/LICENSE is missing"):
            gen_sbom.license_text(self.root)

    def test_delivered_submodule_without_an_entry_stops(self):
        del gen_sbom.LICENSE_FILES["third_party/fmt"]
        with self.assertRaisesRegex(SystemExit, "no entry in LICENSE_FILES for third_party/fmt"):
            gen_sbom.license_text(self.root)

    def test_excluded_submodule_needs_no_text(self):
        gen_sbom.DEPENDENCIES["third_party/fmt"] = ("MIT", "fmt:fmt", "excluded")
        del gen_sbom.LICENSE_FILES["third_party/fmt"]
        self.assertNotIn("fmt", gen_sbom.license_text(self.root))


class HelperTest(unittest.TestCase):
    def test_normalize_version(self):
        self.assertEqual(gen_sbom.normalize_version("v3.3.1"), "3.3.1")
        self.assertEqual(gen_sbom.normalize_version("asio-1-36-0"), "1.36.0")
        self.assertEqual(gen_sbom.normalize_version("release-1.8.0"), "1.8.0")
        self.assertEqual(gen_sbom.normalize_version("11.2.0"), "11.2.0")

    def test_github_slug(self):
        self.assertEqual(gen_sbom.github_slug("https://github.com/Tencent/rapidjson.git"),
                         "Tencent/rapidjson")
        self.assertEqual(gen_sbom.github_slug("https://github.com/fmtlib/fmt"), "fmtlib/fmt")
        self.assertIsNone(gen_sbom.github_slug("/tmp/up-fmt"))

    def test_license_expression(self):
        self.assertEqual(gen_sbom.license_entry("MIT"), [{"license": {"id": "MIT"}}])
        self.assertEqual(gen_sbom.license_entry("Apache-2.0 AND MIT"),
                         [{"expression": "Apache-2.0 AND MIT"}])

    def test_every_delivered_dependency_has_license_files(self):
        for path, (_, _, scope) in gen_sbom.DEPENDENCIES.items():
            if scope == "required":
                self.assertIn(path, gen_sbom.LICENSE_FILES)

    def test_every_vex_entry_has_a_dependency_with_a_cpe(self):
        for path in gen_sbom.VEX:
            self.assertIsNotNone(gen_sbom.DEPENDENCIES[path][1], path)


if __name__ == "__main__":
    unittest.main()
