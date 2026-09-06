pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// brightnessctl wrapper. Reads on a slow timer (the value only changes when
// something else sets it) and writes immediately on drag, with the local value
// held optimistically so the slider never stutters waiting for the process.
Item {
    id: root

    property bool available: true
    property real value: 0.5        // 0..1
    property int maxBrightness: 0

    // Set while the user is dragging so an in-flight poll cannot yank the
    // handle back to a stale reading.
    property bool dragging: false

    function set(v) {
        const clamped = Math.min(1.0, Math.max(0.01, v))
        root.value = clamped
        writeProc.command = ["brightnessctl", "-m", "set", Math.round(clamped * 100) + "%"]
        writeProc.running = true
    }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // machine-readable: device,class,current,percent%,max
                const f = this.text.trim().split(",")
                if (f.length < 5) {
                    root.available = false
                    return
                }
                root.available = true
                root.maxBrightness = parseInt(f[4]) || 0
                if (!root.dragging) {
                    const pct = parseInt((f[3] || "").replace("%", ""))
                    if (!isNaN(pct))
                        root.value = pct / 100
                }
            }
        }
        onExited: code => { if (code !== 0) root.available = false }
    }

    Process { id: writeProc }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.dragging) readProc.running = true
    }
}
