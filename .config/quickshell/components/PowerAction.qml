import QtQuick
import ".."

/*
 * One circular button inside the power pill.
 *
 * Hover treatment matches the control-center tiles: the fill lightens and the
 * circle scales up slightly, both animated, never snapped. `dangerous` swaps
 * the hover tint for a red-shifted one so shut down is visibly not just another
 * button in the row.
 *
 * CONFIRMATION. When `requiresConfirm` is set, the first click does not fire —
 * it arms the button, which turns red-tinted and holds for Theme.powerConfirmMs
 * before reverting on its own. A second click while armed is what actually
 * emits `activated()`. The arming is owned here rather than by the island so
 * the visual state and the state that gates the click can never disagree.
 *
 * REVEAL. `revealed` drives the fade-and-scale entrance, delayed by
 * `revealDelay` so a row of these can be staggered. The delay applies only on
 * the way in: on the way out they all go together, which is what makes the
 * close read as faster than the open.
 */
Item {
    id: root

    property string glyph: "power"
    property int diameter: Theme.circleSize
    property int glyphSize: Math.round(diameter * 0.42)
    property bool dangerous: false
    property bool requiresConfirm: false

    property bool revealed: false
    property int revealDelay: 0

    readonly property bool confirming: confirmTimer.running

    signal activated()

    // Emitted on the first click of a two-click action, so the island can
    // disarm any other button that was already waiting for its second click.
    signal armed()

    function disarm() { confirmTimer.stop() }

    implicitWidth: diameter
    implicitHeight: diameter

    opacity: revealed ? 1 : 0
    scale: revealed ? 1 : 0.72
    transformOrigin: Item.Center

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.revealed ? root.revealDelay : 0 }
            NumberAnimation {
                duration: root.revealed ? Theme.durOpen : Theme.durClose
                easing.type: root.revealed ? Theme.easeStandard : Theme.easeClose
            }
        }
    }

    Behavior on scale {
        SequentialAnimation {
            PauseAnimation { duration: root.revealed ? root.revealDelay : 0 }
            NumberAnimation {
                duration: root.revealed ? Theme.durOpen : Theme.durClose
                easing.type: root.revealed ? Theme.easeOpen : Theme.easeClose
                easing.overshoot: Theme.easeOpenOvershoot
            }
        }
    }

    // A button that is fading out must not still be clickable, and one that has
    // not arrived yet must not be either.
    readonly property bool interactive: revealed && opacity > 0.9

    readonly property color fillColor: {
        if (root.confirming)
            return Theme.dangerConfirm
        if (area.containsMouse)
            return root.dangerous ? Theme.dangerHover : Theme.fillHover
        return Theme.toggleOff
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: width / 2
        color: root.fillColor
        antialiasing: true
        // Press dips below the resting size; hover lifts slightly above it.
        scale: area.pressed ? 0.92 : (area.containsMouse ? 1.07 : 1.0)

        Behavior on color { ColorAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
        Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }

        // Faint rim, so a resting button still reads as a surface on the glass.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.confirming ? Theme.alpha(Theme.danger, 0.55) : Theme.rim
            antialiasing: true

            Behavior on border.color { ColorAnimation { duration: Theme.durHover } }
        }

        PowerGlyph {
            anchors.centerIn: parent
            size: root.glyphSize
            glyph: root.glyph
            color: root.confirming ? Theme.text
                 : root.dangerous && area.containsMouse ? Theme.danger
                 : Theme.text
        }
    }

    // The armed window. Running is the armed state — see `confirming` above.
    Timer {
        id: confirmTimer
        interval: Theme.powerConfirmMs
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        onClicked: {
            if (root.requiresConfirm && !confirmTimer.running) {
                confirmTimer.restart()
                root.armed()
                return
            }
            confirmTimer.stop()
            root.activated()
        }
    }

    // Nothing should stay armed once the pill is on its way out.
    onRevealedChanged: if (!revealed) confirmTimer.stop()
}
