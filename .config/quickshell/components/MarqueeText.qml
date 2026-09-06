import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

/*
 * Text that scrolls only when it overflows, with a soft right-edge fade.
 *
 * The fade is an alpha mask over the text itself, not a solid strip drawn on
 * top of it. A strip would be an opaque plate on glass, and an opaque plate is
 * the one thing that reliably breaks the frosted illusion — so the pixels
 * themselves are made transparent instead.
 *
 * The mask is a horizontal gradient in a hidden, layer-backed Item, fed to
 * OpacityMask as maskSource; the effect multiplies the layer's alpha by the
 * mask's alpha.
 *
 * NOTE: this deliberately uses Qt5Compat's OpacityMask rather than
 * QtQuick.Effects' MultiEffect. MultiEffect's maskEnabled/maskSource pair
 * silently renders the layer *unmasked* here (verified on Qt 6 / Quickshell
 * 0.3.0) — no error, no fade, just an ignored mask. OpacityMask works.
 */
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property int pixelSize: Theme.fontSizeMd
    property int weight: Font.Normal
    property string family: Theme.fontUI
    // Set to Text.RichText to colour parts of the string differently (the media
    // pill dims the artist half of "Title - Artist" this way).
    property int textFormat: Text.PlainText
    // Width of the edge fades, as a fraction of the item width. The left fade
    // defaults to 0 — most labels only need to dissolve on the trailing edge —
    // but the focused-window title sets both so a scrolling string dissolves at
    // either boundary instead of being hard-clipped.
    property real fadeWidth: 0.22
    property real fadeWidthLeft: 0
    property bool scroll: true
    property int startPause: 1400   // hold before each cycle begins moving

    // Identifies *what* the text describes, so the cycle restarts when the
    // subject changes rather than whenever the string does. The focused-window
    // title is edited constantly by its own app — a progress percentage, a tab
    // count, or Claude Code's spinner glyph cycling several times a second —
    // and restarting on each of those pinned the marquee inside its opening
    // pause forever, so it never moved at all. Keying the reset to the window
    // address instead means a live-updating title keeps scrolling smoothly and
    // only an actual window switch starts the cycle over.
    property var resetKey: undefined
    // Centre the text when it fits. Used by the focused-window title, which
    // truncates rather than scrolling.
    property bool centered: false
    property int gap: 40
    // px per second, not a duration: a long title and a short one travel at the
    // same rate.
    property int speed: Theme.marqueeSpeed

    readonly property bool overflowing: label.implicitWidth > width

    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    Item {
        id: track
        anchors.fill: parent
        clip: true

        // Centring and scrolling are deliberately two different items.
        // The scroll animation drives strip.x and ends with a PropertyAction,
        // which permanently breaks any binding on that property — so if
        // centring lived on strip.x too, a short title arriving after a long
        // one had scrolled would stay pinned at 0 instead of re-centring.
        // `shifter` is never touched by the animation, so its binding survives.
        Item {
            id: shifter
            width: track.width
            height: track.height
            x: root.centered && !root.overflowing
                ? Math.max(0, (track.width - label.implicitWidth) / 2)
                : 0

            Row {
                id: strip
                spacing: root.gap
                y: (track.height - label.implicitHeight) / 2
                x: 0

                Text {
                    id: label
                    text: root.text
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.pixelSize
                    font.weight: root.weight
                    textFormat: root.textFormat
                }

                // The second copy exists only while scrolling, so a static label
                // costs one text node rather than two.
                Text {
                    visible: root.scroll && root.overflowing
                    text: root.text
                    color: root.color
                    font.family: root.family
                    font.pixelSize: root.pixelSize
                    font.weight: root.weight
                    textFormat: root.textFormat
                }
            }
        }

        // Wrap-around scroll: travel exactly one copy plus the gap, then snap
        // back to 0 — with two identical copies the snap is invisible.
        SequentialAnimation {
            id: marquee
            running: root.scroll && root.overflowing && root.visible
            loops: Animation.Infinite
            PauseAnimation { duration: root.startPause }
            NumberAnimation {
                target: strip
                property: "x"
                from: 0
                to: -(label.implicitWidth + root.gap)
                // Constant-speed travel. This is the one place a linear curve
                // is correct: an eased marquee reads as a stutter.
                duration: Math.max(1, (label.implicitWidth + root.gap) / root.speed * 1000)
                easing.type: Easing.Linear
            }
            PropertyAction { target: strip; property: "x"; value: 0 }
        }

        // A new window must start a fresh cycle, pause included — otherwise it
        // inherits the previous title's scroll position and appears mid-travel.
        Connections {
            target: root
            function onResetKeyChanged() {
                strip.x = 0
                if (root.scroll && root.overflowing)
                    marquee.restart()
                else
                    marquee.stop()
                // restart()/stop() assign `running` directly, which would drop
                // its binding and leave the marquee stuck in whatever state the
                // *previous* title put it in. Re-establish it so the next title
                // is still judged on its own overflow.
                marquee.running = Qt.binding(function() {
                    return root.scroll && root.overflowing && root.visible
                })
            }
        }
    }

    // --------------------------------------------------------- fade mask ----
    Item {
        id: maskShape
        width: Math.max(1, root.width)
        height: Math.max(1, root.height)
        // Never painted itself; it exists only as a texture for the mask, which
        // is why it needs its own layer.
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.fadeWidthLeft > 0 ? "#00FFFFFF" : "#FFFFFFFF" }
                GradientStop { position: Math.max(0.0, Math.min(0.49, root.fadeWidthLeft)); color: "#FFFFFFFF" }
                GradientStop { position: Math.max(0.51, 1.0 - root.fadeWidth); color: "#FFFFFFFF" }
                GradientStop { position: 1.0; color: root.fadeWidth > 0 ? "#00FFFFFF" : "#FFFFFFFF" }
            }
        }
    }

    // Masking costs an FBO, so skip it entirely when the text fits and there is
    // nothing to fade.
    layer.enabled: (root.fadeWidth > 0 || root.fadeWidthLeft > 0) && root.overflowing
    layer.effect: OpacityMask {
        maskSource: maskShape
    }
}
