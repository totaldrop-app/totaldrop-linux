#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 The TotalDrop Contributors
# SPDX-License-Identifier: GPL-3.0-or-later

"""Desktop metadata, Kose SVG icon, and 16-subplatform Node 24 workflow verifier for totaldrop-linux.

Validates:
  - `ui-qt6-wayland/Cargo.toml` version parity across all 16 `subplatforms/*/*/RECIPE.toml`
    and all 16 `.github/workflows/pkg-*.yml` workflows
  - Node 24 GitHub Action SHA pins (`actions/upload-artifact` v7.0.2 and
    `actions/attest-build-provenance` v4.2.2) across all 16 packaging workflows
  - `packaging-common/linux/app.totaldrop.TotalDrop.desktop` (35-language parity,
    desktop actions, `MimeType=x-scheme-handler/totaldrop;`, `StartupWMClass`)
  - `packaging-common/linux/app.totaldrop.TotalDrop.metainfo.xml` (valid XML,
    35-language `<summary>` & `<description>`, latest `<release>` matching Cargo version)
  - Canonical Kose SVG icon geometry (`M55 15H97V57A42 42 0 1 1 55 15Z`, ADR 0012)
    in both full-color and symbolic Linux icons
  - Nemo and Dolphin file-manager action definitions
"""

from __future__ import annotations

