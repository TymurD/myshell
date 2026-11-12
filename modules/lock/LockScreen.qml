import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.theme

// Session lock (ext-session-lock via WlSessionLock) + PAM, one surface per screen.
// IPC: `lock lock` locks for real, `lock preview` shows the same UI in a plain
// overlay window without a session lock (Esc or a correct password closes it).
// Hyprland: set misc.allow_session_lock_restore = true before relying on this.
Scope {
    id: root

    property bool previewing: false

    function lock(): void {
        if (sessionLock.locked)
            return;
        previewing = false;
        ctx.reset();
        sessionLock.locked = true;
    }

    function preview(): void {
        if (sessionLock.locked)
            return;
        ctx.reset();
        previewing = true;
    }

    LockContext {
        id: ctx
        onUnlocked: {
            if (sessionLock.locked)
                sessionLock.locked = false;
            root.previewing = false;
        }
    }

    Connections {
        target: Session
        function onLockRequested() {
            root.lock();
        }
        function onLockPreviewRequested() {
            root.preview();
        }
    }

    Binding {
        target: Session
        property: "locked"
        value: sessionLock.locked
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Theme.bgSolid

            LockContent {
                anchors.fill: parent
                context: ctx
                screen: surface.screen
            }
        }
    }

    // Preview: identical UI in a normal fullscreen overlay, no session lock.
    LazyLoader {
        active: root.previewing

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win
                required property ShellScreen modelData
                screen: modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "myshell-lock-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                LockContent {
                    anchors.fill: parent
                    context: ctx
                    screen: win.modelData
                    preview: true
                    onEscapePressed: {
                        ctx.reset();
                        root.previewing = false;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Session.lock();
        }
        function preview(): void {
            root.preview();
        }
        function closePreview(): void {
            ctx.reset();
            root.previewing = false;
        }
    }
}
