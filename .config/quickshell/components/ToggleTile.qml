import QtQuick
import ".."

/*
 * The control-center tile, in all three of its shapes.
 *
 * The styling rule, implemented once here so it cannot drift between tiles:
 *   OFF -> dark glass fill, coloured icon (the icon carries the identity)
 *   ON  -> inverted: light fill, dark icon
 * Both the fill and the icon colour animate; neither ever snaps.
 *
 * Split behaviour: when `splittable` is true the tile is two hit targets. The
 * left portion toggles; the right portion opens the detail list. The divider is
 * invisible — it is only a hover affordance, matching macOS.
 */
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool enabled: true
    property color accent: Theme.accent
    property bool splittable: false
    property real splitPoint: 0.62      // fraction of width that toggles
    property bool compact: false        // small square tile: icon only

    signal toggled()
    signal detailRequested()

    implicitWidth: compact ? 70 : 140
    implicitHeight: 70

    opacity: enabled ? 1.0 : 0.38

    readonly property color fillColor: {
        if (!enabled) return Theme.toggleOff
        if (active) return Theme.toggleOn
        return (toggleArea.containsMouse || detailArea.containsMouse) ? Theme.fillHover : Theme.toggleOff
    }
    readonly property color iconColor: active ? Theme.toggleOnIcon : accent
    readonly property color textColor: active ? Theme.toggleOnIcon : Theme.text
    readonly property color subColor: active
        ? Theme.alpha(Theme.toggleOnIcon, 0.6)
        : Theme.textDim

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Theme.radiusTile
        color: root.fillColor
        antialiasing: true
        scale: (toggleArea.pressed || detailArea.pressed) ? 0.965 : 1.0

        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }

        // Faint rim so an off tile still reads as a surface on dark glass.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.active ? "transparent" : Theme.alpha(Theme.rim, Theme.rim.a * 0.7)
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: Theme.durHover } }
        }

        // ------------------------------------------------------------ icon --
        // The icon lives in its own circular well when the tile is wide, and
        // fills the tile when compact.
        Item {
            id: iconWell
            width: 34
            height: 34
            anchors.left: root.compact ? undefined : parent.left
            anchors.leftMargin: 12
            anchors.horizontalCenter: root.compact ? parent.horizontalCenter : undefined
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: !root.compact
                color: root.active
                    ? Theme.alpha(root.accent, 0.16)
                    : Theme.alpha(root.accent, 0.20)
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                font.family: Theme.fontIcons
                font.pixelSize: root.compact ? 22 : 19
                color: root.active
                    ? (root.compact ? Theme.toggleOnIcon : root.accent)
                    : root.accent
                Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
            }
        }

        // ------------------------------------------------------------ text --
        Column {
            visible: !root.compact
            anchors.left: iconWell.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
                color: root.textColor
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }

            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                font.family: Theme.fontUI
                font.pixelSize: Theme.fontSizeSm
                color: root.subColor
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
            }
        }

        // Hover affordance for the detail half: a soft wash, not a hard line.
        Rectangle {
            visible: root.splittable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * (1 - root.splitPoint)
            radius: parent.radius
            opacity: detailArea.containsMouse ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: root.active ? Theme.alpha("#000000", 0.10) : Theme.alpha("#FFFFFF", 0.08) }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
        }

        // A chevron marks the half that opens a list.
        Text {
            visible: root.splittable
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: "›"
            font.family: Theme.fontUI
            font.pixelSize: Theme.fontSize(0.95)
            color: root.active ? Theme.alpha(Theme.toggleOnIcon, 0.55) : Theme.textFaint
            opacity: detailArea.containsMouse ? 1.0 : 0.45
            Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
        }
    }

    MouseArea {
        id: toggleArea
        enabled: root.enabled
        hoverEnabled: true
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.splittable ? parent.width * root.splitPoint : parent.width
        onClicked: root.toggled()
    }

    MouseArea {
        id: detailArea
        enabled: root.enabled && root.splittable
        visible: root.splittable
        hoverEnabled: true
        anchors.left: toggleArea.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onClicked: root.detailRequested()
    }
}
