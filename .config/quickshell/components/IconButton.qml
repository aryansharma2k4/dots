import QtQuick
import ".."

// Circular icon button. Background and scale animate on hover and press; they
// never snap.
Item {
    id: root

    property string icon: ""
    property int iconSize: Theme.fontSize(0.95)
    property color iconColor: Theme.text
    property color hoverColor: Theme.fillHover
    property bool enabled: true
    property bool highlighted: false
    property int diameter: 28
    // Invisible ring of extra hit area around the circle. The button keeps its
    // `diameter` for everything you can see; only the target grows, so a near
    // miss still lands on the right control instead of on its neighbour.
    property int hitPadding: 0

    readonly property bool hovered: area.containsMouse

    signal clicked()

    implicitWidth: diameter + hitPadding * 2
    implicitHeight: diameter + hitPadding * 2
    opacity: enabled ? 1 : 0.35

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: root.diameter
        height: root.diameter
        radius: width / 2
        color: root.highlighted ? root.hoverColor
             : area.containsMouse ? root.hoverColor
             : "transparent"
        scale: area.pressed ? 0.9 : (area.containsMouse ? 1.06 : 1.0)

        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.family: Theme.fontIcons
            font.pixelSize: root.iconSize
            color: root.iconColor
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
