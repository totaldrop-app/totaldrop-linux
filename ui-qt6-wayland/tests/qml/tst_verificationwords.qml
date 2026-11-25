// SPDX-FileCopyrightText: 2026 The TotalDrop Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtTest
import app.totaldrop

// Security and accessibility invariants for the 4-word SAS verification banner:
// - Words stay strictly left-to-right even inside a mirrored RTL window (ar/fa/he/ur)
// - Rendered with Text.PlainText so markup cannot inject styled HTML
// - Exposes all four words to screen readers via Accessible.name
TestCase {
    id: tc
    name: "VerificationWords"
    when: windowShown
    width: 480
    height: 240

    Component {
        id: rtlHostComponent
        Item {
            width: 440
            height: 200
            LayoutMirroring.enabled: true
            LayoutMirroring.childrenInherit: true

            property alias banner: vw

            VerificationWords {
                id: vw
                width: parent.width
                words: ["alpha", "bravo", "charlie", "delta"]
            }
        }
    }

    function init() {
        failOnWarning(/.*/)
    }

    function findWordsLabel(rootItem) {
        const queue = [rootItem]
        while (queue.length > 0) {
            const node = queue.shift()
            if (node.text !== undefined && String(node.text).indexOf("  ·  ") >= 0) {
                return node
            }
            if (node.children) {
                for (let i = 0; i < node.children.length; i++) {
                    queue.push(node.children[i])
                }
            }
        }
        return null
    }

    function test_keeps_ltr_order_and_plain_text_under_rtl_mirroring() {
        const host = createTemporaryObject(rtlHostComponent, tc)
        verify(host)
        const banner = host.banner
        verify(banner)

        compare(banner.Accessible.role, Accessible.StaticText)
        compare(banner.Accessible.name, "Verification words: alpha bravo charlie delta")

        const wordsLabel = findWordsLabel(banner)
        verify(wordsLabel, "Expected verification words label")
        compare(wordsLabel.text, "alpha  ·  bravo  ·  charlie  ·  delta")
        compare(wordsLabel.LayoutMirroring.enabled, false)
        compare(wordsLabel.horizontalAlignment, Text.AlignLeft)
        compare(wordsLabel.textFormat, Text.PlainText)
    }

    function test_markup_like_tokens_stay_plain_text() {
        const host = createTemporaryObject(rtlHostComponent, tc)
        verify(host)
        host.banner.words = ["<b>one</b>", "two", "three", "four"]

        const wordsLabel = findWordsLabel(host.banner)
        verify(wordsLabel)
        compare(wordsLabel.text, "<b>one</b>  ·  two  ·  three  ·  four")
        compare(wordsLabel.textFormat, Text.PlainText)
    }
}
