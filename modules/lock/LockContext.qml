import QtQuick
import Quickshell
import Quickshell.Services.Pam
import qs.config

// Shared auth state for every lock surface (one per screen) and the preview.
// `buffer` is the typed password, mirrored into each screen's field.
Scope {
    id: root

    property string buffer: ""
    property bool busy: false
    property string error: ""
    property string info: ""

    // Bumped on every failure; surfaces play their shake animation on change.
    property int failures: 0

    signal unlocked

    function submit(): void {
        if (busy || buffer === "")
            return;
        error = "";
        info = "";
        busy = true;
        if (!pam.start()) {
            busy = false;
            error = "Could not start authentication";
            failures++;
        }
    }

    function reset(): void {
        if (pam.active)
            pam.abort();
        buffer = "";
        busy = false;
        error = "";
        info = "";
    }

    PamContext {
        id: pam

        // "login" is what hyprlock uses too (see /etc/pam.d/hyprlock).
        config: Config.lock?.pamConfig ?? "login"

        onPamMessage: {
            if (responseRequired) {
                respond(root.buffer);
            } else if (messageIsError) {
                root.error = message;
            } else {
                root.info = message;
            }
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.buffer = "";
                root.error = "";
                root.info = "";
                root.unlocked();
                return;
            }
            root.buffer = "";
            root.error = result === PamResult.MaxTries ? "Too many attempts" : result === PamResult.Failed ? "Wrong password" : "Authentication error";
            root.failures++;
        }

        onError: err => {
            root.busy = false;
            root.buffer = "";
            root.error = "PAM: " + PamError.toString(err);
            root.failures++;
        }
    }
}
