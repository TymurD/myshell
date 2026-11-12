import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Dialog card for one polkit AuthFlow (or the preview stand-in).
PanelSurface {
    id: root

    property var flow: null
    readonly property bool busy: !(flow?.isResponseRequired ?? false)
    readonly property string error: flow?.supplementaryIsError ? (flow?.supplementaryMessage ?? "") : (flow?.failed ? "Authentication failed" : "")
    readonly property string info: flow?.supplementaryIsError ? "" : (flow?.supplementaryMessage ?? "")

    signal cancelled

    implicitWidth: Theme.barHeight * 13
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding * 1.5

    opacity: 0
    scale: 0.95
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
        input.forceActiveFocus();
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Anim.normal
            easing.type: Anim.standard
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Anim.normal
            easing.type: Anim.emphasized
        }
    }

    function submit(): void {
        if (busy || !flow)
            return;
        flow.submit(input.text);
        input.text = "";
    }

    onErrorChanged: if (error !== "")
        shake.restart()

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding * 1.5
        spacing: Theme.panelPadding

        RowLayout {
            spacing: Theme.itemPadding
            Icon {
                code: 0xF0483 // nf-md-shield-lock
                color: Theme.text
                font.pixelSize: Theme.fontSizeXL
            }
            ColumnLayout {
                spacing: 2
                StyledText {
                    text: "Authentication required"
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: root.flow?.actionId ?? ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.flow?.message ?? ""
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        // identity (click cycles when several are allowed)
        MouseArea {
            id: ident
            readonly property var ids: root.flow?.identities ?? []
            Layout.fillWidth: true
            implicitHeight: identRow.implicitHeight + Theme.panelGap * 2
            enabled: ids.length > 1
            hoverEnabled: enabled
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                const i = ids.indexOf(root.flow.selectedIdentity);
                root.flow.selectedIdentity = ids[(i + 1) % ids.length];
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSmall
                color: ident.containsMouse ? Theme.surfaceHover : Theme.surface
                border.color: Theme.border
                border.width: Theme.borderWidth
            }
            RowLayout {
                id: identRow
                anchors.fill: parent
                anchors.leftMargin: Theme.itemPadding
                anchors.rightMargin: Theme.itemPadding
                spacing: Theme.panelGap
                Icon {
                    code: root.flow?.selectedIdentity?.isGroup ? 0xF0849 : 0xF0004
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.flow?.selectedIdentity?.displayName ?? ""
                    elide: Text.ElideRight
                }
                Icon {
                    visible: ident.enabled
                    code: 0xF04E1 // swap
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // password
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.barHeight * 1.3
            radius: height / 2
            color: Theme.surface
            border.width: Theme.borderWidth
            border.color: root.error !== "" ? Theme.urgent : input.activeFocus ? Theme.borderStrong : Theme.border

            transform: Translate {
                id: shakeOffset
            }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: -Theme.panelGap
                    duration: Anim.fast / 3
                }
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: Theme.panelGap
                    duration: Anim.fast / 3
                }
                NumberAnimation {
                    target: shakeOffset
                    property: "x"
                    to: 0
                    duration: Anim.fast / 3
                }
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: Theme.itemPadding
                anchors.rightMargin: Theme.itemPadding
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                readOnly: root.busy
                echoMode: (root.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.bgSolid
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhHiddenText
                onAccepted: root.submit()
                Keys.onEscapePressed: root.cancelled()

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: root.busy ? "Authenticating…" : (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                    color: Theme.textMuted
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.error !== "" ? root.error : root.info
            color: root.error !== "" ? Theme.urgent : Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.panelGap / 2
            spacing: Theme.panelGap

            Item {
                Layout.fillWidth: true
            }

            component DialogButton: MouseArea {
                id: btn
                property string label
                property bool primary: false
                implicitWidth: lbl.implicitWidth + Theme.itemPadding * 2.5
                implicitHeight: Theme.barHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                opacity: enabled ? 1 : 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: btn.primary ? Theme.accent : btn.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: btn.primary ? Theme.accent : Theme.border
                    border.width: Theme.borderWidth
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }
                StyledText {
                    id: lbl
                    anchors.centerIn: parent
                    text: btn.label
                    color: btn.primary ? Theme.bgSolid : Theme.text
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            DialogButton {
                label: "Cancel"
                onClicked: root.cancelled()
            }
            DialogButton {
                label: root.busy ? "Authenticating…" : "Authenticate"
                primary: true
                enabled: !root.busy && input.text !== ""
                onClicked: root.submit()
            }
        }
    }
}