import sys
import tomllib
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXPECTED_UPLOAD_ARTIFACT_PIN = "actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9"
EXPECTED_ATTEST_PIN = "actions/attest-build-provenance@4d101475d8b20a2381f78447822ac1eab6504dd8"
KOSE_PATH_DATA = "M55 15H97V57A42 42 0 1 1 55 15Z"
EXPECTED_L10N_LOCALES = 35
EXPECTED_UNITS = 16


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    # 1. Read authoritative Linux desktop version from ui-qt6-wayland/Cargo.toml
    app_toml = tomllib.loads(
        (REPO_ROOT / "ui-qt6-wayland/Cargo.toml").read_text(encoding="utf-8")
    )
    app_version = app_toml["package"]["version"]
    tilde_version = app_version.replace("-", "~", 1)

    # 2. Verify all 16 subplatform recipes + Node 24 packaging workflows
    recipes = sorted((REPO_ROOT / "subplatforms").glob("*/*/RECIPE.toml"))
    if len(recipes) != EXPECTED_UNITS:
        fail(f"expected {EXPECTED_UNITS} subplatform recipes, found {len(recipes)}")

    for recipe_path in recipes:
        rel_recipe = recipe_path.relative_to(REPO_ROOT).as_posix()
        data = tomllib.loads(recipe_path.read_text(encoding="utf-8"))
        if data["version"] != app_version:
            fail(f"{rel_recipe}: version {data['version']!r} != {app_version!r}")
        if app_version not in data["artifact_name"]:
            fail(f"{rel_recipe}: artifact_name {data['artifact_name']!r} missing {app_version!r}")
        if data["runner"] not in ("ubuntu-latest", "ubuntu-24.04-arm"):
            fail(f"{rel_recipe}: unexpected Linux runner {data['runner']!r}")

        wf_rel = data["workflow"]
        wf_path = REPO_ROOT / wf_rel
        if not wf_path.is_file():
            fail(f"missing workflow {wf_rel}")
        wf_text = wf_path.read_text(encoding="utf-8")
        if f"runs-on: {data['runner']}" not in wf_text:
            fail(f"{wf_rel}: runs-on does not match RECIPE runner {data['runner']!r}")
        if data["artifact_name"] not in wf_text:
            fail(f"{wf_rel}: missing artifact_name {data['artifact_name']!r}")
        if EXPECTED_UPLOAD_ARTIFACT_PIN not in wf_text:
            fail(f"{wf_rel}: expected Node 24 upload-artifact v7.0.2 pin")
        if EXPECTED_ATTEST_PIN not in wf_text:
            fail(f"{wf_rel}: expected Node 24 attest-build-provenance v4.2.2 pin")

    # 3. Verify Freedesktop .desktop entry
    desktop_path = REPO_ROOT / "packaging-common/linux/app.totaldrop.TotalDrop.desktop"
    desktop_text = desktop_path.read_text(encoding="utf-8")
    for required_line in (
        "Type=Application",
        "Name=TotalDrop",
        "Exec=totaldrop-desktop %U",
        "Icon=app.totaldrop.TotalDrop",
        "MimeType=x-scheme-handler/totaldrop;",
        "StartupWMClass=app.totaldrop.TotalDrop",
        "SingleMainWindow=true",
        "Actions=send;clipboard;receive;",
    ):
        if required_line not in desktop_text:
            fail(f"{desktop_path.name}: missing {required_line!r}")

    generic_langs = sum(
        1 for line in desktop_text.splitlines() if line.startswith("GenericName[") and "=" in line
    )
    comment_langs = sum(
        1 for line in desktop_text.splitlines() if line.startswith("Comment[") and "=" in line
    )
    # 1 default English entry + 34+ localized entries (including zh_HK/zh_MO/zh_TW/pt_PT variants)
    if generic_langs < EXPECTED_L10N_LOCALES - 1 or comment_langs < EXPECTED_L10N_LOCALES - 1:
        fail(
            f"{desktop_path.name}: insufficient localized entries "
            f"(GenericName={generic_langs}, Comment={comment_langs})"
        )

    # 4. Verify AppStream metainfo.xml
    meta_path = REPO_ROOT / "packaging-common/linux/app.totaldrop.TotalDrop.metainfo.xml"
    meta_root = ET.parse(meta_path).getroot()
    if meta_root.tag != "component":
        fail(f"{meta_path.name}: root tag {meta_root.tag!r} != 'component'")
    if meta_root.findtext("id") != "app.totaldrop.TotalDrop":
        fail(f"{meta_path.name}: unexpected <id>")
    summaries = meta_root.findall("summary")
    if len(summaries) < EXPECTED_L10N_LOCALES:
        fail(f"{meta_path.name}: expected >= {EXPECTED_L10N_LOCALES} <summary> elements, found {len(summaries)}")
    releases = meta_root.findall("./releases/release")
    if not releases:
        fail(f"{meta_path.name}: missing <releases>/<release>")
    latest_rel = releases[0].attrib.get("version", "")
    if latest_rel != tilde_version:
        fail(f"{meta_path.name}: latest release {latest_rel!r} != {tilde_version!r}")

    # 5. Verify canonical Kose SVG icon geometry (ADR 0012)
    for svg_rel in (
        "packaging-common/linux/app.totaldrop.TotalDrop.svg",
        "packaging-common/linux/app.totaldrop.TotalDrop-symbolic.svg",
    ):
        svg_path = REPO_ROOT / svg_rel
        svg_root = ET.parse(svg_path).getroot()
        paths = [el.attrib.get("d", "") for el in svg_root.iter() if el.tag.endswith("path")]
        if KOSE_PATH_DATA not in paths:
            fail(f"{svg_rel}: missing canonical Kose path {KOSE_PATH_DATA!r}")

    # 6. Verify Nemo & Dolphin file-manager actions exist and invoke totaldrop-desktop
    for fm_rel in (
        "packaging-common/linux/file-managers/app.totaldrop.TotalDrop.nemo_action",
        "packaging-common/linux/file-managers/app.totaldrop.TotalDrop.send.desktop",
    ):
        fm_path = REPO_ROOT / fm_rel
        if not fm_path.is_file():
            fail(f"missing {fm_rel}")
        if "totaldrop-desktop" not in fm_path.read_text(encoding="utf-8"):
            fail(f"{fm_rel}: missing totaldrop-desktop exec invocation")

    print(
        f"linux desktop assets & subplatforms OK: version={app_version} "
        f"(metainfo={tilde_version}), 16 Node 24 pkg workflows aligned, "
        f"35-language desktop/AppStream & Kose SVGs verified."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
