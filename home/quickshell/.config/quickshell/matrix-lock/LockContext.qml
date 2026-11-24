// Shared state for every screen's lock surface + PAM (from the official
// quickshell-examples lockscreen). Preview mode never talks to PAM.
import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
	id: root
	signal unlocked()

	property bool preview: false
	property string currentText: ""
	property bool unlockInProgress: false
	property bool showFailure: false
	property bool granted: false   // right password: play the ACCESS GRANTED beat, then unlock
	property bool leaving: false   // last 300 ms: fade the surface to black, then unlock
	property bool previewGrants: false   // preview demo: pretend the password was right
	property real verifyStart: 0   // when the spinner started (the right password still spins >= 700 ms)
	property real lastFrame: 0   // ms epoch of the last frame any lock surface rendered (watchdog heartbeat)

	onCurrentTextChanged: if (currentText !== "") showFailure = false
	onShowFailureChanged: if (showFailure) failureReset.restart()

	// red rings / ACCESS DENIED fade back to normal after a moment
	Timer {
		id: failureReset
		interval: 2500
		onTriggered: root.showFailure = false
	}

	function tryUnlock() {
		if (currentText === "" || unlockInProgress || granted)
			return;
		unlockInProgress = true;
		verifyStart = Date.now();
		if (preview)
			(previewGrants ? previewGrant : previewFail).start();   // preview never touches PAM
		else
			pam.start();
	}

	// PAM answers a right password in a few ms: keep the verifying spin up for a
	// beat so it reads as "checking", then play ACCESS GRANTED.
	function succeed() {
		const wait = 700 - (Date.now() - verifyStart);
		if (wait > 0) { minVerify.interval = wait; minVerify.start(); }
		else grantBeat.start();
	}
	Timer { id: minVerify; onTriggered: grantBeat.start() }

	function fail() {
		currentText = "";
		showFailure = true;
		unlockInProgress = false;
	}

	// rings merge + ACCESS GRANTED, then actually unlock
	Timer {
		id: grantBeat
		interval: 1450
		onRunningChanged: if (running) { root.granted = true; root.unlockInProgress = false; leaveFade.start(); }
		onTriggered: root.unlocked()
	}
	Timer { id: leaveFade; interval: 1150; onTriggered: root.leaving = true }

	Timer {
		id: previewGrant
		interval: 900
		onTriggered: root.succeed()
	}

	Timer {
		id: previewFail
		interval: 1800   // ~ the delay pam_unix adds to a wrong password
		onTriggered: root.fail()
	}

	PamContext {
		id: pam
		// Own config (pam/password.conf = pam_unix only): the system "login"/"su"
		// stacks may prompt for things this UI can't answer.
		configDirectory: "pam"
		config: "password.conf"

		onPamMessage: {
			if (this.responseRequired)
				this.respond(root.currentText);
		}

		onCompleted: result => {
			if (result == PamResult.Success) {
				root.succeed();
			} else {
				root.fail();
			}
		}
	}
}
