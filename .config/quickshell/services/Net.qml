pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager via nmcli.
//
// State is refreshed by `nmcli monitor`, a long-lived process that prints a
// line whenever anything changes — so the common case costs nothing. The timer
// is only a safety net for the case where the monitor dies. The AP scan is the
// expensive call, so it runs only while the network list is actually open.
Item {
    id: root

    property bool available: true
    property bool wifiEnabled: false
    property string ssid: ""
    property int strength: 0
    property bool wired: false
    property bool connecting: false

    // Populated only while `scanning` is true.
    property var networks: []
    property bool scanning: false

    readonly property bool connected: ssid !== "" || wired

    readonly property string subtitle: {
        if (!available) return "Unavailable"
        if (!wifiEnabled) return wired ? "Wired" : "Off"
        if (connecting) return "Connecting…"
        return ssid !== "" ? ssid : "Not Connected"
    }

    readonly property string icon: {
        if (wired && ssid === "") return "󰈁"
        if (!wifiEnabled) return "󰤮"
        if (ssid === "") return "󰤯"
        if (strength >= 75) return "󰤨"
        if (strength >= 50) return "󰤥"
        if (strength >= 25) return "󰤢"
        return "󰤟"
    }

    function refresh() { statusProc.running = true }

    // Split one -t (terse) nmcli line on unescaped colons.
    //
    // nmcli escapes a literal colon inside a field as "\:", so the obvious
    // split(":") mangles SSIDs that contain one. A lookbehind regex would be
    // the tidy fix, but Qt's JS engine does not support lookbehind — it throws
    // at parse time and takes the whole handler down silently — so this walks
    // the string instead.
    function splitFields(line) {
        const out = []
        let field = ""
        for (let i = 0; i < line.length; i++) {
            const c = line[i]
            if (c === "\\" && i + 1 < line.length) {
                field += line[++i]      // keep the escaped character verbatim
            } else if (c === ":") {
                out.push(field)
                field = ""
            } else {
                field += c
            }
        }
        out.push(field)
        return out
    }

    function setEnabled(on) {
        root.wifiEnabled = on           // optimistic, monitor corrects it
        action(["nmcli", "radio", "wifi", on ? "on" : "off"])
    }

    function toggle() { setEnabled(!wifiEnabled) }

    function connect(name) {
        root.connecting = true
        action(["nmcli", "device", "wifi", "connect", name])
    }

    function disconnectNetwork(name) { action(["nmcli", "connection", "down", "id", name]) }

    function action(cmd) {
        actionProc.running = false
        actionProc.command = cmd
        actionProc.running = true
    }

    function startScan() {
        root.scanning = true
        scanProc.running = true
    }

    function stopScan() { root.scanning = false }

    Process {
        id: statusProc
        command: ["sh", "-c",
            "printf 'RADIO %s\\n' \"$(nmcli -t radio wifi 2>/dev/null)\"; " +
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let wifiName = ""
                let hasWired = false
                for (const line of lines) {
                    if (line.startsWith("RADIO ")) {
                        root.wifiEnabled = line.substring(6).trim() === "enabled"
                        continue
                    }
                    const f = line.split(":")
                    if (f.length < 3) continue
                    if (f[0] === "wifi" && f[1] === "connected") wifiName = f[2]
                    if (f[0] === "ethernet" && f[1] === "connected") hasWired = true
                }
                root.ssid = wifiName
                root.wired = hasWired
                root.connecting = false
                if (wifiName !== "")
                    signalProc.running = true
                else
                    root.strength = 0
            }
        }
        onExited: code => { if (code !== 0) root.available = false; else root.available = true }
    }

    Process {
        id: signalProc
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep '^\\*' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(":")
                root.strength = f.length > 1 ? (parseInt(f[1]) || 0) : 0
            }
        }
    }

    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                // One SSID can appear many times, once per access point. Fold
                // them into a single row: strongest signal wins, and the row is
                // "in use" if ANY of its APs is the one we are connected to —
                // keeping only the first sighting would drop the connected AP
                // whenever a stronger one is in range.
                const byName = ({})
                const out = []
                for (const line of this.text.trim().split("\n")) {
                    const f = root.splitFields(line)
                    if (f.length < 4) continue
                    const name = f[1] || ""
                    if (name === "") continue

                    const security = (f[3] || "").trim()
                    const entry = {
                        ssid: name,
                        inUse: f[0].trim() === "*",
                        signal: parseInt(f[2]) || 0,
                        secure: security !== "" && security !== "--"
                    }

                    const existing = byName[name]
                    if (existing) {
                        existing.inUse = existing.inUse || entry.inUse
                        existing.signal = Math.max(existing.signal, entry.signal)
                    } else {
                        byName[name] = entry
                        out.push(entry)
                    }
                }
                out.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
                root.networks = out
            }
        }
    }

    Process { id: actionProc; onExited: settle.restart() }

    // nmcli returns before the state has settled; re-read shortly after.
    Timer {
        id: settle
        interval: 700
        onTriggered: {
            root.refresh()
            if (root.scanning) scanProc.running = true
        }
    }

    // Event stream — one line per NM state change.
    Process {
        id: monitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: monitorDebounce.restart() }
        onExited: monitorRestart.restart()
    }

    Timer { id: monitorDebounce; interval: 250; onTriggered: root.refresh() }
    Timer { id: monitorRestart; interval: 3000; onTriggered: monitor.running = true }

    // Safety net only — the monitor does the real work.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Rescan while the list is open.
    Timer {
        interval: 8000
        running: root.scanning
        repeat: true
        onTriggered: scanProc.running = true
    }
}
