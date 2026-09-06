pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import ".."

/*
 * The wallpaper library, and the current selection.
 *
 * This service deliberately owns almost nothing. ~/.config/scripts already has
 * the whole pipeline — set-wallpaper.sh drives awww and writes the chosen
 * basename to ~/.wall/.current, random-wallpaper.sh picks one — so the shell
 * shells out to those rather than reimplementing the transition flags, and
 * reads the result back out of .current.
 *
 * That indirection is the point: the wallpaper can be changed from the bar,
 * from a keybind, from either script on the command line, or from anything else
 * that writes .current, and the island stays correct in every case because it
 * is watching the file rather than remembering what it last did. Same shape as
 * Theme.qml watching quickshell/theme-mode.
 */
Item {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")

    readonly property string dir: home + "/.wall"
    readonly property string setScript: configDir + "/scripts/set-wallpaper.sh"
    readonly property string shuffleScript: configDir + "/scripts/random-wallpaper.sh"
    readonly property string colorScript: configDir + "/quickshell/scripts/albumcolors.py"

    // ------------------------------------------------------------- library --
    // FolderListModel watches the directory, so dropping a new image into
    // ~/.wall makes it appear in the strip without a shell reload.
    FolderListModel {
        id: files
        folder: "file://" + root.dir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    // Flattened into a plain array once per change: the delegates bind to this
    // rather than to the model, so a repaint never touches the file system.
    property var wallpapers: []

    function rebuild() {
        const out = []
        for (let i = 0; i < files.count; i++) {
            const name = files.get(i, "fileName")
            const path = files.get(i, "filePath")
            if (!name || name.charAt(0) === ".")
                continue
            out.push({ name: name, path: path, url: "file://" + path })
        }
        root.wallpapers = out
    }

    Connections {
        target: files
        function onCountChanged() { root.rebuild() }
        function onStatusChanged() { if (files.status === FolderListModel.Ready) root.rebuild() }
    }

    Component.onCompleted: rebuild()

    // ------------------------------------------------------------- current --
    // set-wallpaper.sh writes the basename here; watching it is what keeps the
    // island honest when the wallpaper is changed from outside the shell.
    property string currentName: ""

    FileView {
        path: root.dir + "/.current"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.currentName = text().trim()
        onFileChanged: reload()
    }

    readonly property int currentIndex: {
        for (let i = 0; i < root.wallpapers.length; i++) {
            if (root.wallpapers[i].name === root.currentName)
                return i
        }
        return -1
    }

    readonly property string currentUrl: currentIndex >= 0 ? wallpapers[currentIndex].url : ""

    // ------------------------------------------------------------- actions --
    function apply(path) {
        if (path)
            Quickshell.execDetached([root.setScript, path])
    }

    function applyIndex(i) {
        if (i >= 0 && i < root.wallpapers.length)
            apply(root.wallpapers[i].path)
    }

    // Wraps rather than clamping — unlike the workspace carousel, where running
    // off the end means something. Here the list is a ring.
    function step(delta) {
        const n = root.wallpapers.length
        if (n === 0)
            return
        const base = currentIndex >= 0 ? currentIndex : 0
        applyIndex(((base + delta) % n + n) % n)
    }

    function shuffle() { Quickshell.execDetached([root.shuffleScript]) }

    // ------------------------------------------------------------- accents --
    /*
     * The dominant colour of a wallpaper, for the rim around its thumbnail and
     * around the island itself.
     *
     * scripts/albumcolors.py is reused unchanged — it takes any file:// URL and
     * quantises it, and nothing in it is specific to album art. Results are
     * cached by filename for the life of the shell: the extraction costs a
     * python start plus a decode, which is fine once per image and much too
     * expensive on every hover.
     *
     * `accentRevision` exists so `accentOf()` participates in bindings. A plain
     * function call captures no dependency, so without something to bump, a rim
     * bound to accentOf(name) would keep whatever colour it had when it was
     * first evaluated and never pick up the resolved one.
     */
    property var accentCache: ({})
    property int accentRevision: 0

    function accentOf(name) {
        root.accentRevision            // dependency, see above
        const c = root.accentCache[name]
        return c ? c : Theme.accent
    }

    function resolveAccent(name) {
        if (!name || root.accentCache[name] || pending.indexOf(name) !== -1)
            return
        pending.push(name)
        pump()
    }

    property var pending: []
    property string inFlight: ""

    // One python at a time. Hovering along the strip queues a handful of names
    // in a moment, and starting a process per hover would spawn faster than
    // they finish.
    function pump() {
        if (root.inFlight !== "" || root.pending.length === 0)
            return
        const name = root.pending.shift()
        const entry = root.wallpapers.find(w => w.name === name)
        if (!entry) {
            pump()
            return
        }
        root.inFlight = name
        colorProc.command = ["python3", root.colorScript, entry.url]
        colorProc.running = true
    }

    Process {
        id: colorProc
        stdout: StdioCollector {
            onStreamFinished: {
                const name = root.inFlight
                try {
                    const c = JSON.parse(this.text.trim())
                    if (c.ok === true && name !== "") {
                        root.accentCache[name] = c.glow
                        root.accentRevision++
                    }
                } catch (e) {
                    // A wallpaper we cannot quantise just keeps Theme.accent.
                }
                root.inFlight = ""
                root.pump()
            }
        }
    }

    // The current wallpaper's colour is always worth having — it is what the
    // collapsed island wears.
    onCurrentNameChanged: resolveAccent(currentName)
}
