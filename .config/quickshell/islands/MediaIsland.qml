import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../popups"
import "../services"

// LEFT ISLAND — the media pill, and the card it grows into on hover.
Scope {
    id: root

    // Space around the island inside its window, so the drop shadow has
    // somewhere to fall instead of being clipped at the surface edge.
    readonly property int pad: 20
    readonly property int pillWidth: 300
    readonly property int pillHeight: Theme.barHeight

    signal sinkPickerRequested(int x)

    PanelWindow {
        id: window

        anchors { top: true; left: true }
        // Pinned; the island moves inside it. Only the vertical offset changes
        // with the mode — the pill keeps its distance from the left edge either
        // way, so it has room for a flare on both of its top corners.
        margins.top: -root.pad
        margins.left: Theme.screenMargin - root.pad
        implicitWidth: root.pillWidth + root.pad * 2
        implicitHeight: root.pillHeight + root.pad * 2 + Theme.screenMargin
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        // Keyed to the layerrule blur entry in the Hyprland config.
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region { item: pill }

        GlassSurface {
            id: pill
            x: root.pad
            width: root.pillWidth
            height: root.pillHeight
            radius: Theme.radiusIsland
            followsNotch: true

            // Flush with the screen edge in notch mode, floating below it in
            // island mode. The window itself never moves — see BarIsland.
            y: root.pad + Theme.barTopMargin

            Behavior on y {
                NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard }
            }

            HoverHandler {
                id: pillHover
                onHoveredChanged: card.triggerHovered = hovered
            }

            // The meter runs whenever something is playing. Hovering only
            // raises its refresh rate — see Media.meterWanted.
            Binding {
                target: Media
                property: "meterWanted"
                value: pillHover.hovered || card.active
            }

            // ---- album art -------------------------------------------------
            Rectangle {
                id: thumb
                // Inner padding scales with barHeight, so the art keeps the
                // same optical inset as the pill grows.
                width: parent.height - Theme.innerPadding * 2
                height: width
                radius: Theme.radiusArt
                anchors.left: parent.left
                anchors.leftMargin: Theme.innerPadding
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fillMid
                clip: true

                Image {
                    id: thumbImage
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
            // Decoded at twice the size it is drawn, not at the source's own
            // resolution: an uncapped Image keeps a full pixmap of whatever the
            // player handed over — cover art is routinely 1000px square — to
            // fill a box a few dozen pixels wide.
            sourceSize.width: thumb.width * 2
                    sourceSize.height: thumb.height * 2
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !thumbImage.visible
                    text: "󰝚"
                    font.family: Theme.fontIcons
                    font.pixelSize: Theme.fontSizeBar
                    color: Theme.barTextFaint
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.alpha(Theme.rim, Theme.rim.a * 1.2)
                }
            }

            // ---- "Title - Artist" ------------------------------------------
            // One string, two colours: rich text lets the artist half sit
            // dimmer without a second scrolling label that could drift out of
            // sync with the first.
            MarqueeText {
                anchors.left: thumb.right
                anchors.leftMargin: Theme.innerPadding + 2
                anchors.right: bars.left
                anchors.rightMargin: Theme.innerPadding
                anchors.verticalCenter: parent.verticalCenter
                height: Theme.fontSizeBar + 5

                textFormat: Text.RichText
                text: Media.available
                    ? "<span style='color:" + Theme.barText + "'>" + esc(Media.title) + "</span>"
                      + (Media.artist !== ""
                         ? "<span style='color:" + Theme.barTextDim + "'> - " + esc(Media.artist) + "</span>"
                         : "")
                    : "<span style='color:" + Theme.barTextFaint + "'>Nothing playing</span>"
                pixelSize: Theme.fontSizeBar
                weight: Font.DemiBold
                fadeWidth: 0.28     // the artist tail dissolves at the right edge

                function esc(s) {
                    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
                }
            }

            // ---- level meter -----------------------------------------------
            WaveBars {
                id: bars
                anchors.right: parent.right
                anchors.rightMargin: Theme.innerPadding + 3
                anchors.verticalCenter: parent.verticalCenter
                bars: 4
                barWidth: 3
                barSpacing: 3
                maxHeight: Math.round(Theme.barHeight * 0.38)
                color: Media.colorsResolved ? Media.primary : Theme.barText
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) Media.next()
                    else Media.play()
                }
            }
        }
    }

    // ---- the card ------------------------------------------------------------
    HoverPopup {
        id: card

        contentWidth: 330
        contentHeight: 152
        // Centred under the pill itself, so it tracks the island rather than
        // assuming a fixed offset from the screen edge.
        anchorItem: pill
        anchorAlign: "center"

        MediaCard {
            anchors.fill: parent
            radius: Theme.radiusPopup
            showGlow: card.active
            onSinkPickerRequested: x => root.sinkPickerRequested(x)
        }
    }
}
