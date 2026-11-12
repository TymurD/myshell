import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Notification center: DND + clear all, history grouped by app (collapsible,
// per-app mute + dismiss), muted apps list. Opening it marks everything read.
PanelSurface {
    id: root

    property string panelId: "notifications"
    readonly property bool isOpen: PanelManager.openId === panelId
    readonly property int maxListHeight: Notifications.cfg.centerMaxHeight ?? 620
    property var collapsed: ({})   // appName → true

    implicitWidth: Notifications.cfg.centerWidth ?? 420
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    function markRead(): void {
        if (isOpen)
            Notifications.markAllRead();
    }
    onIsOpenChanged: markRead()
    Component.onCompleted: markRead()
    Connections {
        target: Notifications
        function onUnreadChanged(): void {
            root.markRead();
        }
    }
    Binding {
        target: Notifications
        property: "centerOpen"
        value: root.isOpen
    }

    function toggleGroup(app: string): void {
        const c = Object.assign({}, collapsed);
        if (c[app])
            delete c[app];
        else
            c[app] = true;
        collapsed = c;
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 12

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: "Notifications"
                font.pixelSize: Theme.fontSizeLarge
            }
            StyledText {
                visible: Notifications.count > 0
                text: Notifications.count
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 2
            }
            Item {
                Layout.fillWidth: true
            }
            IconButton {
                code: Notifications.dnd ? 0xF009B : 0xF009C
                label: "DND"
                active: Notifications.dnd
                onClicked: Notifications.toggleDnd()
            }
            IconButton {
                code: 0xF05E9
                label: "Clear all"
                enabled: Notifications.count > 0
                opacity: enabled ? 1 : 0.4
                onClicked: Notifications.clear()
            }
        }

        // ── empty state ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 24
            Layout.bottomMargin: 24
            visible: Notifications.count === 0
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignHCenter
                code: Notifications.dnd ? 0xF009B : 0xF009C
                font.pixelSize: Theme.fontSizeDisplay
                color: Theme.textMuted
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No notifications"
                color: Theme.textDim
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: Notifications.dnd
                text: "Do not disturb is on"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // ── grouped list ──
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(groupsCol.implicitHeight, root.maxListHeight)
            visible: Notifications.count > 0
            contentHeight: groupsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: groupsCol
                width: flick.width
                spacing: 12

                Repeater {
                    model: Notifications.groups

                    Column {
                        id: group
                        required property var modelData
                        readonly property string app: modelData.appName
                        readonly property bool folded: root.collapsed[app] === true
                        readonly property bool muted: Notifications.muted.indexOf(app) !== -1

                        width: groupsCol.width
                        spacing: 6

                        // group header
                        MouseArea {
                            id: head
                            width: parent.width
                            height: headRow.implicitHeight + 4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleGroup(group.app)

                            RowLayout {
                                id: headRow
                                anchors.fill: parent
                                spacing: 8

                                Icon {
                                    code: group.folded ? 0xF0142 : 0xF0140
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                Image {
                                    id: appImg
                                    Layout.preferredWidth: Theme.fontSize
                                    Layout.preferredHeight: Theme.fontSize
                                    sourceSize.width: width * 2
                                    sourceSize.height: height * 2
                                    source: Notifications.iconFor(group.modelData.appIcon)
                                    visible: status === Image.Ready
                                    asynchronous: true
                                }
                                StyledText {
                                    text: group.app
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: head.width * 0.5
                                }
                                StyledText {
                                    text: group.modelData.items.length + (group.folded ? " · " + Notifications.relativeTime(group.modelData.items[0].time, Time.now) : "")
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                IconButton {
                                    // bell-off when muted (click to unmute), bell-outline otherwise
                                    code: group.muted ? 0xF009B : 0xF009C
                                    color: group.muted ? Theme.urgent : Theme.textDim
                                    opacity: group.muted || head.containsMouse || containsMouse ? 1 : 0.5
                                    onClicked: Notifications.toggleMute(group.app)
                                }
                                IconButton {
                                    code: 0xF0156
                                    opacity: head.containsMouse || containsMouse ? 1 : 0.5
                                    onClicked: Notifications.dismissApp(group.app)
                                }
                            }
                        }

                        // items, newest first
                        Column {
                            width: parent.width
                            spacing: 4
                            visible: !group.folded

                            Repeater {
                                model: group.folded ? [] : group.modelData.items

                                NotificationCard {
                                    required property var modelData
                                    uid: modelData.uid
                                    width: parent.width
                                    onCloseClicked: Notifications.dismiss(uid)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── muted apps ──
        ColumnLayout {
            Layout.fillWidth: true
            visible: Notifications.muted.length > 0
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.borderWidth
                color: Theme.border
            }
            StyledText {
                text: "Muted apps"
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Notifications.muted

                    IconButton {
                        required property string modelData
                        code: 0xF009B
                        color: Theme.urgent
                        label: modelData + "  ×"
                        onClicked: Notifications.unmute(modelData)
                    }
                }
            }
        }
    }
}
