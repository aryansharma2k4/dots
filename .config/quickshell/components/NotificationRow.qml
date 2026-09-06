import QtQuick
import ".."
import "../services"

/*
 * One waiting notification, listed inside the expanded card under the one being
 * read. A row, not a card: it is already inside the island's glass, so it draws
 * no surface of its own and only lifts a fill on hover.
 */
Item {
    id: root

    property var notif: null

    signal activated()
    signal dismissed()

    implicitHeight: Theme.notifQueueRow

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.fillWeak : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durHover } }
    }

    NotificationIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        size: 24
        image: root.notif ? root.notif.image : ""
        appIcon: root.notif ? root.notif.appIcon : ""
        appName: root.notif ? root.notif.appName : ""
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: close.left
        anchors.rightMargin: 8
        spacing: 0

        Text {
            width: parent.width
            text: root.notif ? (root.notif.summary !== "" ? root.notif.summary
                                                          : root.notif.appName) : ""
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeMd
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.notif ? (root.notif.body !== "" ? root.notif.body
                                                       : root.notif.appName) : ""
            textFormat: Text.StyledText
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textFaint
            elide: Text.ElideRight
            visible: text !== ""
        }
    }

    IconButton {
        id: close
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        icon: "󰅖"
        iconSize: Theme.fontSize(0.62)
        diameter: 20
        hitPadding: 4
        iconColor: Theme.textFaint
        onClicked: root.dismissed()
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        z: -1
        onClicked: root.activated()
    }
}
