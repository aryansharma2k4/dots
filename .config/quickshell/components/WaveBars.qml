import QtQuick
import ".."
import "../services"

// Animated level meter. Bar heights come from Media.levels, which uses real
// audio levels when PipeWire exposes them and a phase-offset sine idle
// animation when it does not. Heights are animated rather than assigned so the
// 14Hz level tick reads as continuous motion at full framerate.
Row {
    id: root

    property int bars: 4
    property int barWidth: 2
    property int barSpacing: 2
    property int maxHeight: 16
    property color color: Theme.text
    property bool active: Media.playing

    spacing: barSpacing
    height: maxHeight

    Repeater {
        model: root.bars

        Rectangle {
            required property int index

            width: root.barWidth
            radius: root.barWidth / 2
            color: root.color
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.active ? 1.0 : 0.5

            // Floor at 22% so a quiet passage still reads as a meter rather
            // than a row of dots.
            height: Math.max(root.barWidth,
                             root.maxHeight * Math.max(0.22, Media.levels[index % Media.levels.length] ?? 0.3))

            Behavior on height {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
            Behavior on color { ColorAnimation { duration: Theme.durColor } }
        }
    }
}
