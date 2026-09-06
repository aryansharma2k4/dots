import QtQuick
import ".."
import "../services"

/*
 * The square at the left of a notification: the image the app supplied, its
 * icon, or — when it gave neither — a glyph guessed from its name.
 *
 * `image` is the notification's own picture (an album cover, a contact's
 * avatar); `appIcon` is the application's icon. Preferring the former is what
 * makes a message notification show who sent it rather than the chat app's
 * logo, which is the whole reason the spec carries both.
 */
Item {
    id: root

    property string image: ""
    property string appIcon: ""
    property string appName: ""
    property int size: Theme.notifIcon
    property color tint: Theme.barTextDim

    implicitWidth: size
    implicitHeight: size

    readonly property string source: {
        if (image !== "")
            return image
        if (appIcon !== "")
            return appIcon.startsWith("/") || appIcon.startsWith("file:")
                 ? appIcon : Quickshell.iconPath(appIcon, true)
        return ""
    }

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.fillWeak
        clip: true

        Image {
            id: art
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
            visible: status === Image.Ready
        }

        // The fallback. Sized off the plate rather than off Theme so it keeps
        // its proportion when a caller asks for a smaller icon.
        Text {
            anchors.centerIn: parent
            visible: !art.visible
            text: Notif.fallbackGlyph(root.appName)
            font.family: Theme.fontIcons
            font.pixelSize: Math.round(root.size * 0.52)
            color: root.tint
        }
    }
}
