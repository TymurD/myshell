import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.services
import qs.theme

// Transient "layout switched" overlay, bottom-center of the focused screen.
// No input region, no keyboard focus. Repeated switches restart the hide timer.
Scope {
    id: root

    property bool showing: false

    Connections {
        target: KbLayout
        function onSwitched(full: string): void {
            root.showing = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.showing = false
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.showing || card.opacity > 0
        anchors.bottom: true
        margins.bottom: Theme.barHeight * 3
        implicitWidth: card.implicitWidth + 2 * Theme.panelGap
        implicitHeight: card.implicitHeight + 2 * Theme.panelGap
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "myshell-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: card

            anchors.centerIn: parent
            implicitWidth: row.implicitWidth + 2 * Theme.panelPadding + Theme.itemPadding
            implicitHeight: row.implicitHeight + 2 * Theme.panelPadding
            radius: height / 2
            color: Theme.bgSolid
            border.color: Theme.border
            border.width: Theme.borderWidth

            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.92
            Behavior on opacity {
                NumberAnimation {
                    duration: root.showing ? Anim.fast : Anim.normal
                    easing.type: root.showing ? Anim.standard : Anim.exit
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Anim.normal
                    easing.type: root.showing ? Anim.emphasized : Anim.exit
                }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: Theme.itemPadding

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    code: 0xF030C // nf-md-keyboard
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.text
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: KbLayout.full
                    font.pixelSize: Theme.fontSizeLarge
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: code.implicitWidth + Theme.itemPadding
                    implicitHeight: code.implicitHeight + Theme.panelGap
                    radius: Theme.radiusSmall
                    color: Theme.accent

                    StyledText {
                        id: code
                        anchors.centerIn: parent
                        text: KbLayout.short
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.bgSolid
                    }
                }
            }
        }
    }
}
