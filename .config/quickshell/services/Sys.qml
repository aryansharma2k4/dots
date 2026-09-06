pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Odds and ends that are each too small for their own file: dark mode, the
// notification DND daemon, the idle inhibitor, and screenshots.
//
// Everything here probes for its backing tool once at startup and exposes an
// `*Available` flag, so a missing tool renders a disabled control instead of
// silently doing nothing.
Item {
    id: root

    // ------------------------------------------------------------ dark mode --
    property bool darkMode: true

    function setDarkMode(on) {
        root.darkMode = on
        // gsettings for GTK apps, then the user's own switcher for everything
        // else (kitty, fuzzel, dunst, hyprland borders, quickshell/theme-mode).
        run(["sh", "-c",
             "gsettings set org.gnome.desktop.interface color-scheme '"
             + (on ? "prefer-dark" : "prefer-light") + "' 2>/dev/null; "
             + "\"$HOME/.config/scripts/theme-mode.sh\" " + (on ? "dark" : "light")])
    }

    function toggleDarkMode() { setDarkMode(!darkMode) }

    Process {
        id: readMode
        running: true
        command: ["sh", "-c", "cat \"${XDG_CONFIG_HOME:-$HOME/.config}\"/quickshell/theme-mode 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.darkMode = this.text.trim() !== "light"
        }
    }

    // ------------------------------------------------------------- focus/DND --
    // DEAD as of the shell becoming its own notification daemon: Focus is now
    // Notif.dnd, a flag this shell owns, and nothing reads the properties below.
    // Kept only because they are the fallback if that daemon is ever handed
    // back to swaync or mako — see services/Notif.qml.
    //
    // swaync and mako answer different CLIs; detect whichever is running.
    property string dndBackend: ""      // "swaync" | "mako" | ""
    property bool dnd: false
    readonly property bool dndAvailable: dndBackend !== ""

    function toggleDnd() {
        if (dndBackend === "swaync")
            run(["swaync-client", "-d", "-sw"])
        else if (dndBackend === "mako")
            run(["makoctl", "mode", "-s", root.dnd ? "default" : "dnd"])
        else
            return
        root.dnd = !root.dnd
        dndSettle.restart()
    }

    Process {
        id: detectDnd
        running: true
        command: ["sh", "-c",
            "if pgrep -x swaync >/dev/null; then echo swaync; " +
            "elif pgrep -x mako >/dev/null; then echo mako; else echo ''; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.dndBackend = this.text.trim()
                if (root.dndBackend !== "")
                    readDnd.running = true
            }
        }
    }

    Process {
        id: readDnd
        command: ["sh", "-c",
            "if pgrep -x swaync >/dev/null; then swaync-client -D 2>/dev/null; " +
            "elif pgrep -x mako >/dev/null; then makoctl mode 2>/dev/null | grep -qx dnd && echo true || echo false; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.dnd = this.text.trim() === "true"
        }
    }

    Timer { id: dndSettle; interval: 400; onTriggered: readDnd.running = true }

    // ------------------------------------------------------------ screenshot --
    // Region capture, routed through the user's own screenshot script rather
    // than calling grim/slurp here, so the tile behaves exactly like the
    // PRINT keybind already does: same save folder, same clipboard copy, same
    // notification. "region-clipboard" is the mode that selects an area, saves
    // it, and puts the PNG on the clipboard.
    readonly property string screenshotScript:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
        + "/scripts/screenshot.sh"

    property bool screenshotAvailable: false

    function captureRegion() {
        if (!screenshotAvailable)
            return
        // Its own Process, not the shared one-shot: the capture stays alive for
        // as long as the user is dragging out a region, and any other action
        // fired meanwhile would otherwise replace its command and kill it.
        screenshotProc.running = false
        screenshotProc.command = [root.screenshotScript, "region-clipboard"]
        screenshotProc.running = true
    }

    Process { id: screenshotProc }

    Process {
        id: detectScreenshot
        running: true
        command: ["sh", "-c",
            "[ -x '" + root.screenshotScript + "' ] && command -v hyprshot >/dev/null "
            + "&& echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.screenshotAvailable = this.text.trim() === "yes"
        }
    }

    // -------------------------------------------------------- app launcher --
    // Pick the first launcher that actually exists; if none do, the search
    // button disables itself rather than clicking into nothing.
    //
    // vicinae leads the list on purpose: it is what SUPER+SPACE is bound to in
    // the Hyprland config, and it is the class Hypr.launcherOpen watches for to
    // retract the islands. The bar's search button must be the same gesture as
    // the keybind — a second, different launcher on the button would open a
    // window the shell does not recognise and so would not retract for.
    property string launcher: ""
    property var launcherArgs: []
    readonly property bool launcherAvailable: launcher !== ""

    function openLauncher() { if (launcherAvailable) run([launcher].concat(launcherArgs)) }

    Process {
        id: detectLauncher
        running: true
        command: ["sh", "-c",
            "for c in vicinae fuzzel rofi wofi tofi anyrun walker; do " +
            "  command -v \"$c\" >/dev/null && { echo \"$c\"; exit 0; }; " +
            "done; echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = this.text.trim()
                // rofi and wofi need an explicit mode to show applications;
                // vicinae takes `toggle`, so the button closes it again too.
                root.launcher = found
                root.launcherArgs = found === "vicinae" ? ["toggle"]
                                  : found === "rofi" ? ["-show", "drun"]
                                  : found === "wofi" ? ["--show", "drun"]
                                  : []
            }
        }
    }

    // -------------------------------------------------------- idle inhibitor --
    // systemd-inhibit holds the lock for as long as the child process lives, so
    // toggling the inhibitor is just starting and stopping this process.
    readonly property bool idleInhibited: inhibitor.running

    function toggleIdleInhibit() { inhibitor.running = !inhibitor.running }

    Process {
        id: inhibitor
        running: false
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell",
                  "--why=Idle inhibitor", "--mode=block", "sleep", "infinity"]
    }

    // ------------------------------------------------------------------ util --
    function run(cmd) {
        oneShot.running = false
        oneShot.command = cmd
        oneShot.running = true
    }

    Process { id: oneShot }
}
