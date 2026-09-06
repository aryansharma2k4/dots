//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import "."
import "islands"
import "services"
import "popups"

// Three independent floating islands plus the popups they own. Nothing here is
// a bar with spacers — each island is its own layer-shell surface, so the gaps
// between them are real desktop, not padding.
ShellRoot {
    id: root

    MediaIsland {
        onSinkPickerRequested: x => sinkPicker.openAt(x)
    }

    BarIsland {
        id: barIsland
        // Close the control centre as it hands off to the picker. Two pinned
        // panels would otherwise both hold an exclusive keyboard grab and both
        // run their own idle timer, so the one underneath could time out and
        // vanish while you were still choosing an output.
        onSinkPickerRequested: x => {
            barIsland.closeControlCenter()
            sinkPicker.openAt(x)
        }
    }

    // Summoned by SUPER+SHIFT+W and gone again once it has been used — there is
    // no resting button for it in the bar. It appears in the empty run to the
    // right of the centre island, so it needs that island's live width (it is
    // centred, and its width follows the focused window title).
    WallpaperIsland {
        id: wallpaperIsland
        barWidth: barIsland.islandWidth
    }

    AppIsland {}

    // Sits in the run between the centre island and the app circle, so it needs
    // no coordination with either — both are anchored to their own edges.
    NotificationIsland { id: notifications }

    // Shared by the media card and the control centre's sound row — one picker,
    // one PipeWire subscription, opened from either place.
    SinkPicker {
        id: sinkPicker
        // Opened from the centre island or from the media card, but it always
        // hangs under the bar — so it goes when the bar does.
        hidesWithLauncher: true
    }

    // hyprctl-friendly entry points, so keybinds can drive the shell.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(true) }
    }

    IpcHandler {
        target: "controlCenter"
        function toggle(): void { barIsland.toggleControlCenter() }
        function close(): void { barIsland.closeControlCenter() }
    }

    // SUPER+N opens the notification card without the mouse; the other two are
    // for scripts and for the control centre's Focus tile.
    IpcHandler {
        target: "notif"
        function toggle(): void { notifications.togglePinned() }
        function close(): void { notifications.unpin() }
        function dismissAll(): void { Notif.dismissAll() }
        function dnd(): void { Notif.toggleDnd() }
        function history(): void { barIsland.showNotificationHistory() }
    }

    // SUPER+X, bound in ~/.config/hypr/config/keybinds.lua.
    IpcHandler {
        target: "powerMenu"
        function toggle(): void { barIsland.togglePowerMenu() }
        function close(): void { barIsland.closePowerMenu() }
    }

    // SUPER+SHIFT+N. Swaps the centre island between the floating dynamic
    // island and a flush black macOS-style notch. Also exposed as explicit
    // on/off so a script can put the bar in a known state rather than having to
    // know which one it is in.
    IpcHandler {
        target: "notch"
        function toggle(): void { barIsland.toggleNotch() }
        function on(): void { Theme.notch = true }
        function off(): void { Theme.notch = false }
    }
}
