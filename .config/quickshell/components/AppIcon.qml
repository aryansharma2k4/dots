import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."

// Resolves a Hyprland window class to a themed icon, falling back to the first
// letter of the class in a tinted well when the desktop entry cannot be found
// (Electron apps and terminals-with-custom-classes miss surprisingly often).
Item {
    id: root

    property string appClass: ""
    property int size: 20

    implicitWidth: size
    implicitHeight: size

    // DesktopEntries scans the applications directories lazily and finishes
    // asynchronously, so a lookup made in the first frames comes back null.
    // Depending on the entry count re-runs the lookup once the scan lands.
    readonly property int entryCount: DesktopEntries.applications?.values?.length ?? 0
    readonly property var entry: appClass !== "" && entryCount >= 0
        ? DesktopEntries.heuristicLookup(appClass) : null
    readonly property string iconName: entry?.icon || appClass.toLowerCase()
    readonly property string resolved: iconName !== "" ? Quickshell.iconPath(iconName, true) : ""

    IconImage {
        id: image
        anchors.fill: parent
        source: root.resolved
        visible: root.resolved !== ""
        asynchronous: true
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !image.visible
        radius: width * 0.28
        color: Theme.fillStrong

        Text {
            anchors.centerIn: parent
            text: (root.appClass || "?").charAt(0).toUpperCase()
            font.family: Theme.fontUI
            font.pixelSize: Math.round(root.size * 0.55)
            font.weight: Font.DemiBold
            color: Theme.textDim
        }
    }
}
