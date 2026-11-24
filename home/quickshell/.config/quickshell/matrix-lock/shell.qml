// Matrix lockscreen (Quickshell) - same look as the SDDM theme TerminalStyleLogin
// (+ MatrixRain / MatrixHud), with real animation: rings widen and stop turning
// while you type. Run: qs -c matrix-lock      Preview (no lock, no PAM):
//   MATRIX_LOCK_PREVIEW=1 qs -c matrix-lock   (Esc closes; MATRIX_LOCK_DEMO=1 auto-types)
// PAM self-test without locking (window closes + logs PASS on the right password):
//   MATRIX_LOCK_PREVIEW=1 MATRIX_LOCK_PAMTEST=1 qs -c matrix-lock
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
	id: shell
	readonly property bool preview: Quickshell.env("MATRIX_LOCK_PREVIEW") === "1"
	readonly property bool pamTest: preview && Quickshell.env("MATRIX_LOCK_PAMTEST") === "1"

	// A hot-reload while locked could drop the lock surface: never watch files.
	Component.onCompleted: Quickshell.watchFiles = false

	LockContext {
		id: ctx
		preview: shell.preview && !shell.pamTest   // pam test = real PAM inside the preview window
		previewGrants: Quickshell.env("MATRIX_LOCK_DEMO") === "grant"
		onUnlocked: {
			if (shell.preview)
				console.log("PASS: PAM accepted the password");
			// Unlock before exiting, or Hyprland shows its fallback "lock dead" screen.
			lock.locked = false;
			Qt.quit();
		}
	}

	WlSessionLock {
		id: lock
		locked: !shell.preview

		WlSessionLockSurface {
			color: "black"
			LockSurface {
				anchors.fill: parent
				context: ctx
			}
		}
	}

	// Heartbeat for lock-watchdog.sh (run by hypridle after resume): the time of the
	// last rendered frame. If it goes stale, the watchdog hands the lock to hyprlock.
	FileView {
		id: heartbeat
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/matrix-lock.heartbeat"
	}
	Timer {
		// MATRIX_LOCK_HEARTBEAT_TEST=1 also writes it in preview, to test the watchdog safely
		interval: 2000; running: !shell.preview || Quickshell.env("MATRIX_LOCK_HEARTBEAT_TEST") === "1"; repeat: true; triggeredOnStart: true
		onTriggered: heartbeat.setText(String(Math.round(ctx.lastFrame)))
	}

	LazyLoader {
		active: shell.preview
		FloatingWindow {
			implicitWidth: 1600
			implicitHeight: 900
			color: "black"
			LockSurface {
				anchors.fill: parent
				context: ctx
				preview: true
			}
		}
	}
}
