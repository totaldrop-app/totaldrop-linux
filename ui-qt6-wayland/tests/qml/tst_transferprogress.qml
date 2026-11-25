// SPDX-FileCopyrightText: 2026 The TotalDrop Contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtTest
import app.totaldrop

// Progress bar and Kose mark invariants:
// - Zero total never produces NaN (fraction stays 0)
// - 999,999 / 1,000,000 floor-rounds to 99% (never premature 100%)
// - done > total clamps cleanly to 1.0
// - Theme.reducedMotion pauses Mark animation and resets angle to 0
Item {
    id: root
    width: 480
    height: 360

    TestCase {
        id: tc
        name: "TransferProgress"
        when: windowShown

        Component {
            id: progressComponent
            TransferProgress {
                width: 400
                title: "Sending"
                done: 0
                total: 0
            }
        }

        function init() {
            // Fail on any QML property, binding, or reference error while allowing
            // benign software-backend Shape.CurveRenderer fallback notices in headless CI.
            failOnWarning(/ReferenceError|TypeError|Cannot|Unable to|is not defined/)
            Theme.reducedMotion = false
        }

        function cleanup() {
            Theme.reducedMotion = false
        }

        function findLabels(rootItem) {
            const labels = []
            const queue = [rootItem]
            while (queue.length > 0) {
                const node = queue.shift()
                if (node.text !== undefined) {
                    labels.push(String(node.text))
                }
                if (node.children) {
                    for (let i = 0; i < node.children.length; i++) {
                        queue.push(node.children[i])
                    }
                }
            }
            return labels
        }

        function findMark(rootItem) {
            const queue = [rootItem]
            while (queue.length > 0) {
                const node = queue.shift()
                if (node.sending !== undefined && node.moving !== undefined && node.angle !== undefined) {
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

        function test_zero_total_is_safe() {
            const prog = createTemporaryObject(progressComponent, root)
            verify(prog)
            compare(prog.fraction, 0)
            const texts = findLabels(prog)
            verify(texts.indexOf("0%") >= 0, "Expected 0% label, got: " + texts.join(", "))
        }

        function test_floor_rounds_below_one_hundred_percent() {
            const prog = createTemporaryObject(progressComponent, root, {
                done: 999999,
                total: 1000000,
            })
            verify(prog)
            verify(prog.fraction < 1.0)
            const texts = findLabels(prog)
            verify(texts.indexOf("99%") >= 0, "Expected 99% label, got: " + texts.join(", "))
            verify(texts.indexOf("100%") < 0, "Must never display 100% before completion")
        }

        function test_clamps_overflow_and_honors_reduced_motion() {
            const prog = createTemporaryObject(progressComponent, root, {
                done: 2500000,
                total: 1000000,
            })
            verify(prog)
            compare(prog.fraction, 1)

            const mark = findMark(prog)
            verify(mark, "Expected embedded Mark component")
            compare(mark.visible, true)
            compare(mark.sending, true)
            compare(mark.moving, true)

            Theme.reducedMotion = true
            compare(mark.moving, false)
            compare(mark.angle, 0)
        }
    }
}
