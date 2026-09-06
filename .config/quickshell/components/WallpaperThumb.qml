import QtQuick
import Quickshell.Widgets
import ".."
import "../services"

/*
 * One wallpaper in the filmstrip.
 *
 * A rounded square rather than a circle, deliberately: the power pill sitting
 * immediately to its left is a row of circles, and these two pills are adjacent
 * and the same height, so they need to be told apart at a glance. Rounded
 * squares also follow the precedent already set for imagery in this shell — the
 * media pill's album art is a Theme.radiusArt square, not a disc.
 *
 * The rim is the wallpaper's own dominant colour, pulled from the same
 * quantiser the media card uses. The current wallpaper wears it permanently;
 * the others light up on hover, which doubles as a preview of what that image
 * would do to the bar's accent if it were applied.
 */
Item {
    id: root

    property string name: ""
    property string url: ""
    property bool current: false
    property int size: Theme.barHeight - Theme.innerPadding * 2

    property bool revealed: false
    property int revealDelay: 0

    signal chosen()
    signal previewRequested(bool active)

    implicitWidth: size
    implicitHeight: size

    opacity: revealed ? 1 : 0
    scale: revealed ? 1 : 0.72

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.revealed ? root.revealDelay : 0 }
            NumberAnimation {
                duration: root.revealed ? Theme.durOpen : Theme.durClose
                easing.type: root.revealed ? Theme.easeStandard : Theme.easeClose
            }
        }
    }

    Behavior on scale {
        SequentialAnimation {
            PauseAnimation { duration: root.revealed ? root.revealDelay : 0 }
            NumberAnimation {
                duration: root.revealed ? Theme.durOpen : Theme.durClose
                easing.type: root.revealed ? Theme.easeOpen : Theme.easeClose
                easing.overshoot: Theme.easeOpenOvershoot
            }
        }
    }

    readonly property bool interactive: revealed && opacity > 0.9
    readonly property color accent: Wallpaper.accentOf(root.name)

    // ClippingRectangle, not Rectangle: `clip: true` clips to the bounding
    // box only, so a plain rounded Rectangle would leave the image's corners
    // poking out past the radius.
    ClippingRectangle {
        id: surface
        anchors.fill: parent
        radius: Theme.radiusArt
        color: Theme.fillMid
        clip: true
        antialiasing: true

        scale: area.pressed ? 0.92 : (area.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }

        Image {
            anchors.fill: parent
            source: root.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            // Decode at the size actually drawn, not at a round number. These
            // are 2-4MB 1920x1080 PNGs and the tile is `size` px across, so a
            // 160px decode was twenty-five times the pixels needed — paid nine
            // times over, once per wallpaper in the library.
            //
            // Doubled for the hover scale-up and for any fractional scaling.
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            smooth: true
        }

        // Unselected tiles are held back slightly so the current one reads as
        // current without needing a tick or a label.
        Rectangle {
            anchors.fill: parent
            // `surface`, not `parent`: ClippingRectangle puts its children in an
            // inner content item, which has no radius of its own.
            radius: surface.radius
            color: Theme.alpha("#000000", root.current || area.containsMouse ? 0 : 0.28)
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }
    }

    // Rim outside the image so it is never clipped by it.
    Rectangle {
        anchors.fill: surface
        anchors.margins: -1
        radius: surface.radius + 1
        color: "transparent"
        border.width: root.current ? 2 : (area.containsMouse ? 2 : 1)
        border.color: root.current || area.containsMouse ? root.accent : Theme.rim
        antialiasing: true
        scale: surface.scale

        Behavior on border.color { ColorAnimation { duration: Theme.durColor } }
        Behavior on border.width { NumberAnimation { duration: Theme.durHover } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        onClicked: root.chosen()
        onContainsMouseChanged: {
            root.previewRequested(containsMouse)
            if (containsMouse)
                Wallpaper.resolveAccent(root.name)
        }
    }
}
