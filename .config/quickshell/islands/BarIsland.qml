import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../popups"
import "../services"

// CENTRE ISLAND — workspaces, focused window, icon cluster, clock.
Scope {
    id: root

    readonly property int pad: 20
    readonly property int barHeight: Theme.barHeight

    signal sinkPickerRequested(int x)

    // Opens/closes the session actions under the cluster's power glyph. Exposed
    // for the same reason toggleControlCenter is: SUPER+X drives it over IPC.
    function togglePowerMenu() { powerMenu.pinned = !powerMenu.pinned }
    function closePowerMenu() { powerMenu.pinned = false }

    // The centre island's own glass width, published so the power island —
    // which has to sit one gap to the right of it — can follow it as the
    // focused window title changes the bar's width.
    readonly property int islandWidth: bar.width

    property date now: new Date()

    // Retracts into the top edge while the Vicinae launcher is open — the
    // launcher sits exactly here. Leads the retract and trails the return; the
    // power pill is the other half of the pair.
    IslandRetract { id: retract; travel: root.barHeight; centre: true }

    // Opens/closes the control centre under the bar's circle. Exposed so a
    // keybind can drive it through the shell's IpcHandler, not just a click.
    function toggleControlCenter() { controlCenter.pinned = !controlCenter.pinned }

    // Dynamic island <-> macOS notch, driven by SUPER+SHIFT+N over IPC. The
    // flag lives on Theme rather than here because the shape and the palette
    // are two halves of one mode, and the palette has to reach into components
    // (the carousel, the marquee) that this file only passes colours to.
    function toggleNotch() { Theme.notch = !Theme.notch }

    function closeControlCenter() { controlCenter.pinned = false }

    // Straight to the notification history, skipping the tile grid — what the
    // Focus tile's right half does, reachable from a keybind or a script.
    function showNotificationHistory() {
        controlCenter.pinned = true
        controlCenter.openDetail("notifications")
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    PanelWindow {
        id: window

        // No left/right anchor: the surface centres itself on the output.
        anchors.top: true
        // Pinned at the top of the screen and never moved. The mode change is a
        // move *within* this surface (see bar.y), not a change to the surface:
        // animating a layer-shell margin would renegotiate the surface geometry
        // with the compositor on every frame of the morph, which is both janky
        // and a fight the shell cannot win. `pad` is subtracted here for the
        // reason given under exclusiveZone below.
        margins.top: -root.pad

        // Rounded, not raw: content.implicitWidth comes from text metrics and is
        // fractional, and a surface on a half pixel gives every edge drawn
        // against it something to resample.
        implicitWidth: Math.round(content.implicitWidth) + Theme.islandPadding * 2 + root.pad * 2
        // Tall enough for the island's resting position, which hangs
        // Theme.screenMargin lower than the flush notch's.
        implicitHeight: root.barHeight + root.pad * 2 + Theme.screenMargin
        color: "transparent"

        // The one surface that reserves screen space for all three islands —
        // see Theme.exclusiveZone for why it must not be more than one.
        //
        // Layer-shell measures the exclusive zone from the *anchored edge of
        // this surface*, then adds the surface's own top margin. This window is
        // deliberately inflated by `pad` (so the drop shadow has room) and
        // pulled back up by a negative margin to compensate, so that margin has
        // to be added back here — otherwise the reserved strip comes out `pad`
        // pixels short and windows tuck under the islands.
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Theme.exclusiveZone - margins.top

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top
        mask: retract.interactive ? barMask : emptyMask
        Region { id: barMask; item: bar }
        Region { id: emptyMask }

        GlassSurface {
            id: bar
            x: root.pad
            // The one thing that moves between the two modes: the notch sits
            // flush against the screen edge, the island floats below it.
            y: root.pad + Theme.barTopMargin

            Behavior on y {
                NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard }
            }

            width: Math.round(content.implicitWidth) + Theme.islandPadding * 2
            height: root.barHeight
            radius: Theme.radiusIsland

            // The mode. Opaque black with square shoulders, no glass chrome
            // and flared top corners is a notch; frosted, round and lit on
            // every edge is the island. Every piece of that animates on its own
            // Behavior, so the two shapes are the ends of one continuous morph
            // rather than a swap between skins.
            //
            // The flare draws into the window's `pad`, which is why pad must
            // stay >= Theme.radiusNotchFlare.
            followsNotch: true

            opacity: retract.fade
            transform: [
                Scale { origin.x: bar.width / 2; xScale: retract.zoom; yScale: retract.zoom },
                Translate { y: retract.offsetY }
            ]

            Row {
                id: content
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.islandPadding
                // Sections read as distinct groups rather than one dense strip.
                spacing: Theme.sectionSpacing

                // ---- workspaces ---------------------------------------------
                Item {
                    width: carousel.implicitWidth
                    height: parent.height

                    WorkspaceCarousel {
                        id: carousel
                        anchors.centerIn: parent
                        visibleCount: 5
                    }
                }

                // ---- focused window ------------------------------------------
                // Generous horizontal padding on both sides — this gap is what
                // stops the bar reading as a row of crammed widgets.
                Item {
                    width: Theme.titleWidth
                    height: parent.height

                    MarqueeText {
                        anchors.fill: parent
                        text: Hypr.activeTitle !== "" ? Hypr.activeTitle : "Desktop"
                        pixelSize: Theme.fontSizeTitle
                        weight: Font.DemiBold
                        color: Theme.barText
                        // Fades on both edges, so a scrolling title dissolves
                        // at either boundary instead of being hard-clipped.
                        fadeWidth: 0.12
                        fadeWidthLeft: 0.08
                        // Scrolls only when the title actually overflows; a
                        // short title sits centred and perfectly still.
                        scroll: true
                        centered: true
                        startPause: Theme.marqueePause
                        // Restart the scroll when the focused window changes,
                        // not when the app edits its own title.
                        resetKey: Hypr.activeToplevel ? Hypr.activeToplevel.address : ""
                    }
                }

                // ---- icon cluster --------------------------------------------
                // Every control here is Theme.barHitSize wide and the full
                // height of the bar. The glyphs stay small; it is the invisible
                // padding around them that does the work, so hitting the power
                // button rather than the control centre beside it stops taking
                // aim. The row's own spacing is 0 for the same reason — the gap
                // you see between two circles is that padding, and spending it
                // on real spacing instead would only shrink the targets again.
                Row {
                    height: parent.height
                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Power.available
                        icon: Power.icon
                        iconSize: Theme.iconSizeBar
                        diameter: Theme.barButtonSize
                        hitPadding: Theme.barHitPadding
                        hoverColor: Theme.barFillHover
                        iconColor: Power.percentage < 0.15 && !Power.charging
                            ? Theme.danger : Theme.barTextDim
                    }

                    IconButton {
                        id: btIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Bt.icon
                        iconSize: Theme.iconSizeBarSmall
                        diameter: Theme.barButtonSize
                        hitPadding: Theme.barHitPadding
                        hoverColor: Theme.barFillHover
                        enabled: Bt.available
                        iconColor: Bt.enabled ? Theme.bluetooth : Theme.barTextDim
                        onClicked: Bt.toggle()
                    }

                    IconButton {
                        id: searchIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "󰍉"
                        iconSize: Theme.iconSizeBarSmall
                        diameter: Theme.barButtonSize
                        hitPadding: Theme.barHitPadding
                        hoverColor: Theme.barFillHover
                        enabled: Sys.launcherAvailable
                        iconColor: Theme.barTextDim
                        // The same gesture as SUPER+SPACE, not a second
                        // launcher of its own — see Sys.launcher.
                        onClicked: Sys.openLauncher()
                    }

                    IconButton {
                        id: netIcon
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Net.icon
                        iconSize: Theme.iconSizeBarSmall
                        diameter: Theme.barButtonSize
                        hitPadding: Theme.barHitPadding
                        hoverColor: Theme.barFillHover
                        enabled: Net.available
                        iconColor: Net.connected ? Theme.wifi : Theme.barTextDim
                        onClicked: Net.toggle()
                    }

                    // Control centre — the macOS two-slider glyph, opened on
                    // CLICK. Deliberately not a circle any more: a filled dot
                    // sat next to the magnifying glass and both read as
                    // "search".
                    Item {
                        id: ccSlot
                        width: Theme.barHitSize
                        height: parent.height
                        // The tooltip below reads `hovered` off every target
                        // uniformly. IconButton publishes it already; these two
                        // slots drive their glyph from a bare MouseArea, so
                        // they publish the same thing rather than making the
                        // tooltip know the difference.
                        readonly property bool hovered: ccArea.containsMouse

                        ControlCenterIcon {
                            id: ccIcon
                            anchors.centerIn: parent
                            size: Theme.fontSize(1.15)
                            color: controlCenter.pinned ? Theme.accent : Theme.barTextDim
                            scale: ccArea.pressed ? 0.86 : (ccArea.containsMouse ? 1.12 : 1.0)

                            Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
                        }

                        MouseArea {
                            id: ccArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.toggleControlCenter()
                        }
                    }

                    // Session actions. The glyph lives in the cluster with the
                    // other status controls rather than out on the bar as its
                    // own island — the four actions get a pill of their own,
                    // hanging under this icon, only once it is clicked.
                    Item {
                        id: powerSlot
                        width: Theme.barHitSize
                        height: parent.height
                        readonly property bool hovered: powerArea.containsMouse

                        PowerGlyph {
                            id: powerIcon
                            anchors.centerIn: parent
                            size: Theme.fontSize(1.05)
                            glyph: "power"
                            color: powerMenu.pinned ? Theme.accent : Theme.barTextDim
                            scale: powerArea.pressed ? 0.86 : (powerArea.containsMouse ? 1.12 : 1.0)

                            Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        }

                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.togglePowerMenu()
                        }
                    }
                }

                // ---- clock -----------------------------------------------------
                Item {
                    width: clockRow.implicitWidth
                    height: parent.height

                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 9

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(root.now, "ddd MMM d")
                            font.family: Theme.fontUI
                            font.features: Theme.tabularFigures
                            font.pixelSize: Theme.fontSizeBar
                            color: Theme.barTextDim
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatDateTime(root.now, "h:mm AP")
                            font.family: Theme.fontUI
                            font.features: Theme.tabularFigures
                            font.pixelSize: Theme.fontSizeBar
                            font.weight: Font.DemiBold
                            color: Theme.barText
                        }
                    }
                }
            }
        }
    }

    // ---- status tooltips -------------------------------------------------------
    // ONE tooltip, retargeted — not one per icon. Every HoverPopup is its own
    // layer-shell window with its own Qt scene graph and Mesa context behind
    // it, and that per-window cost dwarfs anything a caption this small could
    // possibly need. Three of them for three captions that can never be on
    // screen at the same time was three windows to save writing a switch.
    //
    // Retargeting also gives the thing macOS does for free: slide the pointer
    // from wifi to bluetooth and the caption glides across and swaps its text,
    // instead of one popup closing and another opening in its place.

    readonly property var tipTargets: [batteryIcon, btIcon, netIcon,
                                       searchIcon, ccSlot, powerSlot]

    // A control whose own panel is already open does not also get a caption:
    // the panel says what the icon is far better than a word under it could,
    // and the two would be stacked on top of each other.
    function tipSuppressed(item) {
        return (item === ccSlot && controlCenter.pinned)
            || (item === powerSlot && powerMenu.pinned)
    }

    // Whichever is under the pointer, or null.
    readonly property Item hoveredTip: {
        for (let i = 0; i < tipTargets.length; i++) {
            const t = tipTargets[i]
            if (t.visible && t.hovered && !tipSuppressed(t))
                return t
        }
        return null
    }

    // The last one that WAS hovered, kept so the caption has somewhere to be
    // anchored while it animates out. Without this it would snap to the screen
    // edge on the way down, the moment the pointer left.
    property Item tipAnchor: null
    onHoveredTipChanged: if (hoveredTip) tipAnchor = hoveredTip

    function tipTextFor(item) {
        if (item === batteryIcon) {
            const pct = Math.round(Power.percentage * 100) + "%"
            return Power.charging ? pct + " · Charging" : pct
        }
        if (item === btIcon)
            // Bt.subtitle is already "the connected device, else On/Off/
            // Unavailable" — the same string the control centre's tile shows.
            return "Bluetooth · " + Bt.subtitle
        if (item === netIcon)
            // Net.subtitle resolves to the SSID when there is one, and to
            // Wired / Off / Connecting… / Not Connected when there is not.
            return Net.subtitle + (Net.ssid !== "" && Net.strength > 0
                                   ? " · " + Net.strength + "%" : "")
        // The three that do something rather than report something. The two
        // that have a keybind name it, so the caption teaches the shortcut
        // instead of restating the glyph; both are bound in
        // ~/.config/hypr/config/keybinds.lua. The control centre has none —
        // it is reachable over IPC but nothing calls it, so there is nothing
        // honest to put there.
        if (item === searchIcon)
            return "Search · Super+Space"
        if (item === ccSlot)
            return "Control Centre"
        if (item === powerSlot)
            return "Session · Super+X"
        return ""
    }

    BarTooltip {
        anchorItem: root.tipAnchor
        anchorBounds: bar
        triggerHovered: root.hoveredTip !== null
        text: root.tipTextFor(root.tipAnchor)
    }

    // ---- session actions -------------------------------------------------------
    PowerMenu {
        id: powerMenu
        // Centred on the glyph; clears the whole island vertically, so it never
        // sits over the bar it hangs from.
        anchorItem: powerIcon
        anchorBounds: bar
    }

    // ---- control centre --------------------------------------------------------
    ControlCenter {
        id: controlCenter
        // Horizontally centred on the icon; vertically it clears the whole
        // island, not just the icon, so it never sits over the bar.
        anchorItem: ccIcon
        anchorBounds: bar
        // Hangs off the centre island, so it goes when the centre island goes.
        hidesWithLauncher: true
        onSinkPickerRequested: x => root.sinkPickerRequested(x)
    }
}
