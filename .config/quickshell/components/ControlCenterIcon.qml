import QtQuick
import ".."

/*
 * The macOS Control Center glyph: two horizontal slider rows, each a track with
 * a knob — top knob left of centre, bottom knob right of centre.
 *
 * Drawn on a Canvas rather than pulled from a font, so it scales cleanly with
 * Theme.fontSizeBase instead of snapping between whatever sizes a glyph happens
 * to hint well at. Every dimension below is a fraction of `size`.
 *
 * The gap between knob and track is cut with a destination-out pass rather than
 * painted in a background colour: the icon sits on frosted glass, so there is
 * no opaque background colour to paint with — erasing is the only way to get a
 * clean separation without putting a solid plate on the glass.
 */
Item {
    id: root

    property int size: 16
    property color color: Theme.text

    implicitWidth: size
    implicitHeight: size

    onColorChanged: canvas.requestPaint()
    onSizeChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        // Retina-crisp: render into a buffer at the device pixel ratio.
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d")
            const s = Math.min(width, height)
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            const trackWidth = s * 0.11          // stroke weight of the rails
            const inset = s * 0.14               // rail ends, from the edges
            const topY = s * 0.32
            const bottomY = s * 0.68
            const knobRadius = s * 0.155
            const knobGap = s * 0.055            // clearance cut around a knob

            // Knob centres: top sits left of centre, bottom right of centre.
            const topKnobX = s * 0.36
            const bottomKnobX = s * 0.64

            // 1. the two rails
            ctx.strokeStyle = root.color
            ctx.lineWidth = trackWidth
            ctx.lineCap = "round"

            ctx.beginPath()
            ctx.moveTo(inset, topY)
            ctx.lineTo(s - inset, topY)
            ctx.stroke()

            ctx.beginPath()
            ctx.moveTo(inset, bottomY)
            ctx.lineTo(s - inset, bottomY)
            ctx.stroke()

            // 2. punch the clearance so each knob reads as a separate piece
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath()
            ctx.arc(topKnobX, topY, knobRadius + knobGap, 0, Math.PI * 2)
            ctx.fill()
            ctx.beginPath()
            ctx.arc(bottomKnobX, bottomY, knobRadius + knobGap, 0, Math.PI * 2)
            ctx.fill()

            // 3. the knobs themselves
            ctx.globalCompositeOperation = "source-over"
            ctx.fillStyle = root.color
            ctx.beginPath()
            ctx.arc(topKnobX, topY, knobRadius, 0, Math.PI * 2)
            ctx.fill()
            ctx.beginPath()
            ctx.arc(bottomKnobX, bottomY, knobRadius, 0, Math.PI * 2)
            ctx.fill()
        }
    }
}
