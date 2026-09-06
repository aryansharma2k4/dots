pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// Workspaces, toplevels and the focused window. Quickshell's Hyprland module
// already keeps a socket2 subscription open for us, so everything here is
// event driven — there is no polling in this file.
Item {
    id: root

    readonly property int workspaceCount: 10
    // Guard against the placeholder workspace Hyprland hands back before its
    // data has loaded, whose id is -1. Falling through to 1 keeps the carousel
    // showing a sane window instead of scrolling to a nonexistent workspace.
    readonly property int activeWorkspace: {
        const id = Hyprland.focusedWorkspace?.id ?? -1
        return id > 0 ? id : 1
    }

    // Set of workspace ids that currently hold at least one window. Recomputed
    // only when the workspace list itself changes, not on every repaint.
    property var occupied: ({})

    readonly property var toplevels: Hyprland.toplevels

    // Hyprland keeps reporting the last focused toplevel after you switch to an
    // empty workspace, so the bar would still show a window that is no longer
    // on screen. Treat the active toplevel as absent unless it actually lives
    // on the focused workspace.
    readonly property var activeToplevel: {
        const t = Hyprland.activeToplevel
        if (!t)
            return null
        return (t.workspace?.id ?? -1) === root.activeWorkspace ? t : null
    }

    readonly property string activeTitle: activeToplevel?.title || ""
    readonly property string activeClass: appClass(activeToplevel)

    // The Wayland toplevel is the reliable source: its app id is set the moment
    // the window maps, for xwayland clients too. Hyprland's own IPC object only
    // gains a `class` key after an explicit `j/clients` refresh — the objects
    // built from socket2 events carry just the address and title — so it is a
    // fallback here, not the primary.
    function appClass(toplevel) {
        if (!toplevel)
            return ""
        const obj = toplevel.lastIpcObject
        return (toplevel.wayland?.appId || obj?.class || obj?.initialClass || "").toString()
    }

    function isOccupied(id) { return root.occupied[id] === true }

    // ------------------------------------------------------------ launcher --
    /*
     * Is the Vicinae launcher on screen?
     *
     * Purely event driven, off the socket2 subscription Quickshell already
     * holds — polling hyprctl would put a visible lag between the launcher
     * appearing and the bar getting out of its way, which is the one thing the
     * swap cannot afford.
     *
     * Both of Vicinae's shapes are handled, because which one you get depends
     * on a setting that is meant to be flipped back and forth:
     *
     *   regular window  (layer_shell disabled — the current setup)
     *       openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE   then   closewindow>>ADDRESS
     *       `closewindow` carries only an address, so the address seen at open
     *       time is what identifies it later.
     *
     *   layer surface   (layer_shell enabled — the documented fallback)
     *       openlayer>>NAMESPACE   /   closelayer>>NAMESPACE
     */
    readonly property string launcherClass: "vicinae"
    readonly property string launcherNamespace: "vicinae"

    property string launcherAddress: ""
    property bool launcherLayerOpen: false

    readonly property bool launcherOpen: launcherAddress !== "" || launcherLayerOpen

    function clearLauncher() {
        root.launcherAddress = ""
        root.launcherLayerOpen = false
    }

    function handleLauncherEvent(name, data) {
        if (name === "openwindow") {
            // ADDRESS,WORKSPACE,CLASS,TITLE — the title may itself contain
            // commas, so take the class positionally and never split the rest.
            const parts = (data || "").split(",")
            if (parts.length >= 3 && parts[2] === root.launcherClass)
                root.launcherAddress = parts[0]
        } else if (name === "closewindow") {
            if (data && data === root.launcherAddress)
                root.launcherAddress = ""
        } else if (name === "openlayer") {
            if (data === root.launcherNamespace)
                root.launcherLayerOpen = true
        } else if (name === "closelayer") {
            if (data === root.launcherNamespace)
                root.launcherLayerOpen = false
        }
    }

    // If Vicinae is killed, crashes, or is closed in a way that never reaches
    // us, the open state would stick and the bar would never come back. This is
    // the only thing standing between that and a shell restart.
    Timer {
        id: launcherSafety
        interval: Theme.launcherSafetyMs
        running: root.launcherOpen
        onTriggered: root.clearLauncher()
    }

    // NOTE: this Hyprland is configured through its Lua API (see
    // ~/.config/hypr/config/*.lua), so the IPC `dispatch` payload is a Lua
    // expression, not the classic "workspace 5" string — Hyprland wraps
    // whatever we send in `hl.dispatch(...)`. The classic form parses as Lua
    // and fails silently, which is why every dispatch here is an hl.dsp call.
    function activate(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }

    // Scroll wheel over the carousel: ±1, clamped rather than wrapping.
    function step(delta) {
        const next = Math.min(root.workspaceCount, Math.max(1, root.activeWorkspace + delta))
        if (next !== root.activeWorkspace)
            activate(next)
    }

    function focusWindow(address) {
        if (address)
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + address + "\" })")
    }

    function closeWindow(address) {
        if (address)
            Hyprland.dispatch("hl.dsp.window.close({ window = \"address:0x" + address + "\" })")
    }

    // Flat list of every open window, grouped by application class. Rebuilt on
    // toplevel changes only; the window-list popup binds straight to it.
    property var windowGroups: []

    function rebuild() {
        const occ = ({})
        const list = Hyprland.workspaces?.values ?? []
        for (let i = 0; i < list.length; i++) {
            const ws = list[i]
            const count = ws.toplevels?.values?.length ?? 0
            if (count > 0)
                occ[ws.id] = true
        }
        root.occupied = occ

        const byClass = ({})
        const order = []
        const tops = Hyprland.toplevels?.values ?? []
        for (let j = 0; j < tops.length; j++) {
            const t = tops[j]
            const cls = appClass(t) || "unknown"
            if (!byClass[cls]) {
                byClass[cls] = []
                order.push(cls)
            }
            byClass[cls].push({
                appClass: cls,
                address: t.address,
                title: t.title || cls,
                workspace: t.workspace?.id ?? 0,
                activated: t.activated === true
            })
        }
        root.windowGroups = order.map(cls => ({ appClass: cls, windows: byClass[cls] }))
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name

            root.handleLauncherEvent(n, event.data)

            // Only the events that can change window/workspace membership.
            if (n === "openwindow" || n === "closewindow" || n === "movewindow"
                || n === "windowtitle" || n === "windowtitlev2" || n === "activewindow"
                || n === "activewindowv2" || n === "workspace" || n === "workspacev2"
                || n === "createworkspace" || n === "destroyworkspace")
                debounce.restart()
        }
    }

    // A burst of events arrives when a window opens; coalesce them.
    Timer {
        id: debounce
        interval: 40
        onTriggered: root.rebuild()
    }

    // The first refresh can land before Hyprland is ready to answer, and if the
    // event socket blips during startup nothing else ever asks again — leaving
    // an empty workspace list and a focused workspace whose id is -1 for the
    // life of the process. So keep asking until real data arrives, then stop.
    readonly property bool ready: (Hyprland.workspaces?.values?.length ?? 0) > 0
                                  && (Hyprland.focusedWorkspace?.id ?? -1) > 0

    Timer {
        id: primeTimer
        interval: 250
        repeat: true
        running: !root.ready
        triggeredOnStart: true
        onTriggered: {
            Hyprland.refreshWorkspaces()
            Hyprland.refreshToplevels()
            root.rebuild()
        }
    }

    onReadyChanged: if (ready) rebuild()

    Component.onCompleted: rebuild()
}
