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
    property bool active: false

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
    onActiveChanged: {
        if (active) {
            // Start biometric authentications immediately
            fprintdPam.start();
            interactivePam.start(); // This will trigger howdy
        }
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
            // If fingerprint fails, restart it after a short delay to allow retries

            if (result == PamResult.Success)
                handleUnlockSuccess();
            else
                Qt.callLater(fprintdPam.start);
        }
    }

    // PAM context for howdy (face) and pam_unix (password)
    PamContext {
        id: interactivePam

        config: "quickshell"
        onPamMessage: {
            // Only respond with a password if the user has entered one

            if (this.responseRequired)
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
