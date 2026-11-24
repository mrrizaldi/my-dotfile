// One rotating ring (from the SDDM theme's HudRing): arc segments or tick marks
// drawn on a Canvas, spun by animating the item's rotation (a transform: no repaint).
// Widening while typing is a `scale` animation: the canvas is painted ONCE at the
// widest radius and scaled down when idle, so nothing repaints mid-animation
// (repainting 5 glowing canvases per frame is what made the transition stutter).
import QtQuick

Item {
	id: ring
	property real baseRadius: 150   // idle radius
	property real grow: 0           // extra radius right now (0 idle, maxGrow typing)
	property real maxGrow: 60
	property int arcs: 3            // number of arc segments
	property real arcSpan: 60       // degrees per segment
	property int ticks: 0           // >0 draws tick marks instead of arcs
	property real lineWidth: 3      // as seen when idle
	property int duration: 8000     // ms per full turn
	property bool clockwise: true
	property bool frozen: false
	property int nudges: 0          // keystrokes so far: each one turns the ring
	property real nudgeStep: 8      // degrees per notch
	property real nudgeAngle: 0
	// Combination-safe dial: every keystroke turns each ring 1-2 notches in a random
	// direction, independently of the other rings.
	onNudgesChanged: nudgeAngle += nudgeStep * (Math.random() < 0.5 ? -1 : 1) * (Math.random() < 0.65 ? 1 : 2)
	property color color: "#00FF41"

	readonly property real paintRadius: baseRadius + maxGrow
	property real mergeRadius: -1   // >0: every ring goes to this radius (ACCESS GRANTED)
	property real currentRadius: mergeRadius > 0 ? mergeRadius : baseRadius + grow
	Behavior on currentRadius { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

	width: paintRadius * 2 + 24
	height: width
	anchors.centerIn: parent
	scale: currentRadius / paintRadius

	onColorChanged: canvas.requestPaint()

	Canvas {
		id: canvas
		anchors.fill: parent
		transform: Rotation {
			origin.x: canvas.width / 2
			origin.y: canvas.height / 2
			angle: ring.nudgeAngle
			Behavior on angle { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
		}
		onPaint: {
			var ctx = getContext("2d");
			var c = width / 2;
			var r = ring.paintRadius;
			var f = ring.paintRadius / ring.baseRadius;   // undo the idle downscale for line/tick sizes
			ctx.reset();
			ctx.strokeStyle = ring.color;
			ctx.lineWidth = ring.lineWidth * f;
			ctx.shadowColor = ring.color;
			ctx.shadowBlur = 5 * f;
			if (ring.ticks > 0) {
				for (var t = 0; t < ring.ticks; t++) {
					var a = t * 2 * Math.PI / ring.ticks;
					var len = ((t % 5 === 0) ? 12 : 5) * f;
					ctx.beginPath();
					ctx.moveTo(c + Math.cos(a) * r, c + Math.sin(a) * r);
					ctx.lineTo(c + Math.cos(a) * (r - len), c + Math.sin(a) * (r - len));
					ctx.stroke();
				}
			} else {
				var step = 2 * Math.PI / ring.arcs;
				var span = ring.arcSpan * Math.PI / 180;
				for (var i = 0; i < ring.arcs; i++) {
					ctx.beginPath();
					ctx.arc(c, c, r, i * step, i * step + span);
					ctx.stroke();
				}
			}
		}
	}

	// Idle spin. A NumberAnimation (not RotationAnimator): render-thread Animators ignore
	// `paused`, so the spin kept running under the per-keystroke notches while typing.
	NumberAnimation on rotation {
		from: 0
		to: ring.clockwise ? 360 : -360
		duration: ring.duration
		loops: Animation.Infinite
		paused: ring.frozen
	}
}
