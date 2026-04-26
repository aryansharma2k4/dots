import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root

    property color base: "#0f1115"
    property color panel: "#171a20"
    property color panelRaised: "#1d2128"
    property color panelHover: "#232833"
    property color border: "#2a303b"
    property color text: "#eef2f7"
    property color muted: "#8f99aa"
    property color accent: "#d6dee9"
    property color accentSoft: "#20242d"
    property color success: "#9ccf9b"
    property color warning: "#f0c98a"

    property string activePage: "overview"
    property bool controlVisible: false
    property bool centerHovered: false
    property bool popupHovered: false

    property string clockText: "--:--"
    property string dateText: ""
    property string volumeText: "--"
    property string memoryText: "--"
    property string uptimeText: "--"
    property string wifiLabel: "wifi"
    property string wifiDetail: "checking status"
    property bool wifiEnabled: true

    property var player: {
        const players = Mpris.players.values || [];
        return players.length > 0 ? players[0] : null;
    }

    property var bluetoothAdapter: Bluetooth.defaultAdapter
    property var bluetoothDevices: Bluetooth.devices.values || []
    property var connectedBluetooth: {
        const devices = bluetoothDevices || [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected) {
                return devices[i];
            }
        }
        return null;
    }

    function showControl(page) {
        if (page) {
            activePage = page;
        }

        controlVisible = true;
        hideTimer.stop();
    }

    function scheduleHide() {
        if (!centerHovered && !popupHovered) {
            hideTimer.restart();
        }
    }

    function runDetached(command) {
        launcher.command = command;
        launcher.startDetached();
    }

    function readableSeconds(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);

        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }

        return `${minutes}m`;
    }

    function workspaceLabel(id) {
        const focused = Hyprland.focusedWorkspace;
        return focused && focused.id === id ? `0${id}` : `${id}`;
    }

    Component.onCompleted: {
        clockProc.running = true;
        dateProc.running = true;
        volumeProc.running = true;
        memoryProc.running = true;
        uptimeProc.running = true;
        wifiProc.running = true;
    }

    component ChipButton: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""
        property color fg: root.text

        signal clicked
        signal entered
        signal exited

        radius: 14
        color: mouseArea.containsMouse ? root.panelHover : "transparent"
        border.width: 1
        border.color: mouseArea.containsMouse ? root.border : "transparent"
        implicitHeight: 34
        implicitWidth: row.implicitWidth + 18

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Text {
                visible: chip.icon.length > 0
                text: chip.icon
                color: chip.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }

            Text {
                visible: chip.label.length > 0
                text: chip.label
                color: chip.fg
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                font.weight: 600
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
            onEntered: chip.entered()
            onExited: chip.exited()
        }
    }

    component StatCard: Rectangle {
        id: stat

        property string eyebrow: ""
        property string value: ""
        property string detail: ""

        radius: 20
        color: root.panelRaised
        border.width: 1
        border.color: root.border

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            Text {
                text: stat.eyebrow
                color: root.muted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.letterSpacing: 1.4
            }

            Text {
                text: stat.value
                color: root.text
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 22
                font.weight: 700
            }

            Text {
                text: stat.detail
                color: root.muted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                visible: text.length > 0
            }
        }
    }

    Process {
        id: launcher
    }

    Process {
        id: clockProc
        command: ["date", "+%H:%M"]
        stdout: StdioCollector {
            onStreamFinished: root.clockText = this.text.trim();
        }
    }

    Process {
        id: dateProc
        command: ["date", "+%a %d %b"]
        stdout: StdioCollector {
            onStreamFinished: root.dateText = this.text.trim();
        }
    }

    Process {
        id: volumeProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%d%%\", $2*100}'"]
        stdout: StdioCollector {
            onStreamFinished: root.volumeText = this.text.trim();
        }
    }

    Process {
        id: memoryProc
        command: ["sh", "-c", "free -h | awk '/Mem:/ {print $3 \" / \" $2}'"]
        stdout: StdioCollector {
            onStreamFinished: root.memoryText = this.text.trim();
        }
    }

    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        stdout: StdioCollector {
            onStreamFinished: root.uptimeText = this.text.trim();
        }
    }

    Process {
        id: wifiProc
        command: [
            "sh",
            "-c",
            "if nmcli radio wifi | grep -qi enabled; then ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1==\"yes\" {print $2; exit}'); echo \"on|${ssid:-wifi}|wireless enabled\"; else echo \"off|off|wireless disabled\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                root.wifiEnabled = parts[0] === "on";
                root.wifiLabel = parts[1] || "wifi";
                root.wifiDetail = parts[2] || "wireless status";
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockProc.running = true;
            dateProc.running = true;
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: volumeProc.running = true
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: {
            memoryProc.running = true;
            uptimeProc.running = true;
            wifiProc.running = true;
        }
    }

    Timer {
        id: hideTimer
        interval: 420
        repeat: false
        onTriggered: {
            if (!root.centerHovered && !root.popupHovered) {
                root.controlVisible = false;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            property var modelData

            screen: modelData
            aboveWindows: true
            focusable: false
            implicitHeight: 56
            color: "transparent"
            exclusiveZone: 56

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 10
                left: 12
                right: 12
            }

            Rectangle {
                id: bar
                anchors.fill: parent
                color: "transparent"

                Rectangle {
                    id: leftPill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 42
                    implicitWidth: leftRow.implicitWidth + 24
                    radius: 21
                    color: root.panel
                    border.width: 1
                    border.color: root.border

                    Row {
                        id: leftRow
                        anchors.centerIn: parent
                        spacing: 6

                        ChipButton {
                            icon: "󰊠"
                            fg: root.accent
                            onClicked: root.runDetached(["hyprshot", "-m", "region"])
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            radius: 1
                            color: root.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                const title = Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "";
                                return title.length > 0 ? title : "desktop";
                            }
                            color: root.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: 600
                            elide: Text.ElideRight
                            width: 240
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            radius: 1
                            color: root.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: [1, 2, 3, 4, 5]

                            delegate: ChipButton {
                                icon: ""
                                label: root.workspaceLabel(modelData)
                                fg: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData ? root.base : root.muted
                                color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData ? root.accent : "transparent"
                                border.color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData ? root.accent : "transparent"
                                implicitWidth: 38
                                onClicked: Hyprland.dispatch(`workspace ${modelData}`)
                            }
                        }
                    }
                }

                Rectangle {
                    id: centerPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 42
                    implicitWidth: centerRow.implicitWidth + 26
                    radius: 21
                    color: root.panel
                    border.width: 1
                    border.color: root.border

                    Row {
                        id: centerRow
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "control centre"
                            color: root.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.weight: 700
                        }

                        Text {
                            text: "•"
                            color: root.muted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }

                        Text {
                            text: root.player && root.player.trackTitle ? root.player.trackTitle : "hover to expand"
                            color: root.player && root.player.trackTitle ? root.accent : root.muted
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            width: 200
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            root.centerHovered = true;
                            root.showControl("overview");
                        }
                        onExited: {
                            root.centerHovered = false;
                            root.scheduleHide();
                        }
                        onClicked: {
                            root.controlVisible = !root.controlVisible;
                            if (root.controlVisible) {
                                root.activePage = "overview";
                            }
                        }
                    }
                }

                Rectangle {
                    id: rightPill
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: 42
                    implicitWidth: rightRow.implicitWidth + 24
                    radius: 21
                    color: root.panel
                    border.width: 1
                    border.color: root.border

                    Row {
                        id: rightRow
                        anchors.centerIn: parent
                        spacing: 4

                        ChipButton {
                            icon: "󰤨"
                            label: root.wifiLabel
                            fg: root.wifiEnabled ? root.text : root.muted
                            onClicked: root.showControl("wifi")
                        }

                        ChipButton {
                            icon: ""
                            label: root.connectedBluetooth ? root.connectedBluetooth.name : (root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "on" : "off")
                            fg: root.connectedBluetooth ? root.text : root.muted
                            onClicked: root.showControl("bluetooth")
                        }

                        ChipButton {
                            icon: "󰕾"
                            label: root.volumeText
                            onClicked: root.showControl("audio")
                        }

                        ChipButton {
                            icon: "󰁹"
                            label: UPower.displayDevice.ready ? `${Math.round(UPower.displayDevice.percentage)}%` : "--"
                            fg: UPower.onBattery ? root.warning : root.success
                            onClicked: root.showControl("power")
                        }

                        ChipButton {
                            icon: "󰥔"
                            label: root.clockText
                            onClicked: root.showControl("overview")
                        }
                    }
                }
            }

            PopupWindow {
                id: controlCenter
                visible: root.controlVisible
                anchor.window: panel
                anchor.rect.x: Math.round((bar.width - width) / 2)
                anchor.rect.y: bar.height + 10
                width: 680
                height: 430
                color: "transparent"
                HyprlandWindow.opacity: 0.98

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: Qt.rgba(23 / 255, 26 / 255, 32 / 255, 0.96)
                    border.width: 1
                    border.color: root.border

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onEntered: {
                            root.popupHovered = true;
                            hideTimer.stop();
                        }
                        onExited: {
                            root.popupHovered = false;
                            root.scheduleHide();
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 18

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: root.activePage === "overview" ? "Overview" :
                                      root.activePage === "wifi" ? "Wi-Fi" :
                                      root.activePage === "bluetooth" ? "Bluetooth" :
                                      root.activePage === "audio" ? "Audio" : "Power"
                                color: root.text
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 21
                                font.weight: 700
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: `${root.dateText} · ${root.clockText}`
                                color: root.muted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                            }
                        }

                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: root.activePage === "overview" ? 0 :
                                          root.activePage === "wifi" ? 1 :
                                          root.activePage === "bluetooth" ? 2 :
                                          root.activePage === "audio" ? 3 : 4

                            Item {
                                GridLayout {
                                    anchors.fill: parent
                                    columns: 2
                                    rowSpacing: 16
                                    columnSpacing: 16

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        eyebrow: "NOW PLAYING"
                                        value: root.player && root.player.trackTitle ? root.player.trackTitle : "Nothing active"
                                        detail: root.player && root.player.trackArtists ? root.player.trackArtists : "Start a player to surface metadata here"
                                    }

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        eyebrow: "SESSION"
                                        value: root.memoryText
                                        detail: `uptime ${root.uptimeText}`
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20
                                        color: root.panelRaised
                                        border.width: 1
                                        border.color: root.border

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            spacing: 12

                                            Text {
                                                text: "TRANSPORT"
                                                color: root.muted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                font.letterSpacing: 1.4
                                            }

                                            Row {
                                                spacing: 10

                                                ChipButton {
                                                    icon: "󰒮"
                                                    onClicked: root.runDetached(["playerctl", "previous"])
                                                }

                                                ChipButton {
                                                    icon: "󰐊"
                                                    label: "toggle"
                                                    onClicked: root.runDetached(["playerctl", "play-pause"])
                                                }

                                                ChipButton {
                                                    icon: "󰒭"
                                                    onClicked: root.runDetached(["playerctl", "next"])
                                                }
                                            }
                                        }
                                    }

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        eyebrow: "POWER"
                                        value: UPower.displayDevice.ready ? `${Math.round(UPower.displayDevice.percentage)}%` : "--"
                                        detail: UPower.onBattery
                                                ? `battery · ${root.readableSeconds(UPower.displayDevice.timeToEmpty)} left`
                                                : "plugged in"
                                    }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 16

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        eyebrow: "CURRENT NETWORK"
                                        value: root.wifiLabel === "wifi" ? "Not connected" : root.wifiLabel
                                        detail: root.wifiDetail
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ChipButton {
                                            icon: "󰤨"
                                            label: root.wifiEnabled ? "disable wifi" : "enable wifi"
                                            onClicked: root.runDetached(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"])
                                        }

                                        ChipButton {
                                            icon: "󰑐"
                                            label: "open network manager"
                                            onClicked: root.runDetached(["nm-connection-editor"])
                                        }
                                    }

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        eyebrow: "NOTE"
                                        value: "This Quickshell package lacks the Networking module"
                                        detail: "Wi-Fi controls here use nmcli and NetworkManager tools instead of native Quickshell networking bindings."
                                    }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 16

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        eyebrow: "ADAPTER"
                                        value: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "Enabled" : "Disabled"
                                        detail: root.connectedBluetooth ? `${root.connectedBluetooth.name} connected` : "no active bluetooth device"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ChipButton {
                                            icon: ""
                                            label: root.bluetoothAdapter && root.bluetoothAdapter.enabled ? "disable bluetooth" : "enable bluetooth"
                                            onClicked: {
                                                if (root.bluetoothAdapter) {
                                                    root.bluetoothAdapter.enabled = !root.bluetoothAdapter.enabled;
                                                }
                                            }
                                        }

                                        ChipButton {
                                            icon: "󰂯"
                                            label: "open blueman"
                                            onClicked: root.runDetached(["blueman-manager"])
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20
                                        color: root.panelRaised
                                        border.width: 1
                                        border.color: root.border

                                        ScrollView {
                                            anchors.fill: parent
                                            anchors.margins: 14

                                            Column {
                                                width: parent.width
                                                spacing: 10

                                                Repeater {
                                                    model: root.bluetoothDevices

                                                    delegate: Rectangle {
                                                        width: parent.width
                                                        height: 52
                                                        radius: 14
                                                        color: modelData.connected ? root.accentSoft : root.panel
                                                        border.width: 1
                                                        border.color: root.border

                                                        Row {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 14
                                                            anchors.rightMargin: 14
                                                            spacing: 10

                                                            Text {
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: modelData.connected ? "󰂱" : "󰂲"
                                                                color: root.text
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 16
                                                            }

                                                            Column {
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                spacing: 3

                                                                Text {
                                                                    text: modelData.name && modelData.name.length > 0 ? modelData.name : modelData.deviceName
                                                                    color: root.text
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 13
                                                                }

                                                                Text {
                                                                    text: modelData.batteryAvailable ? `battery ${Math.round(modelData.battery * 100)}%` : (modelData.connected ? "connected" : "available")
                                                                    color: root.muted
                                                                    font.family: "JetBrainsMono Nerd Font"
                                                                    font.pixelSize: 11
                                                                }
                                                            }
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: modelData.connected = !modelData.connected
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 16

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        eyebrow: "AUDIO"
                                        value: root.volumeText
                                        detail: "default output"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ChipButton {
                                            icon: "󰕾"
                                            label: "open mixer"
                                            onClicked: root.runDetached(["pavucontrol"])
                                        }

                                        ChipButton {
                                            icon: "󰖀"
                                            label: "raise"
                                            onClicked: root.runDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"])
                                        }

                                        ChipButton {
                                            icon: "󰕿"
                                            label: "lower"
                                            onClicked: root.runDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20
                                        color: root.panelRaised
                                        border.width: 1
                                        border.color: root.border

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            spacing: 14

                                            Text {
                                                text: "MEDIA SHORTCUTS"
                                                color: root.muted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                font.letterSpacing: 1.4
                                            }

                                            Row {
                                                spacing: 10

                                                ChipButton {
                                                    icon: "󰒮"
                                                    label: "prev"
                                                    onClicked: root.runDetached(["playerctl", "previous"])
                                                }

                                                ChipButton {
                                                    icon: "󰐊"
                                                    label: "play/pause"
                                                    onClicked: root.runDetached(["playerctl", "play-pause"])
                                                }

                                                ChipButton {
                                                    icon: "󰒭"
                                                    label: "next"
                                                    onClicked: root.runDetached(["playerctl", "next"])
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 16

                                    StatCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 120
                                        eyebrow: "BATTERY"
                                        value: UPower.displayDevice.ready ? `${Math.round(UPower.displayDevice.percentage)}%` : "--"
                                        detail: UPower.onBattery ? `remaining ${root.readableSeconds(UPower.displayDevice.timeToEmpty)}` : "charging or plugged"
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        ChipButton {
                                            icon: "󰌾"
                                            label: "lock"
                                            onClicked: root.runDetached(["hyprlock"])
                                        }

                                        ChipButton {
                                            icon: "󰍃"
                                            label: "logout"
                                            onClicked: root.runDetached(["hyprctl", "dispatch", "exit"])
                                        }

                                        ChipButton {
                                            icon: "󰜉"
                                            label: "reboot"
                                            onClicked: root.runDetached(["systemctl", "reboot"])
                                        }

                                        ChipButton {
                                            icon: "󰐥"
                                            label: "shutdown"
                                            onClicked: root.runDetached(["systemctl", "poweroff"])
                                        }

                                        ChipButton {
                                            icon: "⏻"
                                            label: "menu"
                                            onClicked: root.runDetached(["/home/aryan/.config/rofi/scripts/power_menu.sh"])
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 20
                                        color: root.panelRaised
                                        border.width: 1
                                        border.color: root.border

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            spacing: 12

                                            Text {
                                                text: "STATUS"
                                                color: root.muted
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                font.letterSpacing: 1.4
                                            }

                                            Text {
                                                text: `memory ${root.memoryText}`
                                                color: root.text
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }

                                            Text {
                                                text: `uptime ${root.uptimeText}`
                                                color: root.text
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 13
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
