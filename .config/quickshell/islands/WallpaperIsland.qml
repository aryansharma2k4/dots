import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../components"
import "../services"

/*
 * WALLPAPER STRIP — summoned, used, gone.
 *
 * Deliberately NOT a permanent island. There is no resting circle sitting in
 * the bar: the shell is idle until SUPER+SHIFT+W, at which point the strip
 * grows out of nothing, and it leaves again the moment it has been used or
 * ignored. Changing wallpaper is a thing you do occasionally and on purpose,
 * so it does not earn a standing seat in the bar the way the clock or the
 * media pill do.
 *
 * The entrance is still the power pill's grow-in-place gesture rather than a
 * popup fading in over the bar — the surface's own width animates open from a
 * dot and shuts back into one — so it belongs to the same family even though
 * the dot it grows from is never actually seen.
 *
 * DRIVING IT. Arrow keys step the library and apply immediately, in both axes,
 * so the strip is usable without ever touching the mouse — press the bind,
 * hold left or right until the wallpaper you want is on screen, press Escape.
 * The wheel does the same thing over the strip, and clicking a tile jumps
 * straight to it.
 *
 * WHERE IT SITS. In the empty run between the centre island and the app circle
 * — the only stretch of bar wide enough for a strip, and empty now that the
 * power button has moved into the centre island's icon cluster.
 */
