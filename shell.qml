//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.core

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
}
