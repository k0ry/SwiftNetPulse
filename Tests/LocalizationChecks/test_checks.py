#!/usr/bin/env python3
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import importlib.util

spec = importlib.util.spec_from_file_location(
    "check_localization", ROOT / "scripts" / "check-localization.py"
)
checker = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(checker)


class StringsParserTests(unittest.TestCase):
    def test_reordered_numbered_placeholders_match(self):
        self.assertEqual(
            checker.placeholder_signature("%1$@-%2$@"),
            checker.placeholder_signature("%2$@ / %1$@"),
        )

    def test_duplicate_keys_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Localizable.strings"
            path.write_text('"a" = "1";\n"a" = "2";\n', encoding="utf-8")
            with self.assertRaises(checker.CheckError):
                checker.parse_strings(path)

    def test_escapes_and_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Localizable.strings"
            path.write_text(
                '/* c */\n"k" = "line\\nquote:\\""; // trail\n',
                encoding="utf-8",
            )
            table = checker.parse_strings(path)
            self.assertEqual(table["k"], 'line\nquote:"')


class FixtureDirectoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: shutil.rmtree(self.tmp, ignore_errors=True))
        (self.tmp / "en.lproj").mkdir()
        (self.tmp / "ru.lproj").mkdir()
        (self.tmp / "docs").mkdir()
        (self.tmp / "en.lproj" / "Localizable.strings").write_text(
            '"hello" = "Hello %1$@";\n', encoding="utf-8"
        )
        (self.tmp / "ru.lproj" / "Localizable.strings").write_text(
            '"hello" = "Привет %1$@";\n', encoding="utf-8"
        )
        (self.tmp / "README.md").write_text("# Title\n\nSee [dev](DEVELOPMENT.md).\n", encoding="utf-8")
        (self.tmp / "DEVELOPMENT.md").write_text("# Dev\n", encoding="utf-8")
        (self.tmp / "docs" / "ru-readme.md").write_text("# Заголовок\n\n[English](../README.md)\n", encoding="utf-8")
        self.readme_digest = checker.sha256_lf(self.tmp / "README.md")

    def manifest(self, **overrides):
        data = {
            "documents": [
                {
                    "id": "readme",
                    "en": "README.md",
                    "translations": {
                        "ru": {
                            "path": "docs/ru-readme.md",
                            "sourceDigest": self.readme_digest,
                            "status": "current",
                        }
                    },
                }
            ],
            "resources": {
                "en": "en.lproj/Localizable.strings",
                "ru": "ru.lproj/Localizable.strings",
            },
            "licensePlaceholders": [],
            "draftMarkers": [],
        }
        data.update(overrides)
        path = self.tmp / "translations.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def test_good_tree_passes(self):
        errors = checker.run_checks(self.tmp, self.manifest())
        self.assertEqual(errors, [])

    def test_missing_key_is_detected(self):
        (self.tmp / "ru.lproj" / "Localizable.strings").write_text("", encoding="utf-8")
        errors = checker.run_checks(self.tmp, self.manifest())
        self.assertTrue(any("missing keys" in item for item in errors))

    def test_placeholder_mismatch_is_detected(self):
        (self.tmp / "ru.lproj" / "Localizable.strings").write_text(
            '"hello" = "Привет";\n', encoding="utf-8"
        )
        errors = checker.run_checks(self.tmp, self.manifest())
        self.assertTrue(any("placeholder mismatch" in item for item in errors))

    def test_broken_link_is_detected(self):
        (self.tmp / "README.md").write_text("# Title\n\n[x](nope.md)\n", encoding="utf-8")
        self.readme_digest = checker.sha256_lf(self.tmp / "README.md")
        errors = checker.run_checks(self.tmp, self.manifest())
        self.assertTrue(any("broken link" in item for item in errors))

    def test_stale_digest_is_detected(self):
        (self.tmp / "README.md").write_text("# Title changed\n\nSee [dev](DEVELOPMENT.md).\n", encoding="utf-8")
        errors = checker.run_checks(self.tmp, self.manifest())
        self.assertTrue(any("source digest mismatch" in item for item in errors))

    def test_missing_draft_marker_is_detected(self):
        (self.tmp / "LICENSE").write_text("final text", encoding="utf-8")
        manifest = self.manifest(
            draftMarkers=[{"file": "LICENSE", "text": "DRAFT"}]
        )
        errors = checker.run_checks(self.tmp, manifest)
        self.assertTrue(any("missing draft marker" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
