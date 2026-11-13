import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.components
import qs.services
import qs.theme

// One notification: image/icon, app · time, summary, body, actions, close.
// Used by toasts (`toast: true`, own background + timeout bar) and the center (flat row).
MouseArea {
    id: root

    required property int uid
    property bool toast: false
    property int bodyLines: Notifications.cfg.bodyMaxLines ?? 4
    property real progress: 1   // toast only: remaining lifetime 1 → 0 (shown as a thin bar)
    readonly property var e: Notifications.entry(uid)
    readonly property bool critical: e?.urgency === NotificationUrgency.Critical
    readonly property bool live: Notifications.liveRev >= 0 && Notifications.canInvoke(uid)
    readonly property string img: Notifications.imageFor(e)

    signal closeClicked

    implicitWidth: 360
    implicitHeight: col.implicitHeight + 2 * pad
    readonly property int pad: toast ? Theme.panelPadding - 4 : 10

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Notifications.hasDefaultAction(uid) && live ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton || !root.live || !Notifications.hasDefaultAction(root.uid)) {
            if (root.toast)
                root.closeClicked();
            return;
        }
        Notifications.invoke(root.uid, "default");
    }

    Rectangle {
        anchors.fill: parent
        radius: root.toast ? Theme.radius : Theme.radiusSmall
        color: root.toast ? Theme.bgPanel : root.containsMouse ? Theme.surfaceHover : Theme.surface
        border.color: root.critical ? Theme.urgent : root.toast ? Theme.border : "transparent"
        border.width: Theme.borderWidth
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }

        // remaining-time bar
        Rectangle {
            visible: root.toast && root.progress < 1
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: parent.radius / 2
            height: 2
            radius: 1
            width: (parent.width - parent.radius) * root.progress
            color: root.critical ? Theme.urgent : Theme.textMuted
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 12

        // image / app icon, falls back to a bell glyph
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.toast ? 44 : 32
            implicitHeight: implicitWidth

            Image {
                id: image
                anchors.fill: parent
                source: root.img
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: status === Image.Ready
            }
            Icon {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                code: root.critical ? 0xF0028 : 0xF009A
                color: root.critical ? Theme.urgent : Theme.textDim
                font.pixelSize: parent.width * 0.6
            }
        }

        ColumnLayout {
            id: col
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: (root.toast ? (root.e?.appName ?? "") + " · " : "") + Notifications.relativeTime(root.e?.time ?? 0, Time.now)
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
                IconButton {
                    code: 0xF0156
                    opacity: root.containsMouse || containsMouse ? 1 : root.toast ? 0.6 : 0
                    onClicked: root.closeClicked()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.e?.summary ?? ""
                font.bold: true
                color: root.critical ? Theme.urgent : Theme.text
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.e?.body ?? ""
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
                textFormat: Text.StyledText
                linkColor: Theme.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.live && (root.e?.actions.length ?? 0) > 0

                Repeater {
                    model: root.live ? (root.e?.actions ?? []) : []

                    MouseArea {
                        id: act
                        required property var modelData
                        implicitWidth: actText.implicitWidth + 2 * Theme.itemPadding
                        implicitHeight: actText.implicitHeight + 10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.invoke(root.uid, modelData.identifier)

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: act.containsMouse ? Theme.surfaceHover : root.toast ? Theme.surface : Theme.bgSolid
                            border.color: Theme.border
                            border.width: Theme.borderWidth
                        }
                        StyledText {
                            id: actText
                            anchors.centerIn: parent
                            text: act.modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }
}
