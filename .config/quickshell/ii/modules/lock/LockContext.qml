import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs

Scope {
    id: root

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool _unlocked: false // Prevents multiple unlock signals

    signal shouldReFocus()
    signal unlocked()
    signal failed()

    function tryUnlock() {
        if (unlockInProgress)
            return ;

        root.unlockInProgress = true;
        // Start the PAM context that handles password and howdy
        interactivePam.start();
    }

    function handleUnlockSuccess() {
        if (!_unlocked) {
            _unlocked = true;
            root.unlocked();
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }
    Component.onCompleted: {
        // Start biometric authentications immediately
        fprintdPam.start();
        interactivePam.start(); // This will trigger howdy
    }

    Timer {
        id: passwordClearTimer

        interval: 10000
        onTriggered: {
            root.currentText = "";
        }
    }

    // PAM context for fprintd (fingerprint)
    PamContext {
        id: fprintdPam

        config: "fingerprint"
        onCompleted: (result) => {
            if (result == PamResult.Success)
                handleUnlockSuccess();
            else
                // If fingerprint fails, restart it after a short delay to allow retries
                Qt.callLater(fprintdPam.start);
        }
    }

    // PAM context for howdy (face) and pam_unix (password)
    PamContext {
        id: interactivePam

        config: "quickshell"
        onPamMessage: {
            if (this.responseRequired)
                // Only respond with a password if the user has entered one
                this.respond(root.currentText);

        }
        onCompleted: (result) => {
            if (result == PamResult.Success) {
                handleUnlockSuccess();
            } else {
                root.showFailure = true;
                GlobalStates.screenUnlockFailed = true;
                // If auth fails (e.g. wrong password), restart to allow howdy to try again
                Qt.callLater(interactivePam.start);
            }
            root.currentText = "";
            root.unlockInProgress = false;
        }
    }

}
