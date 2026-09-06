import QtQuick
import ".."

/*
 * A one-line label that hangs under a bar control while the cursor rests on it.
 *
 * It is a HoverPopup like every other panel, not a bespoke surface: that is
 * what gives it the hover bridge across the gap, the grace period on close, the
 * open/close animation, and the retract-with-the-launcher behaviour, all for
 * free and all identical to the control centre's.
 *
 * Shaped as a stadium (radius is half its height) and sized to its own text, so
 * it reads as a caption rather than as a panel with something in it. Purely
 * informational — it is never pinned, and nothing inside it is clickable.
 */
HoverPopup {
    id: root

    property alias text: label.text
    property int hPadding: Theme.innerPadding * 2

    contentWidth: Math.round(label.implicitWidth) + hPadding * 2
    contentHeight: Math.round(label.implicitHeight) + Theme.innerPadding * 2
    popupRadius: contentHeight / 2

    anchorAlign: "center"
    // Hangs off the centre island, so it goes when the centre island retracts.
    hidesWithLauncher: true

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontUI
        font.pixelSize: Theme.fontSize(0.85)
        font.weight: Font.Medium
        color: Theme.text
    }
}
