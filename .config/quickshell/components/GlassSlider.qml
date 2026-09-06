import QtQuick
import ".."

// macOS-style capsule slider: the whole track is the handle. Drag anywhere on
// it, including a straight click-to-position. Emits continuously while dragging
// so brightness and volume follow the cursor live.
Item {
    id: root

    property real value: 0.5           // 0..1
    property string iconLeft: ""
    property string iconRight: ""
    property color fillColor: Theme.light ? "#3A3A3E" : "#FFFFFF"
    property bool enabled: true

    signal moved(real value)
    signal released()

    implicitHeight: 26
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.fillMid
        clip: true

        Rectangle {
            id: filled
            height: parent.height
            width: Math.round(parent.width * Math.min(1, Math.max(0, root.value)))
            radius: parent.radius
            color: root.fillColor

            // Snappy but not instant: a click-to-position should travel, a drag
            // should not lag behind the cursor.
            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconLeft
            font.family: Theme.fontIcons
            font.pixelSize: Theme.fontSizeMd
            // The icons sit on both sides of the fill edge, so they invert as
            // the fill sweeps past them.
            color: filled.width > 22 ? Theme.light ? "#FFFFFF" : "#101014" : Theme.textDim
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconRight
            font.family: Theme.fontIcons
            font.pixelSize: Theme.fontSizeLg
            color: filled.width > parent.width - 22 ? Theme.light ? "#FFFFFF" : "#101014" : Theme.textDim
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.rim, Theme.rim.a * 0.7)
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: root.enabled
        preventStealing: true

        function apply(x) {
            root.value = Math.min(1, Math.max(0, x / Math.max(1, root.width)))
            root.moved(root.value)
        }

        onPressed: mouse => apply(mouse.x)
        onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
        onReleased: root.released()
    }

    scale: drag.pressed ? 1.015 : 1.0
    Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
}
