import QtQuick
import QtQuick.Effects
import ".."

/*
 * The frosted slab. Every island and popup is one of these.
 *
 * The compositor supplies the backdrop blur (via the layerrule keyed to the
 * window's WlrLayershell.namespace); QML only supplies the tint on top of it.
 * QML *cannot* blur what is behind it, so there is deliberately no MultiEffect
 * or ShaderEffect blur anywhere in this file — it would be a no-op at best.
 *
 * The rim is what sells the material, not the fill. Five layers, drawn in this
 * order from back to front:
 *
 *   0. drop shadow   - large radius, low opacity, offset down. Separates the
 *                      slab from the wallpaper so it floats.
 *   1. fill          - low-alpha tint. Anything near opaque hides the blur.
 *   2. specular sheen- a faint diagonal white wash, upper-left to transparent
 *                      by the lower-right. Barely visible in isolation; it is
 *                      the difference between "material" and "coloured rect".
 *   3. inner border  - 1px white at low alpha all the way round: the glass edge.
 *   4. top highlight - 1px white at ~0.3, fading to transparent by the vertical
 *                      midpoint of its own 1px-tall rect. This is light catching
 *                      the top bevel of a slab, and it only exists on the top.
 *   5. bottom shade  - a matching dark line along the bottom for thickness.
 *
 * Layers 4 and 5 are inset by `radius * 0.6` horizontally so the highlight does
 * not run past the corner arc and stick out as two bright nubs.
 */
