// HUD rings (SDDM MatrixHud, scaled to 620 px at 1080p). While `expanded`
// (typing) every ring and the dark disk move out by `grow` and stop spinning,
// opening up room around the clock + password in the middle.
//
// Auth feedback = ONE circle (authCircle), the HUD rings converge + fade out:
//   verifying: a short arc with a bright head spins around the clock
//   granted:   the spinning arc grows into a full green circle and stops, pulses, ripples
//   denied:    the spinning arc grows into a full red circle, shakes "no", fades,
//              then the HUD rings come back
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
	id: hud
	property real k: 1                          // screen scale vs 1080p
	property color color: "#00FF41"
	property color failColor: "#E5575B"
	property bool expanded: false
	property int nudges: 0                      // keystrokes while typing
	property bool verifying: false              // PAM is checking the password
	property bool merged: false                 // ACCESS GRANTED
	property bool failed: false                 // ACCESS DENIED
	readonly property real u: k * 620 / 460    // SDDM ring units -> px
	readonly property real maxGrow: 60 * k
	readonly property real grow: expanded ? maxGrow : 0
	readonly property real mergeR: 165 * u + maxGrow
	readonly property string authState: merged ? "granted" : failed ? "denied" : verifying ? "verifying" : "idle"
	readonly property bool authActive: authState !== "idle"

	width: 2 * (296 * u + 60 * k) + 48
	height: width

	Rectangle {
		anchors.centerIn: parent
		width: 2 * (220 * hud.u + hud.grow)
		height: width
		radius: width / 2
		color: "black"
		opacity: hud.expanded ? 0.75 : 0.55   // dark disk behind the text: rain shows through a bit, darker while typing
		Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
		Behavior on opacity { NumberAnimation { duration: 380 } }
	}

	// ---- the single auth circle ----
	SweepCircle {
		id: authCircle
		radius: hud.mergeR
		k: hud.k
		color: hud.authState === "denied" ? hud.failColor : "#00FF41"
		opacity: 0
		transform: Translate { id: shake }
	}
	Rectangle {
		id: ripple
		anchors.centerIn: parent
		width: 2 * hud.mergeR
		height: width
		radius: width / 2
		color: "transparent"
		border.color: authCircle.color
		border.width: 2 * hud.k
		opacity: 0
	}

	// verifying: a ~80 deg arc spinning (it keeps its angle when the verdict comes in)
	ParallelAnimation {
		id: verifyAnim
		NumberAnimation { target: authCircle; property: "opacity"; to: 1; duration: 200 }
		NumberAnimation { target: authCircle; property: "progress"; to: 0.22; duration: 300; easing.type: Easing.OutCubic }
		NumberAnimation {
			target: authCircle; property: "startAngleDeg"
			from: -90; to: 270; duration: 900
			loops: Animation.Infinite
		}
	}

	// granted: grow into the full green circle, stop, pulse + ripple
	SequentialAnimation {
		id: grantAnim
		NumberAnimation { target: authCircle; property: "opacity"; to: 1; duration: 150 }
		NumberAnimation { target: authCircle; property: "progress"; to: 1; duration: 480; easing.type: Easing.OutCubic }
		ParallelAnimation {
			SequentialAnimation {
				NumberAnimation { target: authCircle.arc; property: "scale"; to: 1.04; duration: 120; easing.type: Easing.OutQuad }
				NumberAnimation { target: authCircle.arc; property: "scale"; to: 1.0; duration: 280; easing.type: Easing.InOutQuad }
			}
			NumberAnimation { target: ripple; property: "scale"; from: 1.0; to: 1.3; duration: 560; easing.type: Easing.OutCubic }
			NumberAnimation { target: ripple; property: "opacity"; from: 0.7; to: 0; duration: 560; easing.type: Easing.OutCubic }
		}
	}

	// denied: grow into the full red circle, shake "no", fade out
	SequentialAnimation {
		id: failAnim
		NumberAnimation { target: authCircle; property: "opacity"; to: 1; duration: 150 }
		NumberAnimation { target: authCircle; property: "progress"; to: 1; duration: 480; easing.type: Easing.OutCubic }
		SequentialAnimation {
			NumberAnimation { target: shake; property: "x"; to: -12 * hud.k; duration: 55; easing.type: Easing.OutQuad }
			NumberAnimation { target: shake; property: "x"; to: 12 * hud.k; duration: 90; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: -8 * hud.k; duration: 80; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: 5 * hud.k; duration: 70; easing.type: Easing.InOutQuad }
			NumberAnimation { target: shake; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
		}
		PauseAnimation { duration: 300 }
		NumberAnimation { target: authCircle; property: "opacity"; to: 0; duration: 450; easing.type: Easing.InOutSine }
		ScriptAction { script: hud.resetAuth() }
	}

	NumberAnimation { id: fadeOut; target: authCircle; property: "opacity"; to: 0; duration: 250; onFinished: hud.resetAuth() }

	function resetAuth() {
		authCircle.progress = 0;
		authCircle.startAngleDeg = -90;
		authCircle.arc.scale = 1;
		shake.x = 0;
		ripple.opacity = 0;
	}

	onAuthStateChanged: {
		if (authState === "verifying") {
			grantAnim.stop(); failAnim.stop(); fadeOut.stop();
			resetAuth();
			verifyAnim.restart();
		} else if (authState === "granted") {
			verifyAnim.stop();
			grantAnim.restart();
		} else if (authState === "denied") {
			verifyAnim.stop();
			failAnim.restart();
		} else {                       // idle again (e.g. failure timeout): let a running denial finish
			verifyAnim.stop();
			if (!failAnim.running && !grantAnim.running) fadeOut.restart();
		}
	}

	// ---- the rings: converge + fade out while auth feedback is up, come back after ----
	Item {
		anchors.fill: parent
		opacity: hud.authActive ? 0 : 0.45   // SDDM ring intensity 0.45
		Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutSine } }

		HudRing { mergeRadius: hud.authActive ? hud.mergeR : -1; nudges: hud.nudges; nudgeStep: 6; baseRadius: 210 * hud.u; grow: hud.grow; maxGrow: hud.maxGrow; arcs: 4; arcSpan: 20; lineWidth: 2; duration: 24000; clockwise: false; color: hud.color; frozen: hud.expanded; opacity: 0.5 }
		HudRing { mergeRadius: hud.authActive ? hud.mergeR : -1; nudges: hud.nudges; nudgeStep: 12; baseRadius: 180 * hud.u; grow: hud.grow; maxGrow: hud.maxGrow; arcs: 3; arcSpan: 70; lineWidth: 2; duration: 9000; color: hud.color; frozen: hud.expanded }
		HudRing { mergeRadius: hud.authActive ? hud.mergeR : -1; nudges: hud.nudges; nudgeStep: 3; baseRadius: 155 * hud.u; grow: hud.grow; maxGrow: hud.maxGrow; ticks: 60; lineWidth: 2; duration: 30000; clockwise: false; color: hud.color; frozen: hud.expanded; opacity: 0.7 }
		HudRing { mergeRadius: hud.authActive ? hud.mergeR : -1; nudges: hud.nudges; nudgeStep: 20; baseRadius: 135 * hud.u; grow: hud.grow; maxGrow: hud.maxGrow; arcs: 1; arcSpan: 270; lineWidth: 3; duration: 4000; color: hud.color; frozen: hud.expanded; opacity: 0.8 }
		HudRing { mergeRadius: hud.authActive ? hud.mergeR : -1; nudges: hud.nudges; nudgeStep: 10; baseRadius: 115 * hud.u; grow: hud.grow; maxGrow: hud.maxGrow; arcs: 6; arcSpan: 25; lineWidth: 2; duration: 6000; clockwise: false; color: hud.color; frozen: hud.expanded; opacity: 0.6 }
	}
}
