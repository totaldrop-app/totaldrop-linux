// SPDX-FileCopyrightText: 2026 The TotalDrop Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

// Stand-in for ui-qt6-wayland/qml/Strings.qml so headless QML component tests
// run without the compiled Rust cxx-qt Texts singleton.
QtObject {
    readonly property var s: ({
        "verificationTitle": "Verification words",
        "verificationHint": "The other person sees the same four words. If they differ, stop.",
    })
    property bool rtl: false
    property bool draft: false

    function f(key, args) {
        if (key === "progressPercent" && args && args.percent !== undefined) {
            return args.percent + "%"
        }
        return key
    }

    function size(bytes) {
        const n = Number(bytes) || 0
        if (n >= 1000000) {
            return (n / 1000000).toFixed(1) + " MB"
        }
        if (n >= 1000) {
            return (n / 1000).toFixed(1) + " kB"
        }
        return Math.floor(n) + " B"
    }

    function name(text) {
        return String(text || "")
    }
}
