pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ over DBus. Every consumer must tolerate `available === false`: a
// machine with no adapter renders a disabled tile, it does not error.
Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled === true
    readonly property bool discovering: available && adapter.discovering === true

    readonly property var devices: {
        const out = []
        const list = Bluetooth.devices?.values ?? []
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            if (d.paired || d.bonded || d.connected)
                out.push(d)
        }
        out.sort((a, b) => (b.connected - a.connected)
                        || (a.name || "").localeCompare(b.name || ""))
        return out
    }

    readonly property var connectedDevice: devices.find(d => d.connected) ?? null

    readonly property string subtitle: {
        if (!available) return "Unavailable"
        if (!enabled) return "Off"
        return connectedDevice ? (connectedDevice.name || "Connected") : "On"
    }

    readonly property string icon: {
        if (!available) return "󰂲"
        if (!enabled) return "󰂲"
        return connectedDevice ? "󰂱" : "󰂯"
    }

    function setEnabled(on) { if (available) adapter.enabled = on }
    function toggle() { setEnabled(!enabled) }

    function toggleDevice(device) {
        if (!device) return
        if (device.connected) device.disconnect()
        else device.connect()
    }

    function deviceIcon(device) {
        const kind = (device?.icon || "").toLowerCase()
        if (kind.includes("headset") || kind.includes("headphone")) return "󰋋"
        if (kind.includes("audio")) return "󰓃"
        if (kind.includes("mouse")) return "󰦋"
        if (kind.includes("keyboard")) return "󰌌"
        if (kind.includes("phone")) return "󰄜"
        return "󰂯"
    }

    // Discovery is power hungry — only run it while a device list is visible.
    function setDiscovering(on) { if (available) adapter.discovering = on }
}
