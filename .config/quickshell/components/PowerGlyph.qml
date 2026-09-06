import QtQuick
import ".."

/*
 * The four power-menu glyphs, drawn on a Canvas rather than pulled from the
 * Nerd Font — same reasoning as ControlCenterIcon.qml: they scale continuously
 * with Theme.fontSizeBase instead of snapping between the sizes a hinted glyph
 * happens to look right at, and the four stay optically matched to each other
 * because they share one stroke weight and one bounding box.
 *
 * Every dimension below is a fraction of `size`, so the whole set rescales from
 * that one number. `glyph` picks which one to paint:
 *
 *   power  — IEC 5009: a ring broken at the top with a vertical stroke through
 *            the gap. Used both for the collapsed island button and for shut
 *            down, which is why it is the default.
 *   lock   — padlock: shackle arc over a rounded body.
 *   sleep  — crescent moon. Solid, unlike the other three: a hairline crescent
 *            outline collapses into an unreadable sliver at bar sizes.
 *   logout — an arrow leaving an open-sided bracket.
 */
Item {
    id: root

    property int size: 16
    property color color: Theme.text
    property string glyph: "power"

    implicitWidth: size
    implicitHeight: size

    onColorChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()
    onGlyphChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d")
            const s = Math.min(width, height)
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            // One weight for the whole set — this is what makes four different
            // shapes read as one family.
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineWidth = s * 0.10
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            switch (root.glyph) {
            case "lock":   paintLock(ctx, s);   break
            case "sleep":  paintSleep(ctx, s);  break
            case "logout": paintLogout(ctx, s); break
            default:       paintPower(ctx, s);  break
            }
        }

        // The ring is drawn the long way round, from just past the gap's right
        // edge all the way back to its left edge, so the break sits centred on
        // top no matter what `gap` is set to.
        function paintPower(ctx, s) {
            const cx = s * 0.5
            const cy = s * 0.56
            const r = s * 0.32
            const gap = Math.PI * 0.30          // ~54° of missing arc, centred up
            const top = -Math.PI / 2

            ctx.beginPath()
            ctx.arc(cx, cy, r, top + gap / 2, top - gap / 2 + Math.PI * 2)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(cx, s * 0.12)
            ctx.lineTo(cx, cy - r * 0.30)
            ctx.stroke()
        }

        function paintLock(ctx, s) {
            const cx = s * 0.5
            const bodyTop = s * 0.46
            const bodyLeft = s * 0.22
            const bodyRight = s * 0.78
            const bodyBottom = s * 0.86
            const corner = s * 0.10

            // Shackle: the upper half of a circle sitting on the body's top edge.
            ctx.beginPath()
            ctx.arc(cx, bodyTop, s * 0.17, Math.PI, Math.PI * 2)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(bodyLeft + corner, bodyTop)
            ctx.lineTo(bodyRight - corner, bodyTop)
            ctx.arcTo(bodyRight, bodyTop, bodyRight, bodyTop + corner, corner)
            ctx.lineTo(bodyRight, bodyBottom - corner)
            ctx.arcTo(bodyRight, bodyBottom, bodyRight - corner, bodyBottom, corner)
            ctx.lineTo(bodyLeft + corner, bodyBottom)
            ctx.arcTo(bodyLeft, bodyBottom, bodyLeft, bodyBottom - corner, corner)
            ctx.lineTo(bodyLeft, bodyTop + corner)
            ctx.arcTo(bodyLeft, bodyTop, bodyLeft + corner, bodyTop, corner)
            ctx.closePath()
            ctx.stroke()
        }

        // A full disc with a second, offset disc erased out of it. Painting the
        // bite in a background colour is not an option here — the icon sits on
        // frosted glass, so there is no opaque colour to paint with; erasing is
        // the only way to cut a clean edge. Same trick as ControlCenterIcon.
        function paintSleep(ctx, s) {
            ctx.beginPath()
            ctx.arc(s * 0.52, s * 0.50, s * 0.34, 0, Math.PI * 2)
            ctx.fill()

            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(s * 0.74, s * 0.34, s * 0.33, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalCompositeOperation = "source-over"
        }

        function paintLogout(ctx, s) {
            const left = s * 0.16
            const right = s * 0.50
            const top = s * 0.16
            const bottom = s * 0.84
            const corner = s * 0.10

            // The bracket: a rounded rect with its right side left open, so the
            // arrow reads as leaving through it.
            ctx.beginPath()
            ctx.moveTo(right, top)
            ctx.lineTo(left + corner, top)
            ctx.arcTo(left, top, left, top + corner, corner)
            ctx.lineTo(left, bottom - corner)
            ctx.arcTo(left, bottom, left + corner, bottom, corner)
            ctx.lineTo(right, bottom)
            ctx.stroke()

            const midY = s * 0.50
            const tip = s * 0.88

            ctx.beginPath()
            ctx.moveTo(s * 0.42, midY)
            ctx.lineTo(tip, midY)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(tip - s * 0.16, midY - s * 0.16)
            ctx.lineTo(tip, midY)
            ctx.lineTo(tip - s * 0.16, midY + s * 0.16)
            ctx.stroke()
        }
    }
}
