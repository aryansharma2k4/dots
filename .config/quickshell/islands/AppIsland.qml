import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../popups"
import "../services"

// RIGHT ISLAND — a circle showing the focused application's icon, expanding on
// hover into the full window list.
Scope {
    id: root

    readonly property int pad: 20
    readonly property int diameter: Theme.circleSize

    PanelWindow {
        id: window

        anchors { top: true; right: true }
        // Pinned; the island moves inside it. See MediaIsland.
        margins.top: -root.pad
        margins.right: Theme.screenMargin - root.pad
        implicitWidth: root.diameter + root.pad * 2
        implicitHeight: root.diameter + root.pad * 2 + Theme.screenMargin
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        mask: Region { item: circle }

        GlassSurface {
            id: circle
            x: root.pad
            width: root.diameter
            height: root.diameter
            // A circle is just the island radius taken to its limit, so it
            // inherits the same rim, sheen and shadow as the other two — and,
            // in notch mode, the same square shoulders: `radius` is what
            // followsNotch falls back to when the mode is off, so this stays a
            // true circle as an island and becomes a tab as a notch.
            radius: width / 2
            followsNotch: true

            // Flush with the screen edge in notch mode, floating below it in
            // island mode. The window itself never moves — see BarIsland.
            y: root.pad + Theme.barTopMargin

            Behavior on y {
                NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard }
            }

            scale: circleArea.pressed ? 0.94 : (list.shouldShow ? 1.05 : 1.0)
            Behavior on scale {
                NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard }
            }

            AppIcon {
                anchors.centerIn: parent
                size: Math.round(root.diameter * 0.62)
                appClass: Hypr.activeClass
                opacity: Hypr.activeClass !== "" ? 1 : 0.35

                Behavior on opacity { NumberAnimation { duration: Theme.durOpen } }
            }

            Text {
                anchors.centerIn: parent
                visible: Hypr.activeClass === ""
                text: "󰇄"
                font.family: Theme.fontIcons
                font.pixelSize: Theme.fontSize(1.1)
                color: Theme.barTextFaint
            }

            HoverHandler {
                onHoveredChanged: list.triggerHovered = hovered
            }

            MouseArea {
                id: circleArea
                anchors.fill: parent
                onClicked: {
                    // A click raises the focused window, which is the useful
                    // thing to do when the list is already open.
                    if (Hypr.activeToplevel)
                        Hypr.focusWindow(Hypr.activeToplevel.address)
                }
            }
        }
    }

    WindowList {
        id: list
        anchorItem: circle
        anchorAlign: "right"
    }
}
