import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

// The lock UI for one screen. Used by the real session lock surface and by the preview window.
Item {
    id: root

    required property LockContext context
    property var screen: null
    property bool preview: false

    signal escapePressed

    // Blurred, dimmed snapshot of the screen behind (settings.json → lock.screencopy, default true).
    Rectangle {
        anchors.fill: parent
        color: Theme.bgSolid
    }

    ScreencopyView {
        id: shot
        anchors.fill: parent
        visible: false
        captureSource: (Config.lock?.screencopy ?? true) ? root.screen : null
        live: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.hasContent
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            NumberAnimation {
                duration: Anim.slow
                easing.type: Anim.standard
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Column {
        id: col
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -height / 6
        spacing: Theme.panelPadding

        opacity: 0
        scale: 0.96
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Anim.slow
                easing.type: Anim.standard
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Anim.slow
                easing.type: Anim.standard
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format(Config.clock?.format ?? "HH:mm")
            font.pixelSize: Theme.fontSizeHuge
            font.weight: Font.Bold
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("dddd, d MMMM")
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeLarge
        }

        Item {
            width: 1
            height: Theme.panelPadding * 2
        }

        // password field
        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.barHeight * 11
            height: Theme.barHeight * 1.5
            radius: height / 2
            color: Theme.surface
            border.width: Theme.borderWidth
            border.color: root.context.error !== "" ? Theme.urgent : input.activeFocus ? Theme.borderStrong : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }

            transform: Translate {
                id: shakeOffset
            }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: -Theme.panelGap * 1.5
                    duration: Anim.fast / 3
                    easing.type: Anim.standard
                }
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: Theme.panelGap * 1.5
                    duration: Anim.fast / 3
                    easing.type: Anim.standard
                }
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: 0
                    duration: Anim.fast / 3
                    easing.type: Anim.standard
                }
            }

            Connections {
                target: root.context
                function onFailuresChanged() {
                    shake.restart();
                }
                function onBufferChanged() {
                    if (input.text !== root.context.buffer)
                        input.text = root.context.buffer;
                }
            }

            Icon {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.itemPadding + Theme.panelGap / 2
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF033E
                color: root.context.error !== "" ? Theme.urgent : root.context.busy ? Theme.text : Theme.textDim

                SequentialAnimation on opacity {
                    running: root.context.busy
                    loops: Animation.Infinite
                    onRunningChanged: if (!running)
                        lockIcon.opacity = 1
                    NumberAnimation {
                        to: 0.3
                        duration: Anim.slow
                        easing.type: Anim.standard
                    }
                    NumberAnimation {
                        to: 1
                        duration: Anim.slow
                        easing.type: Anim.standard
                    }
                }
            }

            TextInput {
                id: input

                anchors.left: lockIcon.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.panelGap * 1.5
                anchors.rightMargin: Theme.itemPadding * 2
                anchors.verticalCenter: parent.verticalCenter

                focus: true
                readOnly: root.context.busy
                echoMode: TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.bgSolid
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.letterSpacing: 2
                clip: true
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText

                onTextEdited: {
                    root.context.buffer = text;
                    if (root.context.error !== "")
                        root.context.error = "";
                }
                onAccepted: root.context.submit()
                Keys.onEscapePressed: {
                    if (text !== "")
                        root.context.buffer = "";
                    else
                        root.escapePressed();
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: root.context.busy ? "Checking…" : "Password"
                    color: Theme.textMuted
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property string msg: root.context.error !== "" ? root.context.error : root.context.info
            text: msg !== "" ? msg : root.preview ? "Preview · Esc to close" : " "
            color: root.context.error !== "" ? Theme.urgent : Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Component.onCompleted: input.forceActiveFocus()
}
