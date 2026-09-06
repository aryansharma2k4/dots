import QtQuick
import ".."

// One row in any of the detail lists (networks, paired devices, output sinks,
// open windows). Hover fills softly; the optional trailing action only appears
// while the row is hovered.
Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property int iconSize: Theme.fontSizeXl
    property string label: ""
    property string sublabel: ""
    property string trailing: ""          // e.g. a signal percentage
    property bool selected: false
    property bool busy: false
    property bool showClose: false
    // When set, the row shows the application's themed icon instead of `icon`.
    property string iconClass: ""

    signal clicked()
    signal closeRequested()

    implicitHeight: sublabel !== "" ? 42 : 34
    implicitWidth: 240

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.fillHover
             : root.selected ? Theme.fillWeak
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
    }

    Item {
        id: iconSlot
        width: root.iconSize + 6
        height: width
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        AppIcon {
            anchors.centerIn: parent
            visible: root.iconClass !== ""
            appClass: root.iconClass
            size: root.iconSize + 3
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconClass === ""
            text: root.icon
            font.family: Theme.fontIcons
            font.pixelSize: root.iconSize
            color: root.iconColor
        }
    }

    Column {
        anchors.left: iconSlot.right
        anchors.leftMargin: 9
        anchors.right: tail.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeMd
            font.weight: root.selected ? Font.DemiBold : Font.Normal
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.sublabel !== ""
            text: root.sublabel
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textDim
            elide: Text.ElideRight
        }
    }

    Item {
        id: tail
        width: 26
        height: parent.height
        anchors.right: parent.right
        anchors.rightMargin: 6

        Text {
            anchors.centerIn: parent
            visible: root.trailing !== "" && !root.showClose && !root.busy
            text: root.trailing
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textFaint
        }

        // Spinner while a connect/disconnect is in flight.
        Text {
            anchors.centerIn: parent
            visible: root.busy
            text: "󰀚"
            font.family: Theme.fontIcons
            font.pixelSize: Theme.fontSizeMd
            color: Theme.textDim
            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: 360; duration: 1100
            }
        }

        // Close affordance, revealed on row hover only.
        Rectangle {
            id: closeButton
            anchors.centerIn: parent
            width: 18
            height: 18
            radius: 9
            visible: root.showClose
            opacity: area.containsMouse || closeArea.containsMouse ? 1 : 0
            scale: closeArea.pressed ? 0.85 : (closeArea.containsMouse ? 1.12 : 1.0)
            color: closeArea.containsMouse ? Theme.danger : Theme.fillStrong

            Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
            Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
            Behavior on color { ColorAnimation { duration: Theme.durHover } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: Theme.fontIcons
                font.pixelSize: Theme.fontSize(0.56)
                color: Theme.text
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.closeRequested()
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        // Sit below the close button so it keeps its own clicks.
        z: -1
        onClicked: root.clicked()
    }
}