Scope {
    id: root

    // Width of the centre island's glass, supplied by the shell. That island is
    // horizontally centred and its width changes with the focused window title,
    // so the strip's position has to be derived from it live rather than
    // measured once.
    property int barWidth: 0

    readonly property int pad: 20
    readonly property int diameter: Theme.circleSize

    readonly property int thumbSize: Theme.barHeight - Theme.innerPadding * 2
    readonly property int thumbGap: Theme.innerPadding
    readonly property int stripPad: Theme.innerPadding

    readonly property var items: Wallpaper.wallpapers

    // What the strip would like to be, and what there is actually room for.
    readonly property int naturalWidth: items.length === 0
        ? diameter
        : stripPad * 2 + items.length * thumbSize + (items.length - 1) * thumbGap

    property bool expanded: false

    function collapse() { root.expanded = false }
    function toggle() { root.expanded = !root.expanded }

    PanelWindow {
        id: window

        // Full width and a fixed height. The island is positioned inside the
        // surface rather than by moving the surface, so neither the growing
        // strip nor a change in the centre bar's width ever resizes or
        // repositions a layer surface — only the masked input region moves.
        anchors { top: true; left: true; right: true }
        margins.top: Theme.screenMargin - root.pad
        implicitHeight: root.diameter + root.pad * 2
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // Unmapped while the strip is away. This surface spans the whole output
        // width, and the `quickshell-bar` namespace carries a backdrop-blur
        // layerrule — so left mapped it is the largest per-frame blur on the
        // screen, paid continuously for an island that is summoned by keybind
        // and gone again seconds later.
        //
        // Held open while the close animation finishes.
        visible: root.expanded || surface.opacity > 0.01

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        // Nothing of this island takes input unless the strip is actually out.
        mask: root.expanded ? surfaceMask : emptyMask

        Region { id: surfaceMask; item: surface }
        Region { id: emptyMask }

        // Any key closes, Escape included — matching the control centre and the
        // power pill. An exclusive grab that swallowed keystrokes without acting
        // on them would leave the keyboard feeling dead while the strip is open.
        WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.Exclusive
                                                   : WlrKeyboardFocus.None

        // The strip holds an exclusive keyboard grab while it is open, so it
        // sees every key. Arrows drive the library; anything else dismisses,
        // Escape included, matching the power pill and the control centre.
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (!root.expanded)
                    return

                switch (event.key) {
                case Qt.Key_Left:
                case Qt.Key_Up:
                    Wallpaper.step(-1)
                    away.restart()      // browsing counts as being present
                    break
                case Qt.Key_Right:
                case Qt.Key_Down:
                    Wallpaper.step(1)
                    away.restart()
                    break
                default:
                    root.collapse()
                    break
                }
                event.accepted = true
            }
        }

        readonly property int screenWidth: window.screen ? window.screen.width : 0

        // The centre island is centred, so its right edge sits at
        // (screenWidth + barWidth) / 2 whatever the surface around it is padded
        // by. One island gap past that is where the strip starts.
        readonly property int leftEdge:
            Math.round((screenWidth + root.barWidth) / 2) + Theme.islandGap

        // Room between there and the app circle at the far right, less one gap
        // so the strip never butts up against it.
        readonly property int available:
            screenWidth - Theme.screenMargin - Theme.circleSize - Theme.islandGap
            - leftEdge

        readonly property int pillWidth: Math.max(root.diameter,
                                                  Math.min(root.naturalWidth, available))

        GlassSurface {
            id: surface
            x: window.leftEdge
            y: root.pad
            width: root.expanded ? window.pillWidth : root.diameter
            height: root.diameter
            radius: height / 2

            // Which thumbnail the cursor is over, so the island's own rim can
            // preview that wallpaper's colour before it is applied.
            property string previewName: ""

            // The current wallpaper's own colour, on the same rim the media
            // card uses for album art and on the same crossfade.
            accentRim: Theme.alpha(Wallpaper.accentOf(previewName !== "" ? previewName
                                                                         : Wallpaper.currentName),
                                   0.85)
            // GlassSurface already crossfades its accent rim on Theme.durColor,
            // so there is deliberately no Behavior here.
            accentRimWidth: 1

            // Absent, not merely collapsed. The width animation still runs
            // from the diameter of a circle so the entrance keeps the power
            // pill's shape, but the fade means that circle is never seen — the
            // strip appears to unroll out of nothing.
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: root.expanded ? Theme.durOpen : Theme.durClose
                    easing.type: root.expanded ? Theme.easeStandard : Theme.easeClose
                }
            }

            Behavior on width {
                SequentialAnimation {
                    PauseAnimation { duration: root.expanded ? 0 : Theme.durClose }
                    NumberAnimation {
                        duration: root.expanded ? Theme.durOpen : Theme.durClose
                        easing.type: root.expanded ? Theme.easeOpen : Theme.easeClose
                        easing.overshoot: Theme.easeOpenOvershoot
                    }
                }
            }

            HoverHandler { id: stripHover }

            // Wheel does what the arrow keys do, for whichever hand is
            // already on the mouse. It sits on the surface rather than on the
            // Flickable below so it works whether or not the strip overflows.
            WheelHandler {
                onWheel: event => {
                    Wallpaper.step(event.angleDelta.y > 0 ? -1 : 1)
                    away.restart()
                }
            }

            // ---- expanded face --------------------------------------------
            // Flickable because the strip is clamped to the room available: a
            // library larger than the corridor scrolls rather than running off
            // under the app circle.
            Flickable {
                anchors.fill: parent
                anchors.leftMargin: root.stripPad
                anchors.rightMargin: root.stripPad
                contentWidth: strip.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: root.expanded && contentWidth > width

                Row {
                    id: strip
                    height: parent.height
                    spacing: root.thumbGap

                    Repeater {
                        model: root.items

                        WallpaperThumb {
                            required property var modelData
                            required property int index

                            anchors.verticalCenter: parent.verticalCenter
                            size: root.thumbSize
                            name: modelData.name
                            url: modelData.url
                            current: modelData.name === Wallpaper.currentName

                            revealed: root.expanded
                            revealDelay: index * Theme.powerStagger

                            onChosen: {
                                Wallpaper.apply(modelData.path)
                                root.collapse()
                            }
                            onPreviewRequested: active => {
                                if (active)
                                    surface.previewName = modelData.name
                                else if (surface.previewName === modelData.name)
                                    surface.previewName = ""
                            }
                        }
                    }
                }
            }

        }

        // Closing drops the hover preview, so the rim crossfades back to the
        // current wallpaper's colour instead of keeping the last one hovered.
        Connections {
            target: root
            function onExpandedChanged() { if (!root.expanded) surface.previewName = "" }
        }

        // Never closes under the cursor: this only runs once the pointer has
        // left, and re-entering stops it, which resets it too.
        Timer {
            id: away
            interval: Theme.idleDismiss
            running: root.expanded && !stripHover.hovered
            onTriggered: root.collapse()
        }
    }

    // hyprctl-friendly entry points. SUPER+SHIFT+W is already bound to
    // `qs ipc call ... toggleWallpaper` in ~/.config/hypr/config/keybinds.lua.
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle() }
        function open(): void { root.expanded = true }
        function close(): void { root.collapse() }
        function next(): void { Wallpaper.step(1) }
        function previous(): void { Wallpaper.step(-1) }
        function shuffle(): void { Wallpaper.shuffle() }
        function current(): string { return Wallpaper.currentName }
    }
}
