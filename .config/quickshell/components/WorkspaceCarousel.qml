import QtQuick
import ".."
import "../services"

/*
 * Ten workspaces on a strip, five visible through a fixed-width window.
 *
 * ── THE MATH ───────────────────────────────────────────────────────────────
 *
 * All `total` numerals live in ONE Row of equal-width cells. The Row is a child
 * of a clipping Item exactly `visible * itemWidth` wide. Nothing is created,
 * destroyed, or re-laid-out when the workspace changes — only the Row's `x`
 * moves, which is what makes the slide cheap enough to spring.
 *
 *   startIndex = clamp(active - floor(visible / 2), 1, total - visible + 1)
 *   row.x      = -(startIndex - 1) * itemWidth
 *
 * With visible = 5, total = 10, the centre offset is floor(5/2) = 2:
 *
 *   active 1 -> clamp(-1, 1, 6) = 1  -> x =  0    strip pinned left
 *   active 2 -> clamp( 0, 1, 6) = 1  -> x =  0    still pinned left
 *   active 3 -> clamp( 1, 1, 6) = 1  -> x =  0    3 is now centre of 1..5
 *   active 4 -> clamp( 2, 1, 6) = 2  -> x = -w    window is 2..6, 4 centred
 *   active 7 -> clamp( 5, 1, 6) = 5  -> x = -4w   window is 5..9, 7 centred
 *   active 8 -> clamp( 6, 1, 6) = 6  -> x = -5w   window is 6..10, 8 centred
 *   active 9 -> clamp( 7, 1, 6) = 6  -> x = -5w   pinned right
 *   active 10-> clamp( 8, 1, 6) = 6  -> x = -5w   still pinned right
 *
 * So 1–2 pin to the left edge, 9–10 pin to the right edge, and everything in
 * between rides centred — exactly the macOS-dock-scroll feel. The lower clamp
 * bound is 1 because workspace ids are 1-based; the upper bound
 * `total - visible + 1` is the last start position that still fills the window.
 *
 * ── THE ANIMATION ──────────────────────────────────────────────────────────
 *
 * `x` rides a spring, so the strip carries a little momentum past its target
 * and settles. Font size and weight are NOT swapped on state change — they are
 * animated: pixelSize gets a Behavior, and weight (an int, so it would step)
 * is faked with an animated scale on top of a fixed DemiBold, which is smooth
 * and costs no re-shaping of the glyphs.
 */
Item {
    id: root

    // Tunables.
    property int visibleCount: 5              // how many numerals fit in the window
    property int total: Hypr.workspaceCount
    property int itemWidth: Math.round(Theme.fontSizeWorkspaceActive * 1.25)
    property int activeSize: Theme.fontSizeWorkspaceActive
    property int inactiveSize: Theme.fontSizeWorkspace

    readonly property int active: Hypr.activeWorkspace


    // clamp(active - floor(visible/2), 1, total - visible + 1)
    readonly property int startIndex: Math.min(
        Math.max(1, root.active - Math.floor(root.visibleCount / 2)),
        Math.max(1, root.total - root.visibleCount + 1))

    implicitWidth: visibleCount * itemWidth
    implicitHeight: activeSize + 8
    clip: true

    Row {
        id: strip
        height: parent.height
        spacing: 0

        // The single animated property. Everything else is static layout.
        x: -(root.startIndex - 1) * root.itemWidth

        Behavior on x {
            SpringAnimation {
                spring: 4.0
                damping: 0.55
                mass: 0.6
                epsilon: 0.25
            }
        }

        Repeater {
            model: root.total

            Item {
                id: cell
                required property int index

                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.active
                readonly property bool isOccupied: Hypr.isOccupied(wsId)

                width: root.itemWidth
                height: strip.height

                Text {
                    id: numeral
                    anchors.centerIn: parent
                    text: cell.wsId
                    font.family: Theme.fontUI
                    font.features: Theme.tabularFigures
                    // Weight is animated via scale rather than switched, so the
                    // transition is continuous instead of a glyph swap.
                    font.weight: Font.DemiBold
                    font.pixelSize: cell.isActive ? root.activeSize : root.inactiveSize

                    // Bar-scoped, not the plain text tokens: this carousel is
                    // only ever drawn inside the centre island, whose ground
                    // goes solid black in notch mode.
                    color: cell.isActive ? Theme.barText
                         : cell.isOccupied ? Theme.barTextDim  // occupied reads
                         : Theme.barTextFaint                  // brighter than empty

                    // The extra bit of visual weight on the active numeral.
                    scale: cell.isActive ? 1.0 : 0.98
                    opacity: cell.isActive ? 1.0
                           : cell.isOccupied ? 0.85
                           : (cellArea.containsMouse ? 0.8 : 0.45)

                    Behavior on font.pixelSize {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    }
                    Behavior on color { ColorAnimation { duration: 220; easing.type: Theme.easeStandard } }
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Theme.easeStandard } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Theme.easeStandard } }
                }

                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hypr.activate(cell.wsId)
                }
            }
        }
    }

    // Scroll anywhere over the carousel steps one workspace.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta === 0)
                return
            // Trackpads emit a stream of small deltas; throttle to one step.
            if (wheelGate.running)
                return
            wheelGate.restart()
            Hypr.step(delta > 0 ? -1 : 1)
        }
    }

    Timer { id: wheelGate; interval: 140 }
}
