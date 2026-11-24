// Matrix rain (from the SDDM theme's MatrixRain). CPU canvas, so `fps` is the
// battery knob: SDDM runs 20, the lockscreen defaults to 15.
import QtQuick

Canvas {
	id: rain
	anchors.fill: parent
	renderStrategy: Canvas.Threaded   // paint off the GUI thread: no stalls during ring animations
	property color color: "#00FF41"
	property string fontFamily: "monospace"
	property int fontSize: 18
	property int fps: 15
	property var drops: []
	readonly property string glyphs: "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789Z:.=*+-<>"

	onWidthChanged: drops = []

	onPaint: {
		var ctx = getContext("2d");
		var cols = Math.floor(width / fontSize);
		if (drops.length !== cols) {
			drops = [];
			for (var i = 0; i < cols; i++)
				drops.push(Math.floor(Math.random() * -50));
			ctx.fillStyle = "black";
			ctx.fillRect(0, 0, width, height);
		}
		ctx.fillStyle = "rgba(0, 0, 0, 0.08)";   // trail length: lower = longer trails
		ctx.fillRect(0, 0, width, height);
		ctx.font = fontSize + "px '" + fontFamily + "'";
		for (var c = 0; c < cols; c++) {
			var y = drops[c] * fontSize;
			if (y > 0) {
				var ch = glyphs.charAt(Math.floor(Math.random() * glyphs.length));
				ctx.fillStyle = Math.random() > 0.97 ? "#D8FFD8" : rain.color;
				ctx.fillText(ch, c * fontSize, y);
			}
			if (y > height && Math.random() > 0.975)
				drops[c] = 0;
			else
				drops[c]++;
		}
	}

	Timer {
		interval: Math.round(1000 / rain.fps)
		running: rain.visible
		repeat: true
		onTriggered: rain.requestPaint()
	}
}
