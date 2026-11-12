import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.theme

// Toast stack, top-right below the bar, on the focused monitor (or settings → notifications.monitor).
// Instantiated once from shell.qml. Also hosts the `notifications` IPC target.
Scope {
    id: root

    readonly property int toastWidth: Notifications.cfg.toastWidth ?? 380

    function pickScreen(): var {
        const name = Notifications.monitor === "focused" ? (Hyprland.focusedMonitor?.name ?? "") : Notifications.monitor;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i];
        return screens[0] ?? null;
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            Notifications.toggleDnd();
        }
        function clear(): void {
            Notifications.clear();
        }
        function mute(app: string): void {
            Notifications.mute(app);
        }
        function unmute(app: string): void {
            Notifications.unmute(app);
        }
        // Run an action ("default" = click) on the newest notification that still accepts it.
        function invokeLatest(action: string): void {
            Notifications.invokeLatest(action);
        }
        function status(): string {
            return JSON.stringify({
                dnd: Notifications.dnd,
                unread: Notifications.unread,
                count: Notifications.count,
                toasts: Notifications.toasts.count,
                muted: Notifications.muted
            });
        }
    }

    PanelWindow {
        id: win

        // Keep the window alive briefly after the last toast so it can slide out.
        property bool lingering: false
        visible: Notifications.toasts.count > 0 || lingering

        anchors {
            top: true
            right: true
            bottom: true
        }
        implicitWidth: root.toastWidth + 2 * Theme.barMargin
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "myshell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: list
        }

        // Follow the chosen monitor, but don't jump while toasts are on screen.
        Binding {
            target: win
            property: "screen"
            value: root.pickScreen()
            when: Notifications.toasts.count === 0 && !win.lingering
            restoreMode: Binding.RestoreNone
        }

        Connections {
            target: Notifications.toasts
            function onCountChanged(): void {
                if (Notifications.toasts.count === 0) {
                    win.lingering = true;
                    linger.restart();
                }
            }
        }
        Timer {
            id: linger
            interval: Anim.normal + Anim.fast
            onTriggered: win.lingering = false
        }

        ListView {
            id: list
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.barMargin + Theme.barHeight + Theme.panelGap
            anchors.rightMargin: Theme.barMargin
            width: root.toastWidth
            height: Math.min(contentHeight, win.height - anchors.topMargin)
            spacing: Theme.panelGap
            interactive: false
            model: Notifications.toasts

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "x"
                        from: root.toastWidth + Theme.barMargin
                        to: 0
                        duration: Anim.normal
                        easing.type: Anim.standard
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Anim.normal
                    }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "x"
                        to: root.toastWidth + Theme.barMargin
                        duration: Anim.normal
                        easing.type: Anim.exit
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Anim.normal
                    }
                }
            }
            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Anim.normal
                    easing.type: Anim.standard
                }
                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Anim.fast
                }
            }

            delegate: NotificationCard {
                id: card
                readonly property int timeout: Notifications.toastTimeout(e)

                width: ListView.view.width
                toast: true
                onCloseClicked: Notifications.expireToast(uid)

                // Lifetime: progress runs 1 → 0, paused while hovered.
                NumberAnimation on progress {
                    running: card.timeout > 0
                    paused: running && card.containsMouse
                    from: 1
                    to: 0
                    duration: card.timeout
                    onFinished: Notifications.expireToast(card.uid)
                }
            }
        }
    }
}
