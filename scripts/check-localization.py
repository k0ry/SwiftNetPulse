#!/usr/bin/env python3
"""Check SwiftNetPulse documentation and string-resource localization."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

PLACEHOLDER_RE = re.compile(r"%(\d+)\$@|%@")
MD_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)


class CheckError(Exception):
    pass


def sha256_lf(path: Path) -> str:
    data = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(data).hexdigest()


def parse_strings(path: Path) -> Dict[str, str]:
    text = path.read_text(encoding="utf-8")
    result: Dict[str, str] = {}
    i = 0
    n = len(text)
    duplicates: List[str] = []

    def skip_ws_and_comments(pos: int) -> int:
        while pos < n:
            if text[pos] in " \t\r\n":
                pos += 1
                continue
            if text.startswith("/*", pos):
                end = text.find("*/", pos + 2)
                if end < 0:
                    raise CheckError(f"{path}: unterminated block comment")
                pos = end + 2
                continue
            if text.startswith("//", pos):
                end = text.find("\n", pos)
                pos = n if end < 0 else end + 1
                continue
            break
        return pos

    def parse_quoted(pos: int) -> Tuple[str, int]:
        if pos >= n or text[pos] != '"':
            raise CheckError(f"{path}: expected quoted string at {pos}")
        pos += 1
        out: List[str] = []
        while pos < n:
            ch = text[pos]
            if ch == "\\":
                if pos + 1 >= n:
                    raise CheckError(f"{path}: dangling escape")
                nxt = text[pos + 1]
                mapping = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}
                out.append(mapping.get(nxt, nxt))
                pos += 2
                continue
            if ch == '"':
                return "".join(out), pos + 1
            out.append(ch)
            pos += 1
        raise CheckError(f"{path}: unterminated quoted string")

    while True:
        i = skip_ws_and_comments(i)
        if i >= n:
            break
        key, i = parse_quoted(i)
        i = skip_ws_and_comments(i)
        if i >= n or text[i] != "=":
            raise CheckError(f"{path}: expected '=' after key {key!r}")
        i += 1
        i = skip_ws_and_comments(i)
        value, i = parse_quoted(i)
        i = skip_ws_and_comments(i)
        if i >= n or text[i] != ";":
            raise CheckError(f"{path}: expected ';' after value for {key!r}")
        i += 1
        if key in result:
            duplicates.append(key)
        result[key] = value
    if duplicates:
        raise CheckError(f"{path}: duplicate keys: {', '.join(duplicates)}")
    return result


def placeholder_signature(value: str) -> Tuple[int, int]:
    numbered = set()
    sequential = 0
    i = 0
    while i < len(value):
        if value.startswith("%%", i):
            i += 2
            continue
        match = re.match(r"%(\d+)\$@", value[i:])
        if match:
            numbered.add(int(match.group(1)))
            i += match.end()
            continue
        if value.startswith("%@", i):
            sequential += 1
            i += 2
            continue
        i += 1
    max_numbered = max(numbered) if numbered else 0
    return max_numbered, sequential


def github_slug(heading: str) -> str:
    text = heading.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    text = re.sub(r"\s+", "-", text)
    return text


def headings_of(path: Path) -> List[str]:
    text = path.read_text(encoding="utf-8")
    slugs = []
    for match in HEADING_RE.finditer(text):
        slugs.append(github_slug(match.group(2)))
    return slugs


def check_markdown_links(root: Path, path: Path, errors: List[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for match in MD_LINK_RE.finditer(text):
        target = match.group(2).strip()
        if target.startswith("http://") or target.startswith("https://") or target.startswith("mailto:"):
            continue
        if target.startswith("#"):
            fragment = github_slug(target[1:])
            if fragment and fragment not in headings_of(path):
                errors.append(f"{path}: missing heading fragment {target}")
            continue
        file_part, frag = (target.split("#", 1) + [""])[:2]
        resolved = (path.parent / file_part).resolve()
        try:
            resolved.relative_to(root.resolve())
        except ValueError:
            # Allow paths that stay inside the repo even if expressed with ..
            if not resolved.exists():
                errors.append(f"{path}: broken link {target}")
            continue
        if not resolved.exists():
            errors.append(f"{path}: broken link {target}")
            continue
        if frag:
            if github_slug(frag) not in headings_of(resolved):
                errors.append(f"{path}: missing heading fragment in {target}")


def load_manifest(root: Path, manifest_path: Path) -> dict:
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def check_documents(root: Path, manifest: dict, errors: List[str]) -> None:
    for document in manifest.get("documents", []):
        ident = document.get("id", "?")
        en_rel = document.get("en")
        if not en_rel:
            errors.append(f"document {ident} missing en path")
            continue
        en_path = root / en_rel
        if not en_path.exists():
            errors.append(f"{ident}: missing English file {en_rel}")
            continue
        digest = sha256_lf(en_path)
        translations = document.get("translations", {})
        for lang, info in translations.items():
            status = info.get("status")
            rel = info.get("path")
            recorded = info.get("sourceDigest")
            if not rel:
                errors.append(f"{ident}/{lang}: missing path")
                continue
            trans_path = root / rel
            if not trans_path.exists():
                errors.append(f"{ident}/{lang}: missing file {rel}")
                continue
            if status == "missing":
                errors.append(f"{ident}/{lang}: status missing")
                continue
            if recorded != digest:
                if status == "current":
                    errors.append(
                        f"{ident}/{lang}: source digest mismatch (recorded {recorded}, actual {digest})"
                    )
                elif status != "stale":
                    errors.append(f"{ident}/{lang}: unknown status {status}")
            if status == "stale":
                text = trans_path.read_text(encoding="utf-8")
                if "stale" not in text.lower() and "устарел" not in text.lower():
                    errors.append(f"{ident}/{lang}: stale translation lacks a visible warning")
                if status == "stale":
                    errors.append(f"{ident}/{lang}: supported translation is stale")
            check_markdown_links(root, trans_path, errors)
        check_markdown_links(root, en_path, errors)


def check_resources(root: Path, manifest: dict, errors: List[str]) -> None:
    resources = manifest.get("resources", {})
    tables: Dict[str, Dict[str, str]] = {}
    for lang, rel in resources.items():
        path = root / rel
        if not path.exists():
            errors.append(f"missing strings file {rel}")
            continue
        try:
            tables[lang] = parse_strings(path)
        except CheckError as exc:
            errors.append(str(exc))
    if "en" not in tables:
        errors.append("English strings table missing")
        return
    english = tables["en"]
    if not english:
        errors.append("English strings table is empty")
    for lang, table in tables.items():
        extra = set(table) - set(english)
        missing = set(english) - set(table)
        if extra:
            errors.append(f"{lang}: extra keys {sorted(extra)}")
        if missing:
            errors.append(f"{lang}: missing keys {sorted(missing)}")
        for key, en_value in english.items():
            if key not in table:
                continue
            if placeholder_signature(en_value) != placeholder_signature(table[key]):
                errors.append(f"{lang}: placeholder mismatch for {key}")
            if "%(" in table[key] or "%s" in table[key] and "%@" not in table[key]:
                errors.append(f"{lang}: unsupported substitution in {key}")


def check_license_placeholders(root: Path, manifest: dict, errors: List[str]) -> None:
    for item in manifest.get("licensePlaceholders", []):
        ident = item.get("id", "?")
        for lang, needle in item.get("markers", {}).items():
            rel = item.get("files", {}).get(lang)
            if not rel:
                errors.append(f"placeholder {ident}: missing file for {lang}")
                continue
            path = root / rel
            if not path.exists():
                errors.append(f"placeholder {ident}: missing {rel}")
                continue
            text = path.read_text(encoding="utf-8")
            if needle not in text:
                errors.append(f"placeholder {ident}: {rel} lacks {needle!r}")
    for marker in manifest.get("draftMarkers", []):
        rel = marker["file"]
        needle = marker["text"]
        path = root / rel
        if not path.exists():
            errors.append(f"draft marker missing file {rel}")
            continue
        if needle not in path.read_text(encoding="utf-8"):
            errors.append(f"{rel}: missing draft marker {needle!r}")


def run_checks(root: Path, manifest_path: Path) -> List[str]:
    errors: List[str] = []
    manifest = load_manifest(root, manifest_path)
    check_documents(root, manifest, errors)
    check_resources(root, manifest, errors)
    check_license_placeholders(root, manifest, errors)
    return errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=None)
    parser.add_argument("--manifest", default="docs/translations.json")
    args = parser.parse_args(argv)
    root = Path(args.root) if args.root else Path(__file__).resolve().parents[1]
    manifest_path = root / args.manifest if not Path(args.manifest).is_absolute() else Path(args.manifest)
    if not manifest_path.exists():
        print(f"missing manifest {manifest_path}", file=sys.stderr)
        return 2
    errors = run_checks(root, manifest_path)
    if errors:
        print("localization checks failed:")
        for item in errors:
            print(f"  - {item}")
        return 1
    print("localization checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
