// One screen of the lockscreen: rain, HUD, clock (above), status/password (inside), greeting (below).
// Layout is designed at 1080p and scaled by `k`.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Rectangle {
	id: root
	required property LockContext context
	property bool preview: false

	readonly property color green: "#00FF41"
	readonly property color red: "#E5575B"    // softer than SDDM's #FF3B3B, same brightness as the green
	// HUD look: thin true-monospace digits (no width jitter when minutes change), wide
	// tracking, soft glow so the thin strokes don't sink into the dark background.
	readonly property string mono: "JetBrainsMono Nerd Font Mono"
	property string userName: ""   // filled once by `id -un` below (Quickshell.env("USER") came back empty)
	readonly property real k: Math.min(width / 1920, height / 1080)
	readonly property bool typing: context.currentText !== "" || context.unlockInProgress
	// nothing going on: only then are the clock and the greeting shown
	readonly property bool idle: !typing && !context.granted && !context.showFailure

	color: "black"
	opacity: context.leaving ? 0 : 1      // fade to black right before unlocking
	Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }

	MatrixRain {
		color: root.green
		fontFamily: "DejaVu Sans Mono"   // has the half-width katakana the rain needs
		fontSize: Math.max(12, Math.round(18 * root.k))
		opacity: 0.55   // keep the centre readable (SDDM value)
	}

	Hud {
		id: hud
		anchors.centerIn: parent
		k: root.k
		expanded: root.typing
		merged: root.context.granted
		verifying: root.context.unlockInProgress && !root.context.granted
		failed: root.context.showFailure
		failColor: root.red
		Connections {
			target: root.context
			function onCurrentTextChanged() { hud.nudges++; }   // every keystroke (incl. backspace) = one notch
		}
		color: root.context.showFailure ? root.red : root.green
	}

	// ---- layout: clock above the circle, greeting below it, only the status inside.
	// Clock + greeting only while idle; typing/auth leaves just the circle. ----
	// Offsets track the outer ring (283 px idle, 343 px while typing at 1080p) so the
	// clock and greeting always sit just outside it.
	readonly property real outerR: (root.typing ? 343 : 283) * root.k

	Text {
		id: clock
		property var now: new Date()
		anchors.horizontalCenter: hud.horizontalCenter
		anchors.verticalCenter: hud.verticalCenter
		anchors.verticalCenterOffset: -(root.outerR + 62 * root.k)
		Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
		color: root.green
		opacity: root.idle ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
		font.family: root.mono
		font.weight: Font.Light
		font.pixelSize: Math.round(58 * root.k)
		font.letterSpacing: 8 * root.k
		leftPadding: font.letterSpacing   // tracking is added after the last digit too; re-centre
		text: Qt.formatTime(now, "HH:mm")
		layer.enabled: true
		layer.effect: MultiEffect {
			shadowEnabled: true
			shadowColor: clock.color
			shadowBlur: 0.7
			shadowOpacity: 0.9
			shadowHorizontalOffset: 0
			shadowVerticalOffset: 0
		}
		Timer {
			interval: 1000; running: true; repeat: true
			onTriggered: clock.now = new Date()
		}
	}

	// inside the circle: password '*' while typing ...
	Text {
		id: secret
		anchors.centerIn: hud
		color: root.green
		font.family: root.mono
		font.pixelSize: Math.round(30 * root.k)
		font.letterSpacing: 6 * root.k
		text: "*".repeat(Math.min(root.context.currentText.length, 12))   // display cap only: longer passwords still go to PAM in full
		opacity: root.typing && !root.context.unlockInProgress && !root.context.granted ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: 200 } }
	}

	// ... otherwise one status line: SYSTEM LOCKED (blinks) / VERIFYING / GRANTED / DENIED
	TypedText {
		id: status
		anchors.centerIn: hud
		full: root.context.granted ? "ACCESS GRANTED"
			: root.context.showFailure ? "ACCESS DENIED"
			: root.context.unlockInProgress ? "VERIFYING..."
			: root.typing ? ""
			: "SYSTEM LOCKED"
		instant: ["", "SYSTEM LOCKED"]
		msPerChar: 30
		color: root.context.showFailure ? root.red : root.green
		font.family: root.mono
		font.weight: Font.Light
		font.pixelSize: Math.round(18 * root.k)
		font.letterSpacing: 4 * root.k
		leftPadding: font.letterSpacing
		onFullChanged: if (full !== "SYSTEM LOCKED") opacity = 0.9
		SequentialAnimation on opacity {   // SDDM blink, only while idle
			running: status.full === "SYSTEM LOCKED"
			loops: Animation.Infinite
			NumberAnimation { to: 0.15; duration: 900 }
			NumberAnimation { to: 0.8; duration: 900 }
		}
	}

	// below the circle: greeting, only while idle; typed out again each time it reappears
	readonly property string greetText: root.userName ? "welcome back, " + root.userName : ""
	function retypeGreeting() {
		greeting.full = "";
		greeting.full = Qt.binding(() => root.greetText);
	}
	onIdleChanged: if (idle) retypeGreeting()
	TypedText {
		id: greeting
		anchors.horizontalCenter: hud.horizontalCenter
		anchors.verticalCenter: hud.verticalCenter
		anchors.verticalCenterOffset: root.outerR + 50 * root.k
		Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
		full: root.greetText
		msPerChar: 40
		cursor: true
		color: root.green
		opacity: root.idle ? 0.9 : 0
		Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
		font.family: root.mono
		font.weight: Font.Light
		font.pixelSize: Math.round(17 * root.k)
		font.letterSpacing: 1 * root.k
	}

	Process {
		running: true
		command: ["id", "-un"]
		stdout: StdioCollector { onStreamFinished: root.userName = text.trim() }
	}

	// ---- uptime, bottom-left ----

	// /proc/uptime is read once; afterwards uptime is derived from the clock,
	// so nothing gets spawned while locked.
	property real bootMs: 0
	property var uptimeNow: new Date()
	Process {
		running: true
		command: ["cat", "/proc/uptime"]
		stdout: StdioCollector {
			onStreamFinished: root.bootMs = Date.now() - parseFloat(text.split(" ")[0]) * 1000
		}
	}
	Timer {
		interval: 30000; running: true; repeat: true
		onTriggered: root.uptimeNow = new Date()
	}
	function uptimeText() {
		if (root.bootMs === 0) return "";
		const mins = Math.floor((root.uptimeNow.getTime() - root.bootMs) / 60000);
		const d = Math.floor(mins / 1440), h = Math.floor(mins % 1440 / 60), m = mins % 60;
		return (d > 0 ? d + "d " : "") + (d > 0 || h > 0 ? h + "h " : "") + m + "m";
	}

	Column {
		anchors { left: parent.left; bottom: parent.bottom; leftMargin: 24 * root.k; bottomMargin: 20 * root.k }
		spacing: 4 * root.k
		Text {
			color: root.green
			opacity: 0.85
			font.family: root.mono
			font.pixelSize: Math.round(15 * root.k)
			text: "> uptime " + root.uptimeText()
		}
	}

	// ---- invisible password input (keeps keyboard focus) ----
	// Heartbeat for the after-resume watchdog: only real rendered frames count, so a
	// surface that froze or vanished (e.g. output re-plugged on resume) goes stale.
	Connections {
		target: root.Window.window
		function onFrameSwapped() { root.context.lastFrame = Date.now(); }
	}

	// Focus guard (as in the SDDM theme): if the password box ever loses keyboard
	// focus - e.g. a lock surface recreated after resume - take it back.
	Timer {
		interval: 300; running: input.enabled; repeat: true
		onTriggered: if (!input.activeFocus) input.forceActiveFocus()
	}

	TextInput {
		id: input
		width: 1; height: 1
		opacity: 0
		focus: true
		echoMode: TextInput.Password
		inputMethodHints: Qt.ImhSensitiveData
		enabled: !root.context.unlockInProgress && !root.context.granted

		onTextChanged: root.context.currentText = text
		onAccepted: root.context.tryUnlock()
		onEnabledChanged: if (enabled) forceActiveFocus()
		Component.onCompleted: forceActiveFocus()

		Keys.onEscapePressed: {
			if (root.preview) Qt.quit();
			else root.context.currentText = "";
		}

		// keep every screen's box in sync with the shared text
		Connections {
			target: root.context
			function onCurrentTextChanged() {
				if (input.text !== root.context.currentText)
					input.text = root.context.currentText;
			}
		}
	}

	Timer {
		id: demoTyper
		interval: 180; repeat: true
		onTriggered: {
			root.context.currentText += "matrix".charAt(root.context.currentText.length);
			if (root.context.currentText.length >= 6) stop();
		}
	}
	// preview demo: fake typing (2.5 s) then Enter (4.5 s -> failure look), no keyboard needed.
	// MATRIX_LOCK_DEMO=type only types; =grant types, Enter, plays ACCESS GRANTED and closes.
	Timer {
		running: root.preview && ["1", "type", "grant"].includes(Quickshell.env("MATRIX_LOCK_DEMO"))
		interval: 2500
		onTriggered: demoTyper.start()
	}
	Timer {
		running: root.preview && ["1", "grant"].includes(Quickshell.env("MATRIX_LOCK_DEMO"))
		interval: 4500
		onTriggered: root.context.tryUnlock()
	}
}
