pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// PipeWire volume and sink selection. Uses the native Pipewire binding for
// state (no polling, no wpctl parsing) and only shells out to wpctl for the
// default-sink switch, which the binding does not expose.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink?.audio !== null

    readonly property real volume: available ? (sink.audio.volume ?? 0) : 0
    readonly property bool muted: available ? (sink.audio.muted === true) : true

    // Every sink the picker can offer, newest binding state.
    readonly property var sinks: {
        const out = []
        const nodes = Pipewire.nodes?.values ?? []
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (n.isSink && !n.isStream)
                out.push(n)
        }
        return out
    }

    // Keep the default sink's audio bound so volume/mute stay live.
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    PwObjectTracker { objects: root.sinks }

    function setVolume(value) {
        if (!available)
            return
        sink.audio.volume = Math.min(1.0, Math.max(0.0, value))
    }

    function toggleMute() {
        if (available)
            sink.audio.muted = !sink.audio.muted
    }

    function setSink(node) {
        if (!node)
            return
        setDefault.command = ["wpctl", "set-default", String(node.id)]
        setDefault.running = true
    }

    function iconFor(node) {
        const name = (node?.description || node?.name || "").toLowerCase()
        if (name.includes("bluez") || name.includes("bluetooth")) return "󰂯"
        if (name.includes("hdmi") || name.includes("displayport")) return "󰽟"
        if (name.includes("headphone") || name.includes("headset")) return "󰋋"
        if (name.includes("usb")) return "󰋋"
        return "󰓃"
    }

    readonly property string volumeIcon: {
        if (!available || muted) return "󰝟"
        if (volume < 0.01) return "󰕿"
        if (volume < 0.5) return "󰖀"
        return "󰕾"
    }

    Process { id: setDefault }
}
