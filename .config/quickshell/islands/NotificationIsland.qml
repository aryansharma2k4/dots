import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

/*
 * NOTIFICATION ISLAND — a pill in the run between the centre bar and the app
 * circle. At rest it is a status light: icon, one line, a count. Under the
 * pointer it becomes the thing you actually read.
 *
 * ── WHY IT GROWS RATHER THAN OPENING A POPUP ───────────────────────────────
 *
 * Every other panel in this shell is a HoverPopup hanging below its trigger,
 * and this deliberately is not one. A notification is not a detail view of the
 * pill — it IS the pill, with more of itself showing. Growing in place keeps
 * that identity: one object, one surface, changing shape. A popup would read as
 * a second thing appearing next to a first, which is exactly the "toast beside
 * an unchanged bar" this is meant to replace.
 *
 * ── ANCHORING ──────────────────────────────────────────────────────────────
 *
 * The window is the size of the *expanded* card and never resizes; the surface
 * inside it is right-aligned and animates its own width and height. So the pill
 * grows leftward and downward from a fixed right edge — it stays pinned beside
 * the app circle instead of sliding around as its content changes, and the
 * compositor is never asked to renegotiate surface geometry mid-animation.
 */
Scope {
    id: root

    readonly property int pad: 20

    // Everything on screen right now: the one being read, then the queue.
    readonly property var notif: Notif.current
    readonly property var queue: Notif.overflow
    readonly property bool present: notif !== null

    // Hover, plus a grace period on the way out. Without the delay, crossing a
    // button's edge or the gap between two queue rows would collapse the card
    // out from under the pointer mid-reach.
    property bool pointerOver: false
    property bool stillOpen: false

    // Held open by keybind rather than by the pointer — SUPER+N, through the
    // `notif` IPC target. Reaching for the mouse to read a message you were
    // already told about is the thing a notification is supposed to save you.
    property bool pinned: false

    readonly property bool expanded: present && (stillOpen || pinned)

    function togglePinned() { root.pinned = !root.pinned }
    function unpin() { root.pinned = false }

    onPointerOverChanged: {
        if (pointerOver) {
            collapseTimer.stop()
            root.stillOpen = true
        } else {
            collapseTimer.restart()
        }
    }

    Timer {
        id: collapseTimer
        interval: Theme.closeDelay
        onTriggered: if (!root.pointerOver) root.stillOpen = false
    }

    // Nothing left to stay open for.
    onPresentChanged: {
        if (!present) {
            root.stillOpen = false
            root.pinned = false
        }
    }

    // Holding the pointer over the island holds every countdown, so a
    // notification cannot expire out from under you mid-read or mid-reply.
    Binding {
        target: Notif
        property: "held"
        value: root.expanded
    }

    // ---- geometry ---------------------------------------------------------------
    readonly property int cardWidth: expanded ? Theme.notifCardWidth : Theme.notifPillWidth
    readonly property int queueShown: Math.min(queue.length, Theme.notifQueueMax)
    readonly property int queueHeight: expanded && queue.length > 0
        ? queueShown * Theme.notifQueueRow
          + 20                                    // the "+n more" / "Clear all" row
          + 10                                    // the divider's breathing room
        : 0
    readonly property int cardHeight: Math.max(
        Theme.barHeight,
        Theme.innerPadding * 2 + view.implicitHeight + queueHeight)

    // What the SURFACE is sized to, as opposed to what the pill is drawn at.
    //
    // The two differ only during the expand/collapse animation, and that gap is
    // the whole point. `cardHeight` steps the instant the mode flips; the pill
    // then animates toward it. If the surface followed the pill it would
    // renegotiate layer-shell geometry with the compositor on every frame,
    // which is what made the expansion stutter; if it followed `cardHeight`
    // directly it would snap smaller at the *start* of a collapse and clip the
    // pill on its way down.
    //
    // So: grow ahead of the animation, shrink after it. Two resizes per cycle,
    // and the surface is never bigger than the card actually needs.
    property int surfaceHeight: Theme.barHeight

    onCardHeightChanged: {
        if (cardHeight >= surfaceHeight) {
            shrinkTimer.stop()
            surfaceHeight = cardHeight
        } else {
            shrinkTimer.restart()
        }
    }

    Timer {
        id: shrinkTimer
        interval: Theme.durOpen + 80
        onTriggered: root.surfaceHeight = root.cardHeight
    }

    PanelWindow {
        id: window

        anchors { top: true; right: true }
        // Left of the app circle by one island gap. Pinned; the pill moves
        // inside — see BarIsland for why a layer margin is never animated.
        margins.top: -root.pad
        margins.right: Theme.screenMargin + Theme.circleSize + Theme.islandGap - root.pad

        // Always the expanded width — the pill grows leftward inside it — and a
        // height that leads the growth and trails the collapse. See
        // root.surfaceHeight: the surface must never resize mid-animation.
        implicitWidth: Theme.notifCardWidth + root.pad * 2
        implicitHeight: root.pad * 2 + Theme.screenMargin + root.surfaceHeight

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // Unmapped entirely when there is nothing to show, not merely masked or
        // faded. The `quickshell-bar` namespace carries a backdrop-blur
        // layerrule, so a mapped surface costs a blur pass on every compositor
        // frame whether or not anything is painted into it — an idle cost for a
        // thing that is idle almost all of the time.
        //
        // Held open while the exit animation finishes, so the pill still gets
        // to leave rather than blinking out.
        visible: root.present || pill.opacity > 0.01

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top

        // Only ever focusable while a reply field is on screen, and then only
        // OnDemand: focus arrives by clicking the field, and nothing is taken
        // from the focused window just because a message came in.
        WlrLayershell.keyboardFocus: root.expanded && root.notif !== null
                                     && root.notif.hasInlineReply === true
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: root.present ? pillMask : emptyMask
        Region { id: pillMask; item: pill }
        Region { id: emptyMask }

        GlassSurface {
            id: pill

            // Right-aligned: the pill grows leftward from a fixed edge.
            x: window.width - root.pad - width
            y: root.pad + Theme.barTopMargin
            width: root.cardWidth
            height: root.cardHeight
            radius: Theme.radiusIsland
            followsNotch: true

            // Arrival: it drops in from under the top edge and scales up from
            // nothing, so a notification announces itself with movement rather
            // than by materialising fully formed.
            opacity: root.present ? 1 : 0
            scale: root.present ? 1 : 0.88
            transformOrigin: Item.TopRight
            visible: opacity > 0.01

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durOpen
                    easing.type: Theme.easeOpen
                    easing.overshoot: Theme.easeOpenOvershoot
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: Theme.durOpen
                    easing.type: Theme.easeOpen
                    easing.overshoot: Theme.easeOpenOvershoot
                }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.durOpen } }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durOpen
                    easing.type: Theme.easeOpen
                    easing.overshoot: Theme.easeOpenOvershoot
                }
            }
            Behavior on y {
                NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard }
            }

            HoverHandler {
                onHoveredChanged: root.pointerOver = hovered
            }

            // Everything inside is laid out at its final size the instant the
            // mode flips — only the pill animates — so it has to be clipped to
            // the pill while the pill is still on its way there.
            Item {
                id: body
                anchors.fill: parent
                clip: true

            // ---- the notification being read --------------------------------
            NotificationView {
                id: view
                notif: root.notif
                expanded: root.expanded
                anchors {
                    top: parent.top
                    topMargin: Theme.innerPadding
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.innerPadding + 4
                    rightMargin: Theme.innerPadding + 4
                }

                onDismissed: Notif.dismiss(root.notif)
                onReplySubmitted: text => {
                    Notif.reply(root.notif, text)
                    clearReply()
                }
            }

            // ---- the queue ---------------------------------------------------
            Rectangle {
                id: divider
                anchors {
                    top: view.bottom
                    topMargin: 5
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.innerPadding + 4
                    rightMargin: Theme.innerPadding + 4
                }
                height: 1
                color: Theme.rim
                opacity: root.queueHeight > 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durOpen } }
            }

            Column {
                id: queueColumn
                anchors {
                    top: divider.bottom
                    topMargin: 4
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.innerPadding + 4
                    rightMargin: Theme.innerPadding + 4
                }
                opacity: root.queueHeight > 0 ? 1 : 0
                visible: opacity > 0.01
                clip: true

                Behavior on opacity { NumberAnimation { duration: Theme.durOpen } }

                Repeater {
                    // Built whenever there is a queue, not when the card opens.
                    // Instantiating four delegates — each with an icon and an
                    // image load — on the first frame of the expansion is a
                    // guaranteed dropped frame right where it shows most.
                    model: root.queue.slice(0, Theme.notifQueueMax)

                    NotificationRow {
                        required property var modelData
                        width: queueColumn.width
                        notif: modelData
                        // Clicking a waiting one promotes it: it becomes the one
                        // being read, and the current one falls into the queue.
                        onActivated: Notif.promote(modelData)
                        onDismissed: Notif.dismiss(modelData)
                    }
                }

                // The tail: how many are not listed, and the way out of all of
                // them. Past notifQueueMax the card stops growing and counts
                // instead, so a burst cannot paper the screen.
                Item {
                    width: parent.width
                    height: visible ? 20 : 0
                    visible: root.queue.length > 0

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.queue.length > Theme.notifQueueMax
                        text: "+" + (root.queue.length - Theme.notifQueueMax) + " more"
                        font.family: Theme.fontUI
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                        color: Theme.textFaint
                    }

                    Text {
                        id: clearAll
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear all"
                        font.family: Theme.fontUI
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: Font.DemiBold
                        color: clearArea.containsMouse ? Theme.accent : Theme.textFaint

                        Behavior on color { ColorAnimation { duration: Theme.durHover } }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -8
                            hoverEnabled: true
                            onClicked: Notif.dismissAll()
                        }
                    }
                }
            }
            }
        }
    }
}
