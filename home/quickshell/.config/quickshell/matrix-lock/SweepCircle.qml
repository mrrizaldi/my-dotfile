// A circle that draws itself clockwise from `startAngleDeg` as `progress` goes 0 -> 1,
// with a glow and a bright head riding the tip. GPU-drawn (Shape + MultiEffect):
// only the sweep angle changes, nothing is repainted on the CPU.
// Used for ACCESS GRANTED (green) and ACCESS DENIED (red).
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
	id: sc
	property real radius: 200
	property real k: 1
	property color color: "#00FF41"
	property real progress: 0
	property real startAngleDeg: -90      // where the arc starts (animated while verifying)
	property alias arc: arcLayer          // scale target for pulses

	anchors.centerIn: parent
	width: 2 * (radius + 40 * k)
	height: width

	Item {
		id: arcLayer
		anchors.fill: parent
		visible: sc.progress > 0
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowColor: sc.color
			shadowBlur: 0.8
			shadowOpacity: 1.0
			shadowHorizontalOffset: 0
			shadowVerticalOffset: 0
		}

		Shape {
			anchors.fill: parent
			preferredRendererType: Shape.CurveRenderer
			ShapePath {
				strokeColor: sc.color
				strokeWidth: 2.5 * sc.k
				fillColor: "transparent"
				capStyle: ShapePath.RoundCap
				PathAngleArc {
					centerX: arcLayer.width / 2
					centerY: arcLayer.height / 2
					radiusX: sc.radius
					radiusY: sc.radius
					startAngle: sc.startAngleDeg
					sweepAngle: sc.progress * 360
				}
			}
		}

		Rectangle {   // bright head while drawing
			readonly property real a: (sc.startAngleDeg + sc.progress * 360) * Math.PI / 180
			width: 7 * sc.k
			height: width
			radius: width / 2
			color: Qt.lighter(sc.color, 1.6)
			visible: sc.progress < 1
			x: arcLayer.width / 2 + Math.cos(a) * sc.radius - width / 2
			y: arcLayer.height / 2 + Math.sin(a) * sc.radius - height / 2
		}
	}
}
