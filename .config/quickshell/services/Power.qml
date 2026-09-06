pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."

// Battery. Renders nothing on a desktop rather than showing a dead cell.
Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery === true && device?.ready === true
    readonly property real percentage: device?.percentage ?? 0
    readonly property bool charging: device ? (device.state === UPowerDeviceState.Charging
                                              || device.state === UPowerDeviceState.FullyCharged) : false

    readonly property string icon: {
        if (!available) return "󰚥"
        if (charging) return "󰂄"
        const steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        return steps[Math.min(10, Math.max(0, Math.round(percentage * 10)))]
    }

    // ------------------------------------------------------- power profile --
    // power-profiles-daemon, cycled by the control-centre tile:
    //   performance -> balanced -> power-saver -> performance
    //
    // Reads are event driven: `gdbus monitor` on the daemon's bus name emits a
    // PropertiesChanged line carrying the new profile inline, so there is no
    // polling here at all. That matters because powerprofilesctl is a Python
    // script — ~0.25s of CPU per invocation, which is far too expensive to put
    // on a timer just to read one string.
    //
    // Writes still go through powerprofilesctl, because setting the profile
    // needs a polkit authorisation that the raw DBus call would not carry.
    property string profile: ""
    property var profiles: []
    readonly property bool profileAvailable: profiles.length > 0

    // Cycle order. The daemon's own list is filtered against this, so a machine
    // that does not offer `performance` simply cycles the two it has instead of
    // trying to select something that would be rejected.
    readonly property var profileOrder: ["performance", "balanced", "power-saver"]

    readonly property string profileLabel: {
        switch (profile) {
        case "performance": return "Power"
        case "balanced": return "Normal"
        case "power-saver": return "Eco"
        }
        return "Unknown"
    }

    readonly property string profileIcon: {
        switch (profile) {
        case "performance": return "󰉁"
        case "balanced": return "󰓅"
        case "power-saver": return "󰌪"
        }
        return "󰓅"
    }

    // The tile is icon-only, so colour is what tells the three modes apart at a
    // glance: hot for performance, neutral for balanced, green for eco.
    readonly property color profileColor: {
        switch (profile) {
        case "performance": return Theme.warning
        case "balanced": return Theme.accent
        case "power-saver": return Theme.success
        }
        return Theme.textDim
    }

    function cycleProfile() {
        if (!profileAvailable)
            return
        const i = root.profiles.indexOf(root.profile)
        setProfile(root.profiles[(i + 1) % root.profiles.length])
    }

    function setProfile(name) {
        if (!name)
            return
        root.profile = name          // optimistic; the monitor confirms it
        setProc.running = false
        setProc.command = ["powerprofilesctl", "set", name]
        setProc.running = true
    }

    Process { id: setProc }

    // Which profiles this machine actually offers, in canonical cycle order.
    Process {
        id: listProc
        running: true
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                for (const line of this.text.split("\n")) {
                    // "  balanced:" or "* power-saver:"
                    const m = line.match(/^[\s*]*([a-z-]+):\s*$/)
                    if (m)
                        found.push(m[1])
                }
                root.profiles = root.profileOrder.filter(p => found.indexOf(p) !== -1)
            }
        }
        onExited: code => { if (code !== 0) root.profiles = [] }
    }

    // Current profile, read once cheaply at startup (busctl is C, unlike
    // powerprofilesctl); the monitor keeps it current from then on.
    Process {
        id: getProc
        running: true
        command: ["busctl", "get-property", "net.hadess.PowerProfiles",
                  "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.match(/"([a-z-]+)"/)
                if (m)
                    root.profile = m[1]
            }
        }
    }

    // Event stream. Each PropertiesChanged line already contains the new value,
    // so no follow-up read is needed.
    Process {
        id: profileMonitor
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "net.hadess.PowerProfiles"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/'ActiveProfile': <'([a-z-]+)'>/)
                if (m)
                    root.profile = m[1]
            }
        }
        onExited: profileMonitorRestart.restart()
    }

    Timer { id: profileMonitorRestart; interval: 3000; onTriggered: profileMonitor.running = true }
}
