import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

// PipeWire output picker, shared by the media card and the control centre's
// sound row. Click-opened, so `pinned` drives it.
HoverPopup {
    id: root

    triggerHovered: false

    readonly property var sinks: Audio.sinks
    contentWidth: 260
    contentHeight: Math.min(300, 46 + Math.max(1, sinks.length) * 38)
    anchorRight: true

    function openAt(x) {
        root.anchorX = x + 20
        root.pinned = true
    }

    Behavior on contentHeight {
        NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard }
    }

    Text {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: 14
        text: "Output"
        font.family: Theme.fontUI
        font.pixelSize: Theme.fontSizeSm
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        color: Theme.textFaint
    }

    Column {
        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        spacing: 1

        Text {
            visible: root.sinks.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            text: "No audio outputs"
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeMd
            color: Theme.textFaint
        }

        Repeater {
            model: root.sinks

            ListRow {
                required property var modelData
                width: parent.width
                height: 36

                icon: Audio.iconFor(modelData)
                iconColor: modelData.id === Audio.sink?.id ? Theme.accent : Theme.textDim
                label: modelData.description || modelData.name || "Output"
                selected: modelData.id === Audio.sink?.id
                trailing: modelData.id === Audio.sink?.id ? "✓" : ""

                onClicked: {
                    Audio.setSink(modelData)
                    root.dismiss()
                }
            }
        }
    }
}
