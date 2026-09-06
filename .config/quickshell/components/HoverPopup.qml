import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/*
 * Shared base for everything that opens under an island.
 *
 * Two problems this solves once, so no popup has to solve them again:
 *
 * 1. THE BRIDGE. The popup hangs `anchorGap` pixels below its trigger. Without
 *    help, the cursor leaves the trigger, crosses that gap over the desktop,
 *    and the popup closes before it is reached. So the popup's shell starts at
 *    the trigger's bottom edge and its first `bridgeHeight` pixels are empty:
 *    an invisible hover region spanning exactly the gap. Because bridgeHeight
 *    is derived from anchorGap, the two always stay in step — changing the gap
 *    can never open a dead strip the cursor falls through.
 *
 * 2. THE GRACE PERIOD. Closing is driven by "neither the trigger nor the popup
 *    is hovered, and has not been for closeDelay ms". Any hover on either side
 *    cancels the pending close, so flicking diagonally across a corner does not
 *    dismiss anything.
 *
 * Open animates scale 0.94 -> 1, opacity 0 -> 1, a small downward translate,
 * and the glass fill alpha 0 -> full, all on an OutBack overshoot: the panel
 * condenses into existence. Close is faster, OutCubic, and does not overshoot.
 */
PanelWindow {
    id: root

    // --- interface ---------------------------------------------------------
    property bool triggerHovered: false      // driven by the island's HoverHandler
    property bool pinned: false              // click-opened popups stay until dismissed
    property int contentWidth: 300
    property int contentHeight: 200
    property int popupRadius: Theme.radiusPopup

    // --- anchoring ---------------------------------------------------------
    // `anchorItem` is what the popup lines up with horizontally — the actual
    // trigger, e.g. the control-centre icon, not its island. The cluster's
    // layout shifts whenever the window title changes width, so this is
    // resolved reactively from the item's live position, never from a fixed
    // offset off an island edge.
    //
    // `anchorBounds` is what the popup clears vertically. It defaults to the
    // anchor item, but for a control sitting *inside* an island it must be the
    // island itself — otherwise the popup would start at the icon's bottom edge
    // and cover the rest of the bar.
    property Item anchorItem: null
    property Item anchorBounds: anchorItem
    property int anchorGap: 8
    property string anchorAlign: "center"    // "center" | "left" | "right"

    // Fallback placement for popups opened from inside another popup (the sink
    // picker), which have no island of their own to hang from.
    property int anchorX: 0
    property bool anchorRight: false
    property int anchorTopFallback: Theme.exclusiveZone

    // Quickshell layer surfaces do not know their own position: `window.x` is
    // undefined, and Item.mapToGlobal wrongly assumes the surface sits at the
    // screen origin (it returns screen.x + localX even for a centred bar). So
    // the window's origin is derived from the anchoring rules it was given.
    // Every term below is a live property read, so this re-evaluates on resize
    // and on monitor change.
    function windowOriginX(win) {
        if (!win || !win.screen)
            return 0
        if (win.anchors.left)
            return win.margins.left
        if (win.anchors.right)
            return win.screen.width - win.width - win.margins.right
        return Math.round((win.screen.width - win.width) / 2)    // centred
    }

    function windowOriginY(win) {
        if (!win || !win.screen)
            return 0
        if (win.anchors.top)
            return win.margins.top
        if (win.anchors.bottom)
            return win.screen.height - win.height - win.margins.bottom
        return Math.round((win.screen.height - win.height) / 2)
    }

    // Offset of an item within its window, summed up the parent chain.
    //
    // This is deliberately NOT mapToItem/mapToGlobal: those are plain function
    // calls, so a binding using them evaluates once and then never updates —
    // which is exactly the drift the fixed-offset approach would have had. Each
    // `node.x` here is a property *read*, so QML captures every ancestor as a
    // dependency and the position recomputes whenever anything in the chain
    // moves, including the icon cluster sliding as the window title resizes.
    function offsetX(item) {
        let v = 0
        for (let node = item; node; node = node.parent)
            v += node.x
        return v
    }

    function offsetY(item) {
        let v = 0
        for (let node = item; node; node = node.parent)
            v += node.y
        return v
    }

    // Screen-space geometry of the trigger. This popup's own surface spans the
    // full screen width from the screen origin, so screen-space x is also this
    // window's local x — no second conversion needed.
    readonly property real anchorLeftEdge: {
        if (!anchorItem)
            return anchorRight ? anchorX - contentWidth : anchorX
        return windowOriginX(anchorItem.QsWindow.window) + offsetX(anchorItem)
    }

    readonly property real anchorSpan: anchorItem ? anchorItem.width : 0

    readonly property real anchorBottomEdge: {
        const item = anchorBounds || anchorItem
        if (!item)
            return anchorTopFallback
        return windowOriginY(item.QsWindow.window) + offsetY(item) + item.height
    }

    // panelX = iconX + iconWidth/2 - panelWidth/2, then clamped so a trigger
    // near the screen edge cannot push the panel off it.
    readonly property int panelX: {
        let x
        if (!anchorItem)
            x = anchorLeftEdge
        else if (anchorAlign === "left")
            x = anchorLeftEdge
        else if (anchorAlign === "right")
            x = anchorLeftEdge + anchorSpan - contentWidth
        else
            x = anchorLeftEdge + anchorSpan / 2 - contentWidth / 2

        const screenWidth = root.screen ? root.screen.width : root.width
        const rightLimit = screenWidth - contentWidth - Theme.screenMargin
        return Math.round(Math.min(Math.max(Theme.screenMargin, x),
                                   Math.max(Theme.screenMargin, rightLimit)))
    }

    // The popup's glass starts one gap below whatever it hangs from.
    readonly property int panelY: Math.round(anchorBottomEdge) + anchorGap

    // The invisible hover strip joining trigger to popup. It spans exactly the
    // gap, so the two surfaces touch and crossing it never counts as leaving.
    readonly property int bridgeHeight: anchorGap

    default property alias body: bodyHolder.data

    // Set on popups that hang off an island which retracts when the launcher
    // opens (the centre bar and the power pill). A popup running its own close
    // animation while its island slides out from under it reads as a glitch
    // rather than as one gesture, so those get a hard cut instead: state
    // cleared, timers stopped, every duration below zeroed, gone on the next
    // frame while the island does the animating.
    //
    // Off by default — the media card and the window list hang off islands that
    // stay exactly where they are, so nothing should disturb them.
    property bool hidesWithLauncher: false

    readonly property bool suppressed: hidesWithLauncher
                                       && Theme.launcherHideEnabled
                                       && Hypr.launcherOpen

    onSuppressedChanged: {
        if (!suppressed)
            return
        pinned = false
        triggerHovered = false
        popupHovered = false
        closeTimer.stop()
        active = false
    }

    // Zero while suppressed, so the cut costs no frames.
    readonly property int animDuration: suppressed ? 0
                                      : (active ? Theme.durOpen : Theme.durClose)

    readonly property bool shouldShow: !suppressed && (triggerHovered || popupHovered || pinned)
    property bool popupHovered: false
    property bool active: false              // drives the animation state

    signal dismissed()

    function dismiss() {
        pinned = false
        triggerHovered = false
        popupHovered = false
    }

    // --- window ------------------------------------------------------------
    // Full width so the content can be positioned anywhere along the bar
    // without resizing the surface (resizing a layer surface mid-animation is
    // where the frame drops come from).
    // Hover-driven popups are only as tall as they need to be, so the desktop
    // under them stays clickable. A click-opened (pinned) popup instead covers
    // the screen, because it needs to catch the click-outside that dismisses it
    // — macOS closes Control Center the same way.
    anchors {
        top: true
        left: true
        right: true
        bottom: root.pinned
    }
    implicitHeight: root.panelY + contentHeight + Theme.shadowRadius + Theme.shadowOffset
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: active || fadeOut.running || shell.opacity > 0.01
    // A null mask means the whole surface takes input, which is exactly what
    // the click-outside catcher needs; otherwise only the card and its bridge.
    mask: root.pinned ? null : hitMask

    WlrLayershell.layer: WlrLayer.Overlay
    // Keyed to the layerrule blur entries in the Hyprland config. Renaming this
    // silently removes the backdrop blur from every popup.
    WlrLayershell.namespace: "quickshell-popup"
    // A pinned panel already swallows every pointer event on the screen — that
    // is what makes click-outside-to-dismiss work — so taking the keyboard too
    // is consistent: it is modal while open, and any keystroke closes it. Hover
    // popups never take the keyboard.
    WlrLayershell.keyboardFocus: root.pinned ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None

    onShouldShowChanged: {
        if (shouldShow) {
            closeTimer.stop()
            root.active = true
        } else {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.closeDelay
        onTriggered: if (!root.shouldShow) { root.active = false; root.dismissed() }
    }

    // --- auto dismiss ------------------------------------------------------
    // Click-opened panels close on their own once the pointer has been still
    // for a while, so one never gets stranded on screen. Hover popups are
    // excluded: they already close the moment the cursor leaves them, and an
    // idle timer there would yank a panel away while it was being read.
    property int idleDismissMs: Theme.idleDismiss

    // Timer.restart() is a C++ method, not a JS property write, so the
    // `running` binding below survives it and the timer still stops when the
    // panel closes.
    function noteActivity() { if (idleTimer.running) idleTimer.restart() }

    Timer {
        id: idleTimer
        interval: root.idleDismissMs
        running: root.pinned && root.idleDismissMs > 0
        onTriggered: root.dismiss()
    }

    // Any keystroke dismisses. The grab means the key does not reach the app
    // underneath, which is the trade for being able to detect typing at all:
    // Hyprland only exposes key events to its own Lua config, and reaching the
    // shell from there would mean spawning a process on every keypress.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (!root.pinned)
                return
            root.dismiss()
            event.accepted = true
        }
    }

    // Only the bridge strip plus the card accept input; the rest of this
    // full-width surface must stay click-through.
    Region { id: hitMask; item: hitRegion }

    Item {
        id: hitRegion
        x: shell.x
        y: shell.y
        width: shell.width
        height: Math.min(root.height - shell.y, shell.height + Theme.shadowRadius)
        visible: false
    }

    // Click-outside catcher. Sits behind the card, so it only ever sees clicks
    // that missed it.
    MouseArea {
        anchors.fill: parent
        enabled: root.pinned
        visible: root.pinned
        hoverEnabled: true
        z: -1
        onClicked: root.dismiss()
        // This catcher spans the whole screen while pinned, so it is also how
        // pointer movement *outside* the panel resets the idle timer.
        onPositionChanged: root.noteActivity()
    }

    Item {
        id: shell
        x: root.panelX
        // The shell starts at the trigger's bottom edge; its first `bridgeHeight`
        // pixels are the hover bridge and the glass begins after them.
        y: root.panelY - root.bridgeHeight
        width: root.contentWidth
        height: root.contentHeight + root.bridgeHeight

        opacity: root.active ? 1 : 0
        // Condense into existence: scale up from 0.94 about the top of the card.
        scale: root.active ? 1.0 : 0.94
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                id: fadeOut
                duration: root.animDuration
                easing.type: root.active ? Theme.easeStandard : Theme.easeClose
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.animDuration
                easing.type: root.active ? Theme.easeOpen : Theme.easeClose
                easing.overshoot: Theme.easeOpenOvershoot
            }
        }

        HoverHandler {
            id: popupHover
            onHoveredChanged: root.popupHovered = hovered
            // Movement inside the panel counts as activity too, so reading or
            // adjusting a slider does not let the idle timer fire underneath.
            onPointChanged: root.noteActivity()
        }

        GlassSurface {
            id: glass
            x: 0
            // The downward translate. Starts 8px high and settles into place.
            y: root.bridgeHeight + (root.active ? 0 : -8)
            width: parent.width
            height: root.contentHeight
            radius: root.popupRadius
            // Fill alpha animates from 0 so the frost condenses rather than
            // appearing already solid under a fading-in card.
            fill: Theme.alpha(Theme.glassPopup, Theme.glassPopup.a * (root.active ? 1 : 0))
            rimColor: Theme.alpha(Theme.rim, Theme.rim.a * (root.active ? 1 : 0))
            topRimColor: Theme.alpha(Theme.rimTop, Theme.rimTop.a * (root.active ? 1 : 0))
            shadowEnabled: Theme.shadowsEnabled && root.active

            Behavior on y {
                NumberAnimation {
                    duration: root.animDuration
                    easing.type: root.active ? Theme.easeOpen : Theme.easeClose
                    easing.overshoot: Theme.easeOpenOvershoot
                }
            }
            Behavior on fill { ColorAnimation { duration: root.animDuration } }

            Item {
                id: bodyHolder
                anchors.fill: parent
            }
        }
    }
}
