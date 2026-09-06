import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."
import "../components"
import "../services"

/*
 * The media card that grows out of the left island on hover.
 *
 * THE SIGNATURE EFFECT — album-art derived border and glow.
 *
 * services/Media.qml runs scripts/albumcolors.py on every track change and
 * publishes three colours: `primary` and `secondary` (the two ends of the
 * gradient border) and `glow` (a brighter, more saturated version driving the
 * outer bloom). The extraction itself is documented in that python file.
 *
 * Here they are turned into light, in three stacked pieces:
 *
 *   1. GLOW      A rounded rect in `glow`, sitting *behind* the card, inflated
 *                past its bounds and heavily blurred. Because it is behind the
 *                glass and larger than it, only the bleed around the edge shows
 *                — which is what an emitted glow looks like.
 *   2. BORDER    A ~2px gradient rim running primary -> secondary -> primary on
 *                the diagonal. Drawn as a filled gradient rect with the card's
 *                interior punched out by a second rect, because a Rectangle's
 *                `border` takes a flat colour and cannot be a gradient.
 *   3. TINT      A barely-there wash of `primary` over the glass fill, so the
 *                card body picks up the cover's cast instead of the border
 *                floating on neutral grey.
 *
 * Every one of those colours has a Behavior with Theme.durColor, so a track
 * change crossfades the whole card's lighting over ~half a second rather than
 * cutting. That crossfade is the effect; without it the border just blinks.
 */
