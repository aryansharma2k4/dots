import QtQuick
import ".."
import "../services"

/*
 * The notification being read, inside the expanded card.
 *
 * No background, no border: the island's own glass is already behind it. The
 * rows below the header exist only when the notification carries them, and the
 * height is published rather than imposed, so the island grows by exactly what
 * this one needs — a bare notification does not pay for buttons it never had.
 */
Item {
    id: root

    property var notif: null
    property bool expanded: true

    readonly property var actions: notif && notif.actions ? notif.actions : []
    readonly property bool hasActions: expanded && actions.length > 0
    readonly property bool hasReply: expanded && notif ? notif.hasInlineReply === true : false
    readonly property bool critical: notif
        ? notif.urgency === 2      // NotificationUrgency.Critical
        : false

    implicitHeight: header.height
        + bodyBlock.height + (bodyBlock.height > 0 ? 4 : 0)
        + (hasActions ? Theme.notifActions : 0)
        + (hasReply ? Theme.notifReply : 0)

    signal dismissed()
    signal replySubmitted(string text)

    function clearReply() { replyField.text = "" }

    // ---- header: icon, app, summary --------------------------------------------
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        // Sized so the collapsed pill comes out at exactly Theme.barHeight,
        // which is what lets it sit in the same row as the other islands
        // instead of near it.
        //
        // Deliberately NOT animated. This feeds root.implicitHeight, which is
        // what the island's own height animation aims at — and an animation
        // aimed at a moving target restarts its easing on every frame instead
        // of running its curve once. One animator owns this transition, and it
        // is the island's height; everything inside it steps.
        height: (root.expanded ? Theme.notifIconCard : Theme.notifIcon) + 4

        // Critical gets a bar down its edge rather than a red wash — tinting
        // the surface would drag the rest of the card with it.
        Rectangle {
            id: flag
            visible: root.critical
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: visible ? 3 : 0
            height: iconPlate.height
            radius: 1.5
            color: Theme.notifCritical
        }

        NotificationIcon {
            id: iconPlate
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: flag.right
            anchors.leftMargin: root.critical ? 9 : 0
            size: root.expanded ? Theme.notifIconCard : Theme.notifIcon
            image: root.notif ? root.notif.image : ""
            appIcon: root.notif ? root.notif.appIcon : ""
            appName: root.notif ? root.notif.appName : ""
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: iconPlate.right
            anchors.leftMargin: 10
            anchors.right: badge.left
            anchors.rightMargin: 8
            spacing: 1

            Text {
                width: parent.width
                text: root.notif ? (root.notif.appName || "Notification") : ""
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6
                color: root.critical ? Theme.notifCritical : Theme.textFaint
                elide: Text.ElideRight
                // At pill size the app name is the least useful line — the
                // summary is what says whether this is worth reaching for.
                visible: root.expanded
            }

            Text {
                width: parent.width
                text: root.notif ? (root.notif.summary !== "" ? root.notif.summary
                                                              : root.notif.appName) : ""
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeBar
                font.weight: Font.DemiBold
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        // Count of everything waiting, including this one. Doubles as the
        // affordance that there is more here than the pill is showing.
        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: closeButton.left
            anchors.rightMargin: root.expanded ? 6 : 0
            width: visible ? Math.max(20, count.implicitWidth + 12) : 0
            height: 20
            radius: 10
            visible: Notif.pending > 1
            color: root.critical ? Theme.alpha(Theme.notifCritical, 0.22) : Theme.fillMid

            Text {
                id: count
                anchors.centerIn: parent
                text: Notif.pending
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: root.critical ? Theme.notifCritical : Theme.textDim
            }
        }

        IconButton {
            id: closeButton
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            icon: "󰅖"
            iconSize: Theme.fontSize(0.68)
            diameter: 22
            hitPadding: 4
            iconColor: Theme.textDim
            // Nothing to press at pill size; it would only be a target to miss.
            visible: root.expanded
            width: visible ? implicitWidth : 0
            onClicked: root.dismissed()
        }
    }

    // ---- body ------------------------------------------------------------------
    Item {
        id: bodyBlock
        anchors { top: header.bottom; topMargin: 4
                  left: parent.left; leftMargin: Theme.notifIconCard + 10
                  right: parent.right }
        height: root.expanded && bodyText.text !== "" ? bodyText.implicitHeight : 0
        clip: true

        Text {
            id: bodyText
            // Top-anchored, never filled: its height must stay its own natural
            // height, or it is back to chasing the wrapper.
            anchors { top: parent.top; left: parent.left; right: parent.right }
            text: root.notif ? root.notif.body : ""
            // We advertise bodyMarkupSupported, so the spec's small HTML subset
            // has to be rendered rather than shown with its tags in it.
            textFormat: Text.StyledText
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeMd
            color: Theme.textDim
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard }
            }
        }
    }

    // ---- actions ---------------------------------------------------------------
    Row {
        id: actionRow
        anchors { top: bodyBlock.bottom; left: bodyBlock.left; right: parent.right }
        height: root.hasActions ? Theme.notifActions : 0
        visible: root.hasActions
        spacing: 6

        Repeater {
            model: root.hasActions ? root.actions : []

            Rectangle {
                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                height: 30
                width: Math.max(70, label.implicitWidth + 24)
                radius: height / 2
                color: area.pressed ? Theme.fillStrong
                     : area.containsMouse ? Theme.fillMid : Theme.fillWeak

                Behavior on color { ColorAnimation { duration: Theme.durHover } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: parent.modelData.text
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Notif.invoke(root.notif, parent.modelData)
                }
            }
        }
    }

    // ---- inline reply ----------------------------------------------------------
    // Only when the app declared one. Typing needs the island's surface to take
    // keyboard focus, which it otherwise never does — see the keyboardFocus
    // binding in NotificationIsland.
    Rectangle {
        id: replyBox
        anchors { top: actionRow.bottom; left: bodyBlock.left; right: parent.right }
        height: root.hasReply ? Theme.notifReply - 8 : 0
        visible: root.hasReply
        radius: height / 2
        color: replyField.activeFocus ? Theme.fillMid : Theme.fillWeak
        border.width: 1
        border.color: replyField.activeFocus ? Theme.alpha(Theme.accent, 0.6) : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.durHover } }

        TextInput {
            id: replyField
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 32
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSizeMd
            color: Theme.text
            selectionColor: Theme.alpha(Theme.accent, 0.45)
            selectedTextColor: Theme.text
            clip: true

            onAccepted: root.replySubmitted(text)
            Keys.onEscapePressed: focus = false

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: replyField.text === "" && !replyField.activeFocus
                text: root.notif && root.notif.inlineReplyPlaceholder !== ""
                    ? root.notif.inlineReplyPlaceholder : "Reply…"
                font: replyField.font
                color: Theme.textFaint
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 4
            icon: "󰒊"
            iconSize: Theme.fontSize(0.78)
            diameter: 24
            enabled: replyField.text.trim() !== ""
            iconColor: enabled ? Theme.accent : Theme.textFaint
            onClicked: root.replySubmitted(replyField.text)
        }
    }

    // Clicking the notification runs the app's default action — what opens the
    // chat the message came from. Behind everything, so the buttons see theirs
    // first. Excludes the reply row, where a click means "put the caret here".
    MouseArea {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: header.height + bodyBlock.height
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.dismissed()
                return
            }
            for (let i = 0; i < root.actions.length; i++) {
                if (root.actions[i].identifier === "default") {
                    Notif.invoke(root.notif, root.actions[i])
                    return
                }
            }
            if (!root.hasReply)
                root.dismissed()
        }
    }
}
