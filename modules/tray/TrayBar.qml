import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.theme

// Status-notifier icons. Left click → activate, right click (or menu-only items) → app menu.
BarButton {
    id: root

    hoverHighlight: false
    shown: SystemTray.items.values.length > 0

    Row {
        spacing: 10

        Repeater {
            model: SystemTray.items

            MouseArea {
                id: entry
                required property SystemTrayItem modelData

                width: 18
                height: 18
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                        if (modelData.hasMenu) {
                            const p = entry.mapToItem(null, 0, entry.height);
                            modelData.display(QsWindow.window, p.x, p.y + 8);
                        }
                    } else {
                        modelData.activate();
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    opacity: entry.containsMouse ? 1 : 0.85
                }
            }
        }
    }
}
