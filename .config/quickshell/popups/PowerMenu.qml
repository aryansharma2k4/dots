import QtQuick
import Quickshell
import ".."
import "../components"

/*
 * The four session actions, in a pill under the bar's power glyph.
 *
 * This used to be a fifth island that grew sideways out of its own circle. It
 * is a popup now for one reason: the power button belongs in the icon cluster
 * with the other status controls, and once the button lives inside the centre
 * island there is nothing left out on the bar for a pill to grow out of. So it
 * hangs from the icon the way the control centre does, and inherits everything
 * HoverPopup already solves — the hover bridge across the gap, click-outside to
 * dismiss, the keyboard grab that makes Escape work, and the idle timeout.
 *
 * Shaped as a stadium rather than a card (popupRadius is half its height) so it
 * reads as one of the bar's pills that happens to be hanging below the bar,
 * rather than as a panel.
 *
 * CONFIRMATION lives in PowerAction, not here: log out and shut down arm on the
 * first click and only fire on the second. This file only has to make sure that
 * arming one disarms the other, so two buttons are never waiting at once.
 */
HoverPopup {
    id: root

    readonly property int diameter: Theme.circleSize
    readonly property int gap: Theme.innerPadding

    contentWidth: Theme.innerPadding * 2 + diameter * 4 + gap * 3
    contentHeight: Theme.barHeight
    popupRadius: contentHeight / 2

    // Hangs off the centre island, so it goes when the centre island retracts
    // for the launcher.
    hidesWithLauncher: true
    anchorAlign: "center"

    // Fire an action. The pill closes first so the surface is gone before
    // hyprlock (or the logout tear-down) paints over the screen.
    function run(command) {
        root.dismiss()
        const cmd = (command || "").trim()
        if (cmd !== "")
            Quickshell.execDetached(["sh", "-c", cmd])
    }

    // Only one action may be waiting for its second click; arming one clears
    // whichever was armed before.
    function disarmOthers(keep) {
        for (let i = 0; i < actions.children.length; i++) {
            const child = actions.children[i]
            if (child !== keep && child.disarm)
                child.disarm()
        }
    }

    Row {
        id: actions
        anchors.centerIn: parent
        spacing: root.gap

        PowerAction {
            glyph: "lock"
            diameter: root.diameter
            revealed: root.active
            revealDelay: 0
            onActivated: root.run(Theme.cmdLock)
            onArmed: root.disarmOthers(this)
        }

        PowerAction {
            glyph: "sleep"
            diameter: root.diameter
            revealed: root.active
            revealDelay: Theme.powerStagger
            onActivated: root.run(Theme.cmdSleep)
            onArmed: root.disarmOthers(this)
        }

        PowerAction {
            glyph: "logout"
            diameter: root.diameter
            revealed: root.active
            revealDelay: Theme.powerStagger * 2
            requiresConfirm: true
            onActivated: root.run(Theme.cmdLogOut)
            onArmed: root.disarmOthers(this)
        }

        PowerAction {
            glyph: "power"
            diameter: root.diameter
            revealed: root.active
            revealDelay: Theme.powerStagger * 3
            requiresConfirm: true
            dangerous: true
            onActivated: root.run(Theme.cmdShutDown)
            onArmed: root.disarmOthers(this)
        }
    }
}
