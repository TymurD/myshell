//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.core
import qs.modules.lock
import qs.modules.polkit
import qs.modules.notifications
import qs.modules.keyboard

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            BarWindow {
                id: bar
                screen: perScreen.modelData
            }

            OverlayWindow {
                screen: perScreen.modelData
                barWindow: bar
            }
        }
    }

    Ipc {}

    // Global singletons-with-UI. Each lives in its module folder and may
    // declare its own IpcHandler there.
    LockScreen {}
    PolkitDialog {}
    NotificationPopups {}
    KeyboardOsd {}
}