Item {
    id: root

    property real radius: Theme.radiusIsland

    // Opt in to the shell's island/notch mode, for the surfaces that ARE the
    // shell's furniture — the three islands. In notch mode they go opaque
    // black, square-shouldered, unlit and flared; in island mode they are the
    // glass they have always been, at whatever `radius` they asked for (the app
    // island asks for half its width, and stays a circle).
    //
    // Off by default, so the popups and the media card — which are content
    // sitting on top of the shell rather than part of its frame — keep their
    // glass in both modes.
    property bool followsNotch: false
    readonly property bool notched: followsNotch && Theme.notch

    // Corner radii, split top from bottom so a surface can be square along one
    // edge and round along the other. That split is the entire shape of the
    // notch: square where it meets the top of the screen, round where it leaves
    // it. Both default to `radius`, so every existing caller is unaffected.
    property real topRadius: notched ? 0 : radius
    property real bottomRadius: notched ? Theme.radiusNotch : radius

    // Concave flare at the two top corners, in pixels. 0 draws nothing.
    //
    // Where topRadius/bottomRadius round a corner *inward*, this bends one
    // outward: the surface widens as it approaches its own top edge, so the
    // wall never meets that edge at a right angle. It is what makes the notch
    // read as a shape cut out of the display — the screen appears to flow into
    // it — rather than as a black bar parked against the top of the screen.
    //
    // It is drawn as two square patches sitting just OUTSIDE this item's left
    // and right edges, so a caller must leave `topFlare` pixels of slack on
    // each side; the centre island's `pad` is what pays for it there.
    property real topFlare: notched ? Theme.radiusNotchFlare : 0

    // The glass chrome — sheen, rim, top bevel, bottom shade — faded as one.
    // At 0 the surface is nothing but `fill`: no material, no edge, no light.
    //
    // This is why the notch cannot just be this slab with a black fill. A black
    // slab still wearing a white rim and a diagonal sheen reads as a pane of
    // very dark glass; a notch has to read as a hole in the display, and a hole
    // has no edge highlight.
    property real chrome: notched ? 0 : 1
    property color fill: notched ? Theme.notchFill : Theme.glassBar
    property color rimColor: Theme.rim
    property color topRimColor: Theme.rimTop
    property color bottomRimColor: Theme.rimBottom
    property color sheenColor: Theme.sheen
    property color shadowColor: Theme.shadow
    property real shadowRadius: Theme.shadowRadius
    property real shadowOffset: Theme.shadowOffset
    property bool shadowEnabled: Theme.shadowsEnabled

    // Extra rim on top of the standard one — the media card drives this from
    // the album art. Transparent means "unused".
    property color accentRim: "transparent"
    property color accentRimEnd: "transparent"
    property real accentRimWidth: 0

    default property alias content: contentHolder.data

    // The island <-> notch transition. Nothing here fires on a normal surface:
    // every other caller sets these once and never moves them.
    Behavior on topRadius { NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard } }
    Behavior on bottomRadius { NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard } }
    Behavior on chrome { NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard } }
    Behavior on topFlare { NumberAnimation { duration: Theme.durMode; easing.type: Theme.easeStandard } }

    // One corner of the flare: a square of `fill`, with a quarter disc erased
    // from the corner that faces the surface. Erased rather than painted over,
    // for the same reason ControlCenterIcon erases — there is no opaque
    // background colour available to paint the cut with, only whatever the
    // compositor has put behind the layer.
    //
    // The disc is centred on the patch's OUTER bottom corner — the one furthest
    // from the surface — so the patch keeps its whole inner edge (which is what
    // welds it to the surface's own wall) and loses the corner that faces away.
    //
    // That corner is what makes the curve bend the right way. Centre the disc
    // on the inner corner instead and the arc runs the other direction: it eats
    // the edge that should join the wall, and the flare curls back on itself
    // instead of sweeping out into the screen edge.
    //
    // The two tangents are the check. At the top the arc has to run horizontal,
    // so it meets the screen edge flush; where it lands on the wall it has to
    // run vertical, so there is no crease. Only the disc centred at the outer
    // bottom corner satisfies both.
    component FlareCorner: Canvas {
        id: flare

        property bool centreOnRight: false

        // Whole pixels. A surface sized from text metrics lands on a fractional
        // width, and a patch placed at that fraction gets resampled — which is
        // what put a pale hairline between the patch and the surface's own edge.
        readonly property int r: Math.round(root.topFlare)

        // ...and one column of the patch tucks *under* that edge, so even when
        // the two round apart there is no gap left for the background to show
        // through. It sits on the near side, which the disc never reaches, so
        // it always paints solid.
        readonly property int overlap: 1

        // Canvas repaints on resize but not on a plain property change, so the
        // fill is mirrored here to hang a repaint off it.
        readonly property color flareFill: root.fill

        width: r + overlap
        height: r
        y: 0
        visible: r >= 1
        renderStrategy: Canvas.Cooperative

        onFlareFillChanged: requestPaint()
        onRChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = flare.flareFill
            ctx.fillRect(0, 0, width, height)
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(flare.centreOnRight ? flare.width : 0, flare.r, flare.r, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    // Left patch: outer corner on the left, overlap column on the right.
    FlareCorner {
        x: -r
        centreOnRight: false
    }

    // Right patch: mirrored — outer corner on the right, overlap on the left.
    FlareCorner {
        x: Math.round(root.width) - overlap
        centreOnRight: true
    }

    // ------------------------------------------------------------- 0 shadow --
    // A blurred rounded rect in the shadow colour, sitting behind everything
    // and nudged down. The wrapper is inflated by shadowRadius on every side so
    // the blur has room to spread instead of being clipped at the layer bounds;
    // the inner rect is inset back by the same amount, plus shadowOffset on the
    // top / minus it on the bottom, which is what shifts the shadow downward.
    //
    // `layer.enabled` follows shadowEnabled rather than being left on. Enabling
    // a layer allocates an offscreen texture the size of this inflated item and
    // builds the MultiEffect blur pipeline behind it, whether or not the item is
    // ever drawn — and every island, popup, card and tooltip in the shell is one
    // of these, so with shadows off that is a dozen textures for nothing.
    Item {
        z: -1
        visible: root.shadowEnabled
        anchors.fill: parent
        anchors.margins: -root.shadowRadius
        layer.enabled: root.shadowEnabled
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: Math.round(root.shadowRadius)
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: root.shadowRadius
            anchors.rightMargin: root.shadowRadius
            anchors.topMargin: root.shadowRadius + root.shadowOffset
            anchors.bottomMargin: root.shadowRadius - root.shadowOffset
            radius: root.radius
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
            color: root.shadowColor
            antialiasing: true
        }
    }

    // --------------------------------------------------------------- 1 fill --
    Rectangle {
        id: base
        anchors.fill: parent
        radius: root.radius
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
        color: root.fill
        antialiasing: true

        Behavior on color { ColorAnimation { duration: Theme.durOpen; easing.type: Theme.easeStandard } }

        // ------------------------------------------------------- 2 specular --
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
            opacity: root.chrome
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.sheenColor }
                GradientStop { position: 0.45; color: Qt.rgba(root.sheenColor.r, root.sheenColor.g, root.sheenColor.b, root.sheenColor.a * 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // The diagonal component of the sheen. A vertical gradient alone reads
        // as a lit shelf; skewing a second wash across it reads as glass.
        Item {
            anchors.fill: parent
            clip: true
            opacity: root.chrome
            Rectangle {
                width: parent.width * 2.2
                height: parent.height * 2.2
                x: -parent.width * 0.6
                y: -parent.height * 1.1
                rotation: 28
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.46; color: Qt.rgba(root.sheenColor.r, root.sheenColor.g, root.sheenColor.b, root.sheenColor.a * 0.9) }
                    GradientStop { position: 0.54; color: "transparent" }
                }
            }
        }

        // --------------------------------------------------- 3 inner border --
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
            color: "transparent"
            border.width: 1
            border.color: root.rimColor
            opacity: root.chrome
            antialiasing: true
        }

        // Accent rim (album-art driven). Drawn over the neutral rim so the two
        // stack rather than fight; width 0 keeps it out of the way entirely.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
            color: "transparent"
            border.width: root.accentRimWidth
            border.color: root.accentRim
            opacity: root.chrome
            visible: root.accentRimWidth > 0
            antialiasing: true
            Behavior on border.color { ColorAnimation { duration: Theme.durColor; easing.type: Theme.easeStandard } }
        }

        // ------------------------------------------------- 4 top highlight --
        // 1px tall, faded to nothing by its own midpoint: a bevel catching light.
        Rectangle {
            height: 1
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.radius * 0.6
            anchors.rightMargin: root.radius * 0.6
            anchors.topMargin: 1
            opacity: root.chrome
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.28; color: root.topRimColor }
                GradientStop { position: 0.72; color: root.topRimColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ---------------------------------------------------- 5 bottom line --
        Rectangle {
            height: 1
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.radius * 0.8
            anchors.rightMargin: root.radius * 0.8
            anchors.bottomMargin: 1
            opacity: root.chrome
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: root.bottomRimColor }
                GradientStop { position: 0.65; color: root.bottomRimColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Item {
            id: contentHolder
            anchors.fill: parent
        }
    }
}
