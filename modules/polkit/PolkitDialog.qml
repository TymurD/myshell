import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import qs.components
import qs.theme

// Polkit authentication agent + its dialog.
// Only one agent can be registered per session: while polkit-gnome (or another agent)
// runs, registration fails and we log a single warning and stay idle.
// IPC: `polkit preview` shows the dialog with a fake request (any password → error).
Scope {
    id: root

    property bool previewing: false
    readonly property bool shown: agent.isActive || previewing
    readonly property var flow: previewing ? fake : agent.flow

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: root.previewing = false
    }

    // If another agent (polkit-gnome) owns the session, Quickshell itself logs one
    // "failed to register listener" warning and the agent stays idle; nothing to do here.

    // Stand-in for AuthFlow in preview mode: same properties, submit always fails.
    QtObject {
        id: fake
        readonly property string message: "Authentication is needed to run `/usr/bin/true' as the super user"
        readonly property string actionId: "org.freedesktop.policykit.exec"
        readonly property string iconName: ""
        readonly property var selectedIdentity: ({
                displayName: Quickshell.env("USER") ?? "user",
                isGroup: false
            })
        readonly property var identities: [selectedIdentity]
        property bool isResponseRequired: true
        readonly property string inputPrompt: "Password:"
        readonly property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property bool failed: false

        function submit(value: string): void {
            isResponseRequired = false;
            fakeReply.restart();
        }
        function cancelAuthenticationRequest(): void {
            root.previewing = false;
        }
        function reset(): void {
            isResponseRequired = true;
            supplementaryMessage = "";
            supplementaryIsError = false;
            failed = false;
        }
    }

    Timer {
        id: fakeReply
        interval: Anim.slow * 3
        onTriggered: {
            fake.failed = true;
            fake.supplementaryMessage = "Authentication failed (preview)";
            fake.supplementaryIsError = true;
            fake.isResponseRequired = true;
        }
    }

    IpcHandler {
        target: "polkit"

        function preview(): void {
            if (agent.isActive)
                return;
            fake.reset();
            root.previewing = true;
        }
        function cancel(): void {
            root.flow?.cancelAuthenticationRequest();
        }
        function status(): string {
            return agent.isRegistered ? (agent.isActive ? "active" : "registered") : "not registered";
        }
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "myshell-polkit"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // dim the rest of the screen
            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Anim.normal
                        easing.type: Anim.standard
                    }
                }
                MouseArea {
                    anchors.fill: parent
                }
            }

            PolkitCard {
                anchors.centerIn: parent
                flow: root.flow
                onCancelled: root.flow?.cancelAuthenticationRequest()
            }
        }
    }
}
