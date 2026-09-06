import QtQuick
import ".."
import "../services"

/*
 * The bar's half of the launcher swap: one island's retract-into-the-top-edge
 * gesture, and the single boolean that says whether it should be retracted.
 *
 * Instantiate one per island and drive the island's surface from it:
 *
 *     IslandRetract { id: retract; travel: pill.height }
 *
 *     GlassSurface {
 *         opacity: retract.fade
 *         transform: [
 *             Scale { origin.x: pill.width / 2; xScale: retract.zoom; yScale: retract.zoom },
 *             Translate { y: retract.offsetY }
 *         ]
 *     }
 *
 * The transform is spelled out at each island rather than handed over as a
 * list: QML has no usable `Transform` base type to put in a property, and the
 * two nodes have to be built where the item's own width is in scope anyway.
 * Scaling about the top edge (origin.y stays 0) is what makes the island look
 * pulled into the screen edge instead of shrinking toward its own middle, and
 * keeping this out of the `scale` property lets it compose with AppIsland's
 * existing press and hover scaling rather than fight it for the same property.
 *
 * ONE VALUE, THREE EFFECTS. Fade, scale and travel are all derived from a
 * single animated number, `shown`. They therefore cannot drift apart or run on
 * different curves — the four islands read as one motion because every one of
 * them is driven by the same shape of the same easing, and each island's three
 * properties are three views of one value rather than three animations that
 * happen to have been given matching durations.
 *
 * DIRECTION. Out is quick and accelerating (InCubic): things that are leaving
 * should look like they are leaving. In is slower and overshoots slightly
 * (OutBack), so the islands settle rather than stop dead — the same curve the
 * popups already open on.
 *
 * STAGGER. Only the two islands the launcher actually lands on top of retract
 * — the centre bar and the power pill. The music pill on the far left and the
 * app circle on the far right are clear of it and stay put, so the launcher
 * appears to open *into* a gap in the bar rather than replacing the whole
 * thing. The centre leads on the way out and trails on the way in: the pair
 * collapses from the middle and refills toward it, which reads as one gesture
 * rather than two things taking turns.
 *
 * RETARGETING. The delay lives inside the Behavior, so mashing the hotkey never
 * queues: each new value replaces the animation in flight from wherever it had
 * got to, and a Behavior always finishes on the value last assigned. An island
 * can be caught halfway out and sent back without ever being stranded.
 */
QtObject {
    id: root

    // Geometry of the island being driven. `travel` is its height — the
    // distance moved is a fraction of it, so a tall pill and a small circle
    // retract by proportionate amounts and arrive together.
    property real travel: Theme.barHeight

    // The centre island. Leads out, trails in.
    property bool centre: false

    readonly property bool hidden: Theme.launcherHideEnabled && Hypr.launcherOpen

    // 1 = fully present, 0 = fully retracted. Overshoots past 1 on the way in.
    property real shown: hidden ? 0.0 : 1.0

    readonly property real fade: Math.max(0, Math.min(1, shown))
    readonly property real zoom: Theme.launcherScale + (1 - Theme.launcherScale) * shown
    readonly property real offsetY: -travel * Theme.launcherRetract * (1 - shown)

    // Input is surrendered the moment the retract starts and taken back the
    // moment the return starts, rather than at either animation's end: a
    // half-faded island must not be clickable, and one on its way back should
    // not stay dead until it has finished settling.
    readonly property bool interactive: !hidden

    Behavior on shown {
        SequentialAnimation {
            PauseAnimation {
                duration: root.hidden
                    ? (root.centre ? 0 : Theme.launcherStagger)
                    : (root.centre ? Theme.launcherStagger : 0)
            }
            NumberAnimation {
                duration: root.hidden ? Theme.durLauncherOut : Theme.durLauncherIn
                easing.type: root.hidden ? Theme.easeLauncherOut : Theme.easeLauncherIn
                easing.overshoot: Theme.easeLauncherOvershoot
            }
        }
    }
}
