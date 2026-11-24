// Text that types itself out, terminal style, whenever `full` changes - except the
// strings in `instant`, which appear at once. The decision is made from `full`
// itself inside the handler: bindings that depend on `full` may not have updated
// yet when onFullChanged runs (that once showed the greeting instantly, or typed
// only len("SYSTEM LOCKED") characters of it).
import QtQuick

Text {
	id: t
	property string full: ""
	property var instant: [""]          // shown at once, not typed
	property int msPerChar: 35
	property bool cursor: false         // blinking "_" after the text
	property int shown: full.length
	property bool cursorOn: true

	text: full.substring(0, shown) + (cursor && full !== "" ? (cursorOn ? "_" : " ") : "")

	onFullChanged: {
		if (instant.indexOf(full) >= 0) {
			typer.stop();
			shown = full.length;
		} else {
			typer.to = full.length;
			typer.duration = msPerChar * full.length;
			typer.restart();
		}
	}
	NumberAnimation { id: typer; target: t; property: "shown"; from: 0 }
	Timer { interval: 530; running: t.cursor && t.full !== ""; repeat: true; onTriggered: t.cursorOn = !t.cursorOn }
}