Item {
    id: root

    // Animated copies of the service's colours. Binding the visuals to these
    // rather than to Media.* directly is what gives us one crossfade for the
    // whole card instead of three independent ones.
    property color primary: Media.primary
    property color secondary: Media.secondary
    property color glow: Media.glow

    Behavior on primary { ColorAnimation { duration: Theme.durColor; easing.type: Theme.easeStandard } }
    Behavior on secondary { ColorAnimation { duration: Theme.durColor; easing.type: Theme.easeStandard } }
    Behavior on glow { ColorAnimation { duration: Theme.durColor; easing.type: Theme.easeStandard } }

    property bool showGlow: true
    property int radius: Theme.radiusPopup

    signal sinkPickerRequested(int x)

    // ------------------------------------------------------------- 1 glow ---
    // The glow source is a RING, not a filled rect. The card's fill is
    // translucent by design, so a filled glow behind it shows straight through
    // and washes the whole card in the cover's colour instead of haloing it.
    // Blurring a hollow ring blooms outward from the edge and leaves the middle
    // clear, which is what an emitted glow actually looks like.
    //
    // The wrapper is inflated so the bloom has room to spread past the card
    // bounds rather than being clipped at the layer edge.
    Item {
        z: -2
        visible: root.showGlow && Media.available
        anchors.fill: parent
        anchors.margins: -glowSpread
        opacity: 0.85

        readonly property int glowSpread: 24

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 40
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.glowSpread
            radius: root.radius
            color: "transparent"
            border.width: 9
            border.color: root.glow
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: Theme.durColor } }
        }
    }

    // ----------------------------------------------------------- 2 border ---
    // A gradient-filled rect with its interior punched out, so the rim can run
    // primary -> secondary -> primary. A Rectangle's own `border` takes a flat
    // colour and cannot be a gradient, hence the cut-out.
    //
    // The cut-out is an OpacityMask, not an overdrawn rect: overdrawing would
    // put an opaque plate in the middle of the card and kill the frost. Note
    // this uses Qt5Compat's OpacityMask rather than MultiEffect's
    // maskEnabled/maskSource — the latter silently ignores the mask here.
    Item {
        anchors.fill: parent
        z: 1

        Rectangle {
            id: borderPaint
            anchors.fill: parent
            radius: root.radius
            antialiasing: true
            visible: false
            layer.enabled: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.primary }
                GradientStop { position: 0.5; color: root.secondary }
                GradientStop { position: 1.0; color: root.primary }
            }
        }

        // Opaque ring, transparent middle. A Rectangle's own border already
        // paints exactly that shape, so the mask is one rect — trying to punch
        // the hole by overdrawing a "transparent" rect on a white one does not
        // work, because drawing transparent paints nothing rather than erasing.
        Rectangle {
            id: borderMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            radius: root.radius
            color: "transparent"
            border.width: 2                      // border thickness
            border.color: "white"
            antialiasing: true
        }

        OpacityMask {
            anchors.fill: parent
            source: borderPaint
            maskSource: borderMask
        }
    }

    // ------------------------------------------------------------- 3 tint ---
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        // Just enough cast to tie the body to the border. Anything heavier and
        // the card stops reading as glass and starts reading as coloured card.
        color: Theme.alpha(root.primary, 0.055)
        antialiasing: true
        Behavior on color { ColorAnimation { duration: Theme.durColor } }
    }

    // ============================================================== content ==
    Item {
        anchors.fill: parent
        anchors.margins: 14

        // ---- art -----------------------------------------------------------
        Rectangle {
            id: artWell
            width: 52
            height: 52
            radius: 10
            color: Theme.fillMid
            clip: true

            Image {
                id: art
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            // Decoded at twice the size it is drawn, not at the source's own
            // resolution: an uncapped Image keeps a full pixmap of whatever the
            // player handed over — cover art is routinely 1000px square — to
            // fill a box a few dozen pixels wide.
            sourceSize.width: artWell.width * 2
                sourceSize.height: artWell.height * 2
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !art.visible
                text: "󰝚"
                font.family: Theme.fontIcons
                font.pixelSize: Theme.fontSize(1.38)
                color: Theme.textFaint
            }

            // The art picks up the same rim as the glass so it sits in the
            // surface rather than on it.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.rim, Theme.rim.a * 1.2)
            }
        }

        // ---- title / artist -------------------------------------------------
        Column {
            anchors.left: artWell.right
            anchors.leftMargin: 12
            anchors.right: wave.left
            anchors.rightMargin: 10
            anchors.top: artWell.top
            anchors.topMargin: 4
            spacing: 2

            MarqueeText {
                width: parent.width
                height: 17
                text: Media.title !== "" ? Media.title : "Nothing playing"
                pixelSize: Theme.fontSizeLg
                weight: Font.Bold
                color: Theme.text
                fadeWidth: 0.16
            }

            MarqueeText {
                width: parent.width
                height: 14
                text: Media.artist
                pixelSize: Theme.fontSizeSm
                color: Theme.textDim
                fadeWidth: 0.16
                visible: Media.artist !== ""
            }
        }

        // ---- waveform, top right --------------------------------------------
        WaveBars {
            id: wave
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 4
            bars: 5
            barWidth: 2
            barSpacing: 2
            maxHeight: 14
            // Tinted by the cover, like everything else on the card.
            color: Media.colorsResolved ? root.primary : Theme.textDim
        }

        // ---- scrub bar --------------------------------------------------------
        Item {
            id: scrub
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: artWell.bottom
            anchors.topMargin: 14
            height: 14

            readonly property real fraction: Media.length > 0
                ? Math.min(1, Math.max(0, Media.position / Media.length)) : 0
            // While dragging, the bar follows the cursor and the elapsed /
            // remaining labels follow the bar — so the numbers preview the seek
            // target before the player has been told about it.
            property bool dragging: false
            property real dragFraction: 0
            readonly property real shown: dragging ? dragFraction : fraction

            Text {
                id: elapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Media.formatTime(scrub.shown * Media.length)
                font.family: Theme.fontUI
                font.features: Theme.tabularFigures
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textDim
            }

            Text {
                id: remaining
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "-" + Media.formatTime(Math.max(0, Media.length - scrub.shown * Media.length))
                font.family: Theme.fontUI
                font.features: Theme.tabularFigures
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textDim
            }

            Item {
                id: barSlot
                anchors.left: elapsed.right
                anchors.right: remaining.left
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 14

                Rectangle {
                    id: barTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: scrubArea.containsMouse || scrub.dragging ? 4 : 3
                    radius: height / 2
                    color: Theme.fillMid
                    Behavior on height { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }

                    Rectangle {
                        width: parent.width * scrub.shown
                        height: parent.height
                        radius: parent.radius
                        color: Media.colorsResolved ? root.primary : Theme.text
                        Behavior on color { ColorAnimation { duration: Theme.durColor } }
                        Behavior on width {
                            enabled: !scrub.dragging
                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                        }
                    }
                }

                // Handle appears on hover, the way macOS does it.
                Rectangle {
                    width: 9
                    height: 9
                    radius: 4.5
                    color: Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                    x: barTrack.width * scrub.shown - width / 2
                    opacity: (scrubArea.containsMouse || scrub.dragging) && Media.canSeek ? 1 : 0
                    scale: scrub.dragging ? 1.2 : 1.0
                    Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
                    Behavior on scale { NumberAnimation { duration: Theme.durHover; easing.type: Theme.easeStandard } }
                }

                MouseArea {
                    id: scrubArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    enabled: Media.canSeek
                    preventStealing: true

                    function frac(x) { return Math.min(1, Math.max(0, x / Math.max(1, barTrack.width))) }

                    onPressed: mouse => { scrub.dragging = true; scrub.dragFraction = frac(mouse.x + 4) }
                    onPositionChanged: mouse => { if (pressed) scrub.dragFraction = frac(mouse.x + 4) }
                    onReleased: {
                        Media.seek(scrub.dragFraction * Media.length)
                        scrub.dragging = false
                    }
                }
            }
        }

        // ---- transport --------------------------------------------------------
        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: scrub.bottom
            anchors.topMargin: 8
            height: 30

            Row {
                anchors.centerIn: parent
                spacing: 14

                IconButton {
                    icon: "󰒮"
                    iconSize: Theme.fontSize(1.0)
                    diameter: 30
                    enabled: Media.canGoPrevious
                    iconColor: Theme.text
                    onClicked: Media.previous()
                }

                IconButton {
                    icon: Media.playing ? "󰏤" : "󰐊"
                    iconSize: Theme.fontSize(1.19)
                    diameter: 30
                    enabled: Media.available
                    iconColor: Theme.text
                    onClicked: Media.play()
                }

                IconButton {
                    icon: "󰒭"
                    iconSize: Theme.fontSize(1.0)
                    diameter: 30
                    enabled: Media.canGoNext
                    iconColor: Theme.text
                    onClicked: Media.next()
                }
            }

            // Output device, pushed to the right edge.
            IconButton {
                id: outputButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "󱡬"
                iconSize: Theme.fontSize(0.95)
                diameter: 28
                iconColor: Theme.textDim
                onClicked: {
                    const p = outputButton.mapToItem(null, outputButton.width / 2, 0)
                    root.sinkPickerRequested(Math.round(p.x))
                }
            }
        }
    }
}
