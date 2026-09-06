pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for the whole shell. Nothing below this file should
// contain a literal colour, radius, duration or easing curve.
Item {
    id: theme

    // ---------------------------------------------------------------- mode --
    property string mode: "dark"
    readonly property bool light: mode === "light"

    // --------------------------------------------------------------- notch --
    // The centre island has two shapes, toggled by SUPER+SHIFT+N through the
    // `notch` IPC target.
    //
    //   false — dynamic island. Frosted glass floating Theme.screenMargin below
    //           the top edge, rounded on all four corners. The default, and
    //           unchanged from what it has always been.
    //   true  — notch. Opaque black, flush with the top edge, square where it
    //           meets that edge and rounded only where it leaves it, so it
    //           reads as a bite taken out of the screen rather than as a bar.
    //
    // All three islands follow, so the top of the screen is one row of notches
    // or one row of floating islands, never a mix. They keep their horizontal
    // margins in both modes: a notch flush into a screen corner would have no
    // room for its outer flare.
    property bool notch: false

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/theme-mode"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: theme.mode = text().trim() === "light" ? "light" : "dark"
        onFileChanged: reload()
    }

    // --------------------------------------------------------------- glass --
    // Frost level. The compositor draws the blur behind the surface; these
    // alphas are only the tint on top of it. Push them toward 1.0 and the blur
    // disappears under an opaque plate, which is exactly what we do not want.
    property real glassAlphaBar: 0.42     // the three islands
    property real glassAlphaPopup: 0.55   // popups carry more text, tint harder

    readonly property color glassBar: light
        ? Qt.rgba(0.96, 0.96, 0.97, glassAlphaBar)
        : Qt.rgba(0.05, 0.05, 0.06, glassAlphaBar)
    readonly property color glassPopup: light
        ? Qt.rgba(0.97, 0.97, 0.98, glassAlphaPopup)
        : Qt.rgba(0.06, 0.06, 0.07, glassAlphaPopup)

    // Edge treatment. See components/GlassSurface.qml for how these combine.
    readonly property color rim: light ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.18)
    readonly property color rimTop: light ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.30)
    readonly property color rimBottom: light ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0, 0, 0, 0.28)
    readonly property color sheen: light ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.05)
    // The one switch for every island's and popup's drop shadow. Off: the glass
    // reads as a flat pane sitting on the wallpaper rather than a slab hovering
    // over it, and nothing bleeds out from under the bar's bottom edge.
    //
    // shadowRadius and shadowOffset stay meaningful either way — HoverPopup
    // sizes its surface with them, so the numbers still describe how much room
    // a shadow would need, they just are not spent while this is false.
    property bool shadowsEnabled: false

    readonly property color shadow: Qt.rgba(0, 0, 0, light ? 0.18 : 0.45)
    readonly property int shadowRadius: 28
    readonly property int shadowOffset: 6

    // Inner surfaces (tiles, sliders, art wells) sitting on top of glass.
    readonly property color fillWeak: light ? Qt.rgba(0, 0, 0, 0.05) : Qt.rgba(1, 1, 1, 0.06)
    readonly property color fillMid: light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.10)
    readonly property color fillStrong: light ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color fillHover: light ? Qt.rgba(0, 0, 0, 0.11) : Qt.rgba(1, 1, 1, 0.13)

    // Toggle tiles: off = dark glass + coloured icon, on = inverted.
    readonly property color toggleOff: light ? Qt.rgba(0, 0, 0, 0.07) : Qt.rgba(1, 1, 1, 0.09)
    readonly property color toggleOn: light ? Qt.rgba(0.12, 0.12, 0.14, 0.92) : Qt.rgba(1, 1, 1, 0.94)
    readonly property color toggleOnIcon: light ? "#FFFFFF" : "#101014"

    // ----------------------------------------------------------- typography --
    readonly property color text: light ? "#14161F" : "#ECEFF7"
    readonly property color textDim: light ? "#4C5162" : "#A8AFC2"
    readonly property color textFaint: light ? "#767C90" : "#767C90"
    readonly property color textOnGlow: light ? "#14161F" : "#FFFFFF"

    // Centre-island palette. Everything drawn *inside* the centre bar reads
    // these instead of the plain text tokens, because that bar is the one
    // surface whose background is not glass in both modes: on the notch's solid
    // black, the dark-mode text colours are near invisible and the light-mode
    // ones are unreadable outright, so the neutrals go white and the greys
    // become alpha-white steps that keep the same relative weighting.
    //
    // The semantic colours — wifi, bluetooth, accent, danger — deliberately do
    // NOT switch. They carry meaning ("connected", "armed") rather than being
    // text, and they already read on black; flattening them to white would cost
    // the state at a glance for no gain.
    readonly property color notchFill: "#000000"
    readonly property color barText: notch ? "#FFFFFF" : text
    readonly property color barTextDim: notch ? Qt.rgba(1, 1, 1, 0.72) : textDim
    readonly property color barTextFaint: notch ? Qt.rgba(1, 1, 1, 0.38) : textFaint
    readonly property color barFillHover: notch ? Qt.rgba(1, 1, 1, 0.16) : fillHover

    // Two families, on purpose:
    //
    //   fontUI    — Inter, for everything the user reads as words or numbers.
    //   fontIcons — the Nerd Font, for the glyph icons (battery, wifi, media
    //               transport, …). Inter has no Private Use Area glyphs, so
    //               anything drawn from a Nerd codepoint MUST stay on this
    //               family or it renders as tofu.
    //
    // Qt silently substitutes a missing family via fontconfig and still reports
    // the name you asked for, so `font.family` is useless as an availability
    // check. Qt.fontFamilies() is the real one — if Inter is not installed the
    // shell falls back to the previous font instead of landing on whatever
    // fontconfig happens to pick.
    readonly property string fontIcons: "JetBrainsMono Nerd Font"
    readonly property bool hasInter: Qt.fontFamilies().indexOf("Inter") !== -1
    readonly property string fontUI: hasInter ? "Inter" : fontIcons

    // Inter's default figures are proportional, so a clock ticking 1 -> 2 would
    // visibly reflow. `tnum` selects the tabular (fixed-width) figure set, which
    // is what a monospaced font gave us for free before. Applied to the clock,
    // the workspace numerals, and the media timecodes — anywhere digits change
    // in place. Harmless on the fallback font.
    readonly property var tabularFigures: ({ "tnum": 1 })


    // Every text size in the shell is a multiple of this one number — change it
    // and the whole bar rescales together.
    property real fontSizeBase: 16

    function fontSize(mult) { return Math.max(1, Math.round(fontSizeBase * mult)) }

    // Bar typography.
    readonly property int fontSizeBar: fontSize(0.95)          // clock, pill text
    readonly property int fontSizeTitle: fontSize(1.0)         // focused window
    readonly property int iconSizeBar: fontSize(1.0)           // icon cluster
    readonly property int iconSizeBarSmall: fontSize(0.9)

    // Visible diameter of a cluster button's hover circle, and the invisible
    // ring of extra hit area around it. The circle stays small enough to read
    // as an icon rather than a chip; the padding is what makes the target
    // comfortable to hit, so aiming between two adjacent glyphs stops being a
    // precision exercise. Kept here rather than inline because the two plain
    // (circle-less) controls in the cluster — the control centre and the power
    // glyph — have to size their hit areas to the same number.
    readonly property int barButtonSize: iconSizeBar + 14
    readonly property int barHitPadding: 6
    readonly property int barHitSize: barButtonSize + barHitPadding * 2

    // Workspace numerals. The active/inactive ratio is preserved from the
    // original 19/12 pair (~1.58) — the pair is just larger overall now.
    readonly property int fontSizeWorkspace: fontSize(1.0)
    readonly property int fontSizeWorkspaceActive: fontSize(1.58)

    // Popup typography. The multipliers are chosen to reproduce the sizes the
    // popups already render at, so raising fontSizeBase scales them too without
    // shifting anything today.
    readonly property int fontSizeXs: fontSize(0.63)           // 10
    readonly property int fontSizeSm: fontSize(0.69)           // 11
    readonly property int fontSizeMd: fontSize(0.75)           // 12
    readonly property int fontSizeLg: fontSize(0.81)           // 13
    readonly property int fontSizeXl: fontSize(0.88)           // 14

    // ------------------------------------------------------------- accents --
    readonly property color accent: "#7AA2F7"
    readonly property color accentAlt: "#BB9AF7"
    readonly property color success: "#9ECE6A"
    readonly property color warning: "#E0AF68"
    readonly property color danger: "#F7768E"
    readonly property color wifi: "#3B9DFF"
    readonly property color bluetooth: "#3B9DFF"

    // Destructive-action tints for the power island. The hover tint is the same
    // idea as fillHover, red-shifted so shut down never reads as just another
    // button; the confirm tint is the armed state, deliberately much stronger
    // so an armed button cannot be mistaken for a hovered one.
    readonly property color dangerHover: alpha(danger, 0.22)
    readonly property color dangerConfirm: alpha(danger, 0.42)

    // -------------------------------------------------------- power actions --
    // The four commands the power island runs, kept here so they can be edited
    // without touching the component. Each string is handed to `sh -c`, so the
    // usual shell syntax works — pipes, arguments, a script path, anything.
    property string cmdLock: "hyprlock"
    property string cmdSleep: "systemctl suspend"
    property string cmdLogOut: "hyprctl dispatch exit"
    property string cmdShutDown: "systemctl poweroff"

    // How long a destructive button stays armed after its first click. A second
    // click inside this window commits; otherwise the button reverts.
    readonly property int powerConfirmMs: 3000

    // Gap between each action icon's reveal as the pill opens, left to right.
    readonly property int powerStagger: 30

    // -------------------------------------------------------------- shapes --
    readonly property int radiusIsland: 12
    readonly property int radiusPopup: 16
    // The notch's lower corners. Larger than radiusIsland on purpose: the
    // shape has only two rounded corners instead of four, so it needs more
    // curve on each to carry the same softness.
    readonly property int radiusNotch: 18

    // The notch's upper corners, which bend the other way — see topFlare in
    // components/GlassSurface.qml. Capped by the centre island's `pad` (20),
    // which is the only slack there is to either side of the bar's glass; go
    // past it and the flare is cut off at the surface boundary.
    readonly property int radiusNotchFlare: 16
    readonly property int radiusTile: 14
    readonly property int radiusSmall: 8
    readonly property int radiusArt: 6

    // Single source of truth for island height. All three islands derive from
    // it, so they share one height and one vertical centre line: the media pill
    // and the centre bar are exactly this tall, and the right-hand island is a
    // circle of this diameter.
    readonly property int barHeight: 46
    readonly property int circleSize: barHeight
    readonly property int screenMargin: 8
    readonly property int islandGap: 10

    // Where an island's glass sits relative to the top of the screen: a notch
    // is flush with it, an island floats below. The corner and colour half of
    // the mode lives in GlassSurface.followsNotch — only the offset has to be
    // out here, because it is the island's *window* that has to leave room for
    // it, not the surface.
    readonly property int barTopMargin: notch ? 0 : screenMargin

    // ------------------------------------------------------- notifications --
    // How long a normal notification holds the island. Low urgency gets less,
    // critical never expires at all — see Notif.arm().
    readonly property int notifTimeout: 6000
    readonly property int notifTimeoutLow: 3500

    // The island's expanded height is barHeight + this. Actions and an inline
    // reply field are extra rows on top, added only when the notification
    // carries them, so a plain notification does not pay for the space.
    // The notification island, in the run between the centre bar and the app
    // circle. Two sizes: a pill at rest, a card under the pointer.
    //
    // The pill is wide enough for an icon, a line of summary and a count, and
    // no wider — at rest it is a status light, not a reader. The card is what
    // you actually read, so it gets the width of a message bubble.
    readonly property int notifPillWidth: 250
    readonly property int notifCardWidth: 400

    // Rows inside the expanded card.
    readonly property int notifBody: 54         // summary + body block
    readonly property int notifActions: 40
    readonly property int notifReply: 42
    readonly property int notifQueueRow: 46     // one waiting notification
    readonly property int notifQueueMax: 4      // beyond this, a "+n more" line

    readonly property int notifIcon: 28
    readonly property int notifIconCard: 34
    readonly property color notifCritical: light ? "#C0392B" : "#FF6B5B"

    // Centre island layout. The title needs real width — it carries a marquee.
    readonly property int titleWidth: 340
    readonly property int islandPadding: 16     // inset at the island's ends
    readonly property int sectionSpacing: 20    // between carousel/title/icons/clock

    // Pill and bar inner padding, proportional to barHeight so contents stay
    // optically centred instead of floating in a taller box.
    readonly property int innerPadding: Math.round(barHeight * 0.15)

    // Space reserved at the top of the screen, so tiled windows start *below*
    // the islands instead of underneath them. Measured from the screen edge to
    // the bottom of the lowest island. Hyprland's own gaps_out adds the visual
    // breathing room below this line, so it is not padded here.
    //
    // The two modes reserve different amounts, because notches are flush with
    // the top edge and islands hang screenMargin below it. Both are one island
    // height; the island mode just starts lower down.
    //
    // IMPORTANT: exactly one surface may claim this. Layer-shell sums the
    // exclusive zones of every surface on an edge, so if all three islands
    // claimed it the usable area would be pushed down three times. BarIsland is
    // the claimant; the other two stay on ExclusionMode.Ignore.
    readonly property int exclusiveZone: barTopMargin + circleSize

    // ---------------------------------------------------------- animation ---
    // Opens overshoot and settle; closes are quicker and never overshoot.
    readonly property int durOpen: 220
    readonly property int durClose: 140
    readonly property int durHover: 130
    readonly property int durSlide: 340   // workspace strip travel

    // Marquee scroll rate in px/sec, not a duration — so a long title and a
    // short one travel at the same speed.
    readonly property int marqueeSpeed: 34
    readonly property int marqueePause: 2000   // hold before each cycle starts
    readonly property int durColor: 520   // album-art derived colour crossfade

    // The island <-> notch morph. Slower than durOpen because it is a change of
    // shape, not a reveal: the corners unwind and the slab slides up to meet the
    // screen edge, and at popup speed that reads as a snap rather than a morph.
    readonly property int durMode: 340
    readonly property int closeDelay: 200 // grace period after the cursor leaves
    readonly property int idleDismiss: 5000 // click-opened panels close after this
                                            // long with no pointer movement

    readonly property int easeOpen: Easing.OutBack
    readonly property real easeOpenOvershoot: 1.35
    readonly property int easeClose: Easing.OutCubic
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeSlide: Easing.OutBack
    readonly property real easeSlideOvershoot: 1.10

    // -------------------------------------------------------- launcher swap --
    // The bar retracts into the top edge while the Vicinae launcher is open,
    // because the launcher is positioned over exactly where the islands sit
    // (see ~/.config/hypr/config/windows.lua). Set this false to leave the bar
    // where it is and let the launcher overlap it — the detection in
    // services/Hypr.qml keeps running either way, nothing else changes.
    readonly property bool launcherHideEnabled: true

    // Out accelerates and never overshoots: leaving. In overshoots slightly and
    // settles, the same curve family the popups open on.
    readonly property int durLauncherOut: 180
    readonly property int durLauncherIn: 240
    readonly property int easeLauncherOut: Easing.InCubic
    readonly property int easeLauncherIn: Easing.OutBack
    readonly property real easeLauncherOvershoot: 1.20

    // Gap between the centre island and the other three. Small enough that the
    // four still read as one gesture rather than a sequence.
    readonly property int launcherStagger: 40

    // How far an island travels on its way out, as a fraction of its own
    // height — it retracts into the screen edge rather than flying off it.
    readonly property real launcherRetract: 0.5
    readonly property real launcherScale: 0.92

    // Backstop. If Vicinae is killed or crashes while open its close event
    // never arrives, and without this the bar would stay hidden for the life of
    // the session.
    readonly property int launcherSafetyMs: 60000

    // ----------------------------------------------------------- helpers ----
    // Both accept either a color or a "#rrggbb" string.
    function alpha(c, a) {
        const k = Qt.color(c)
        return Qt.rgba(k.r, k.g, k.b, a)
    }
    function mix(from, to, t) {
        const a = Qt.color(from)
        const b = Qt.color(to)
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t)
    }
}
