#!/bin/sh
# SPDX-FileCopyrightText: 2026 The TotalDrop Contributors
# SPDX-License-Identifier: GPL-3.0-or-later

# Runs the QML tests in this folder (tst_*.qml) with qmltestrunner,
# without a display. The components under test import app.totaldrop, which
# the app builds with Rust (ui-qt6-wayland/build.rs). Here a stand-in module
# (stub/) gives them a fixed Theme and Strings, and this script copies the
# components into it.
#
#   ui-qt6-wayland/tests/qml/run.sh
#   QMLTESTRUNNER=/path/to/qmltestrunner ui-qt6-wayland/tests/qml/run.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
runner=${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mod="$tmp/app/totaldrop"
mkdir -p "$mod"
cp "$here/stub/qmldir" "$here/stub/Theme.qml" "$here/stub/Strings.qml" "$mod/"
cp \
  "$here/../../qml/ActionCard.qml" \
  "$here/../../qml/Mark.qml" \
  "$here/../../qml/VerificationWords.qml" \
  "$here/../../qml/TransferProgress.qml" \
  "$mod/"
# The platform theme decides which keys press a button; the caller's
# (QT_QPA_PLATFORMTHEME) would make the results differ from CI's.
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= QT_QUICK_BACKEND=software \
  "$runner" -import "$tmp" -input "$here"
