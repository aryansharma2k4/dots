import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

/*
 * macOS Control Center. Opened by CLICK on the bar's filled circle, so it is
 * `pinned` rather than hover-driven — but it still inherits HoverPopup's open
 * and close animations, its bridge, and its glass.
 *
 * Two pages live in the same window: the tile grid, and a detail list (networks
 * or paired devices). Switching between them slides horizontally rather than
 * swapping, and the window height animates between the two — which is why the
 * detail page is always instantiated rather than loaded on demand: a Loader
 * would re-instantiate on every switch and drop frames mid-slide.
 */
HoverPopup {
    id: root

    // Popups are click-opened here; hovering the trigger must not open it.
    triggerHovered: false

    property string page: "home"        // "home" | "wifi" | "bluetooth"
    readonly property int homeHeight: 486
    readonly property int detailHeight: 380

    contentWidth: 330
    contentHeight: page === "home" ? homeHeight : detailHeight
    anchorAlign: "center"

    signal sinkPickerRequested(int x)

    Behavior on contentHeight {
        NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard }
    }

    onPinnedChanged: {
        if (pinned) {
            page = "home"
            Net.refresh()
        } else {
            Net.stopScan()
            Bt.setDiscovering(false)
        }
    }

    // "now" / "4m" / "2h" / "3d". Coarse on purpose: a notification's age is
    // read at a glance, and a precise one would only invite reading it twice.
    function ago(when) {
        if (!when)
            return ""
        const secs = Math.max(0, Math.round((Date.now() - when.getTime()) / 1000))
        if (secs < 45) return "now"
        if (secs < 3600) return Math.round(secs / 60) + "m"
        if (secs < 86400) return Math.round(secs / 3600) + "h"
        return Math.round(secs / 86400) + "d"
    }

    function openDetail(which) {
        root.page = which
        if (which === "wifi")
            Net.startScan()
        else if (which === "bluetooth")
            Bt.setDiscovering(true)
    }

    // Close the panel, then capture. The two steps cannot overlap: hyprshot
    // freezes the screen before the region drag, so a control centre still on
    // screen would be baked into the shot — and its layer surface would eat the
    // drag before slurp ever saw it. So wait out the full close: the grace
    // delay before the popup deactivates, plus the fade itself, plus a frame or
    // two of margin.
    function startScreenshot() {
        root.dismiss()
        screenshotDelay.restart()
    }

    Timer {
        id: screenshotDelay
        interval: Theme.closeDelay + Theme.durClose + 80
        onTriggered: Sys.captureRegion()
    }

    function back() {
        root.page = "home"
        Net.stopScan()
        Bt.setDiscovering(false)
    }

    Item {
        id: pages
        anchors.fill: parent
        clip: true

        // ===================================================== home ==========
        Item {
            id: home
            width: parent.width
            height: root.homeHeight
            x: root.page === "home" ? 0 : -width * 0.25
            opacity: root.page === "home" ? 1 : 0
            visible: opacity > 0.01

            Behavior on x { NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard } }
            Behavior on opacity { NumberAnimation { duration: Theme.durClose; easing.type: Theme.easeStandard } }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // ---- row: connectivity column + media / squares -------------
                // Left column is the three connectivity tiles; right column is
                // the media card with the two square tiles tucked underneath,
                // so both columns come out the same height.
                Row {
                    width: parent.width
                    spacing: 10

                    Column {
                        width: 172
                        spacing: 8

                        // 3 * 74 + 2 * 8 == 238, which is exactly the height of
                        // the media card + squares column beside it.
                        ToggleTile {
                            width: parent.width
                            height: 74
                            icon: Net.icon
                            label: "Wi-Fi"
                            subtitle: Net.subtitle
                            active: Net.wifiEnabled
                            enabled: Net.available
                            accent: Theme.wifi
                            splittable: true
                            onToggled: Net.toggle()
                            onDetailRequested: root.openDetail("wifi")
                        }

                        ToggleTile {
                            width: parent.width
                            height: 74
                            icon: Bt.icon
                            label: "Bluetooth"
                            subtitle: Bt.subtitle
                            active: Bt.enabled
                            enabled: Bt.available
                            accent: Theme.bluetooth
                            splittable: true
                            onToggled: Bt.toggle()
                            onDetailRequested: root.openDetail("bluetooth")
                        }

                        ToggleTile {
                            width: parent.width
                            height: 74
                            icon: "󰄀"
                            label: "Screenshot"
                            subtitle: Sys.screenshotAvailable ? "Select area" : "Unavailable"
                            active: false
                            enabled: Sys.screenshotAvailable
                            accent: Theme.accent
                            onToggled: root.startScreenshot()
                        }
                    }

                    Column {
                        width: 120
                        spacing: 8

                        // ---- compact media card, same MPRIS source as the pill
                        Rectangle {
                            width: parent.width
                            height: 174
                            radius: Theme.radiusTile
                            color: Theme.toggleOff
                            border.width: 1
                            border.color: Theme.alpha(Theme.rim, Theme.rim.a * 0.7)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                // Art is deliberately not square here: the tile
                                // has to leave room for two text lines and the
                                // transport row inside 174px.
                                Rectangle {
                                    width: parent.width
                                    height: 84
                                    radius: 8
                                    color: Theme.fillMid
                                    clip: true

                                    Image {
                                        id: ccArt
                                        anchors.fill: parent
                                        source: Media.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        // See WallpaperThumb: decoded at twice
                                        // the drawn size, never at the source's.
                                        sourceSize.width: width * 2
                                        sourceSize.height: height * 2
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !ccArt.visible
                                        text: "󰝚"
                                        font.family: Theme.fontIcons
                                        font.pixelSize: Theme.fontSize(1.5)
                                        color: Theme.textFaint
                                    }
                                }

                                MarqueeText {
                                    width: parent.width
                                    height: 15
                                    text: Media.title !== "" ? Media.title : "Not Playing"
                                    pixelSize: Theme.fontSizeSm
                                    weight: Font.DemiBold
                                    color: Theme.text
                                    fadeWidth: 0.2
                                }

                                MarqueeText {
                                    width: parent.width
                                    height: 13
                                    text: Media.artist
                                    pixelSize: Theme.fontSizeXs
                                    color: Theme.textDim
                                    fadeWidth: 0.2
                                    visible: Media.artist !== ""
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    IconButton {
                                        icon: "󰒮"; iconSize: Theme.fontSizeLg; diameter: 24
                                        enabled: Media.canGoPrevious
                                        onClicked: Media.previous()
                                    }
                                    IconButton {
                                        icon: Media.playing ? "󰏤" : "󰐊"; iconSize: Theme.fontSize(0.95); diameter: 24
                                        enabled: Media.available
                                        onClicked: Media.play()
                                    }
                                    IconButton {
                                        icon: "󰒭"; iconSize: Theme.fontSizeLg; diameter: 24
                                        enabled: Media.canGoNext
                                        onClicked: Media.next()
                                    }
                                }
                            }
                        }

                        // ---- two small square tiles ------------------------
                        Row {
                            width: parent.width
                            spacing: 8

                            // Power profile. Not a toggle — each click cycles
                            // to the next mode, and the icon plus its colour
                            // are what report which mode you are in, since a
                            // compact tile has no room for a label.
                            ToggleTile {
                                width: (parent.width - 8) / 2
                                height: 56
                                compact: true
                                icon: Power.profileIcon
                                active: false
                                enabled: Power.profileAvailable
                                accent: Power.profileColor
                                onToggled: Power.cycleProfile()
                            }

                            ToggleTile {
                                width: (parent.width - 8) / 2
                                height: 56
                                compact: true
                                icon: Sys.idleInhibited ? "󰅶" : "󰾪"
                                active: Sys.idleInhibited
                                accent: Theme.warning
                                onToggled: Sys.toggleIdleInhibit()
                            }
                        }
                    }
                }

                // ---- row: dark mode + focus --------------------------------
                Row {
                    width: parent.width
                    spacing: 10

                    ToggleTile {
                        width: (parent.width - 10) / 2
                        icon: "󰔎"
                        label: "Dark Mode"
                        subtitle: Sys.darkMode ? "On" : "Off"
                        active: Sys.darkMode
                        accent: Theme.accentAlt
                        onToggled: Sys.toggleDarkMode()
                    }

                    // The shell is the notification daemon now, so Focus is a
                    // flag we own rather than a CLI call out to swaync — and the
                    // right half of the tile opens what it has been holding.
                    ToggleTile {
                        width: (parent.width - 10) / 2
                        icon: Notif.dnd ? "󰂛" : "󰂚"
                        label: "Focus"
                        subtitle: Notif.dnd
                            ? (Notif.history.length > 0
                               ? Notif.history.length + " held" : "On")
                            : (Notif.pending > 0 ? Notif.pending + " showing" : "Off")
                        active: Notif.dnd
                        accent: Theme.accentAlt
                        splittable: true
                        onToggled: Notif.toggleDnd()
                        onDetailRequested: root.openDetail("notifications")
                    }
                }

                // ---- display -----------------------------------------------
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: Theme.radiusTile
                    color: Theme.toggleOff
                    border.width: 1
                    border.color: Theme.alpha(Theme.rim, Theme.rim.a * 0.7)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        text: "Display"
                        font.family: Theme.fontUI
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    GlassSlider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        iconLeft: "󰃞"
                        iconRight: "󰖨"
                        enabled: Brightness.available
                        value: Brightness.value
                        onMoved: v => { Brightness.dragging = true; Brightness.set(v) }
                        onReleased: Brightness.dragging = false
                    }
                }

                // ---- sound -------------------------------------------------
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: Theme.radiusTile
                    color: Theme.toggleOff
                    border.width: 1
                    border.color: Theme.alpha(Theme.rim, Theme.rim.a * 0.7)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        text: "Sound"
                        font.family: Theme.fontUI
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    GlassSlider {
                        id: volumeSlider
                        anchors.left: parent.left
                        anchors.right: sinkButton.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.bottomMargin: 10
                        iconLeft: "󰕿"
                        iconRight: "󰕾"
                        enabled: Audio.available
                        value: Audio.volume
                        onMoved: v => Audio.setVolume(v)
                    }

                    // Output device button, right edge of the sound row.
                    IconButton {
                        id: sinkButton
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: volumeSlider.verticalCenter
                        icon: "󱡬"
                        iconSize: Theme.fontSizeXl
                        diameter: 26
                        highlighted: true
                        iconColor: Theme.text
                        onClicked: {
                            const p = sinkButton.mapToItem(null, sinkButton.width / 2, 0)
                            root.sinkPickerRequested(Math.round(p.x))
                        }
                    }
                }
            }
        }

        // ================================================= detail list =======
        Item {
            id: detail
            width: parent.width
            height: root.detailHeight
            x: root.page === "home" ? width * 0.25 : 0
            opacity: root.page === "home" ? 0 : 1
            visible: opacity > 0.01

            Behavior on x { NumberAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard } }
            Behavior on opacity { NumberAnimation { duration: Theme.durClose; easing.type: Theme.easeStandard } }

            Item {
                id: detailHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 28

                IconButton {
                    id: backButton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "‹"
                    iconSize: Theme.fontSize(1.13)
                    diameter: 26
                    onClicked: root.back()
                }

                Text {
                    anchors.left: backButton.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.page === "wifi" ? "Wi-Fi"
                        : root.page === "bluetooth" ? "Bluetooth" : "Notifications"
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                // Scanning indicator, doubles as the "this list is live" cue.
                Text {
                    id: detailStatus
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.page !== "notifications"
                    text: root.page === "wifi"
                        ? (Net.wifiEnabled ? "Scanning…" : "Wi-Fi off")
                        : (Bt.enabled ? (Bt.discovering ? "Scanning…" : "Paired") : "Bluetooth off")
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textFaint
                }

                // Clearing is destructive and one click, so it only appears on
                // the page it applies to and only when there is something to
                // clear — never as a permanently armed button.
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.page === "notifications" && Notif.history.length > 0
                    text: "Clear"
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.DemiBold
                    color: clearArea.containsMouse ? Theme.accent : Theme.textDim

                    Behavior on color { ColorAnimation { duration: Theme.durHover } }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        onClicked: Notif.clearHistory()
                    }
                }
            }

            ListView {
                anchors.top: detailHeader.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottomMargin: 10
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                // Explicitly empty on the home page. Falling through to a
                // real list there would build delegates for a hidden view, and
                // bind them against whichever page's shape they did not match.
                model: root.page === "wifi" ? Net.networks
                     : root.page === "bluetooth" ? Bt.devices
                     : root.page === "notifications" ? Notif.history
                     : []

                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width

                    readonly property bool isWifi: root.page === "wifi"
                    readonly property bool isNotif: root.page === "notifications"

                    icon: isNotif
                        ? Notif.fallbackGlyph(modelData.appName)
                        : isWifi
                        ? (modelData.signal >= 75 ? "󰤨"
                         : modelData.signal >= 50 ? "󰤥"
                         : modelData.signal >= 25 ? "󰤢" : "󰤟")
                        : Bt.deviceIcon(modelData)
                    iconColor: isNotif
                        ? (modelData.urgency === 2 ? Theme.notifCritical : Theme.textDim)
                        : isWifi
                        ? (modelData.inUse ? Theme.wifi : Theme.textDim)
                        : (modelData.connected ? Theme.bluetooth : Theme.textDim)
                    label: isNotif
                        ? (modelData.summary !== "" ? modelData.summary : modelData.appName)
                        : isWifi ? modelData.ssid
                                 : (modelData.name || modelData.deviceName || "Device")
                    sublabel: isNotif
                        ? (modelData.body !== "" ? modelData.body : modelData.appName)
                        : isWifi
                        ? (modelData.inUse ? "Connected" : (modelData.secure ? "Secured" : "Open"))
                        : (modelData.connected ? "Connected" : "Paired")
                    // Relative, because "4m" is what you actually want to know
                    // about a notification you missed; an absolute clock time
                    // makes you do the subtraction yourself.
                    trailing: isNotif ? root.ago(modelData.time)
                                      : isWifi ? modelData.signal + "%" : ""
                    selected: isNotif ? false : isWifi ? modelData.inUse : modelData.connected
                    busy: !isNotif && !isWifi && modelData.pairing === true

                    onClicked: {
                        if (isNotif) {
                            // History is a record, not a live notification —
                            // the object behind it is long gone.
                        } else if (isWifi) {
                            if (modelData.inUse) Net.disconnectNetwork(modelData.ssid)
                            else Net.connect(modelData.ssid)
                        } else {
                            Bt.toggleDevice(modelData)
                        }
                    }
                }

                // Empty state — never an error, just an explanation.
                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: root.page === "notifications"
                        ? "Nothing yet"
                        : root.page === "wifi"
                        ? (Net.wifiEnabled ? "Looking for networks…" : "Wi-Fi is turned off")
                        : (Bt.available
                           ? (Bt.enabled ? "No paired devices" : "Bluetooth is turned off")
                           : "No Bluetooth adapter")
                    font.family: Theme.fontUI
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textFaint
                }
            }
        }
    }
}
