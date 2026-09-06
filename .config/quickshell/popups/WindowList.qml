import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

/*
 * Every open window, grouped by application, right-aligned under the app
 * circle. Left-click focuses; the × that appears on row hover closes.
 *
 * Rows are built from Hypr.windowGroups, which is rebuilt only when Hyprland
 * reports a window/workspace change — so hovering this list does not re-query
 * anything, and the delegates are not re-instantiated while the popup is open.
 */
HoverPopup {
    id: root

    readonly property var groups: Hypr.windowGroups
    readonly property int rowHeight: 34
    readonly property int headerHeight: 20

    // Height is content-driven: sum of rows, plus a header per multi-window
    // group, clamped so a very busy session still fits on screen.
    readonly property int measuredHeight: {
        let h = 16
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i]
            if (g.windows.length > 1)
                h += headerHeight
            h += g.windows.length * rowHeight
            h += 4
        }
        return Math.min(520, Math.max(56, h))
    }

    contentWidth: 280
    contentHeight: measuredHeight

    Behavior on contentHeight {
        NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: column
            width: parent.width
            spacing: 4

            Text {
                visible: root.groups.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 12
                text: "No open windows"
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textFaint
            }

            Repeater {
                model: root.groups

                Column {
                    required property var modelData
                    width: column.width
                    spacing: 1

                    // Group header only when an app actually has several
                    // windows — a header over a single row is just noise.
                    Item {
                        width: parent.width
                        height: root.headerHeight
                        visible: modelData.windows.length > 1

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.appClass
                            font.family: Theme.fontUI
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            color: Theme.textFaint
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.windows.length
                            font.family: Theme.fontUI
                            font.features: Theme.tabularFigures
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textFaint
                        }
                    }

                    Repeater {
                        model: modelData.windows

                        ListRow {
                            required property var modelData
                            width: column.width
                            height: root.rowHeight

                            label: modelData.title
                            sublabel: ""
                            selected: modelData.activated
                            showClose: true
                            trailing: ""

                            // The class comes from the group, not the window
                            // title — titles lie, classes do not.
                            iconClass: modelData.appClass

                            onClicked: Hypr.focusWindow(modelData.address)
                            onCloseRequested: Hypr.closeWindow(modelData.address)
                        }
                    }
                }
            }
        }
    }
}
