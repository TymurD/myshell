import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Notification center: DND + clear all, history grouped by app (collapsible,
// per-app mute + dismiss), muted apps list. Opening it marks everything read.
// Height is set by the overlay (placement.fillHeight: down to the bottom gap); the
// list takes whatever is left.
PanelSurface {
    id: root

    property string panelId: "notifications"
    readonly property bool isOpen: PanelManager.openId === panelId
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
            // deferred: marking read inside unread's own change handler re-evaluates
            // `unread` mid-update (binding loop)
            Qt.callLater(root.markRead);
        }
    }
    Binding {
        target: Notifications
        property: "centerOpen"
        value: root.isOpen
    }

    // Removals animate first (slide right + fade, then collapse) and only then touch the
    // service: the Repeaters below use plain arrays, so any history change rebuilds every
    // delegate. A delegate rebuilt mid-removal sees its key here and starts leaving again.
    property var leaving: ({})       // uid → true
    property var leavingApps: ({})   // appName → true
    property bool clearing: false
    property int clearedGroups: 0

    function removeItem(uid: int): void {
        leaving = Object.assign({}, leaving, { [uid]: true });
    }
    function removeApp(app: string): void {
        leavingApps = Object.assign({}, leavingApps, { [app]: true });
    }
    function clearAll(): void {
        clearedGroups = 0;
        clearing = true;
    }
    function itemGone(uid: int): void {
        const l = Object.assign({}, leaving);
        delete l[uid];
        leaving = l;
        Qt.callLater(Notifications.dismiss, uid);
    }
    function groupGone(app: string): void {
        if (clearing) {
            if (++clearedGroups >= Notifications.groups.length) {
                clearing = false;
                Qt.callLater(Notifications.clear);
            }
            return;
        }
        const l = Object.assign({}, leavingApps);
        delete l[app];
        leavingApps = l;
        Qt.callLater(Notifications.dismissApp, app);
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
                enabled: Notifications.count > 0 && !root.clearing
                opacity: enabled ? 1 : 0.4
                onClicked: root.clearAll()
            }
        }

        // ── empty state: a full-size box with its content centred both ways ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Notifications.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    code: Notifications.dnd ? 0xF009B : 0xF009C
                    font.pixelSize: Theme.fontSizeDisplay
                    color: Theme.textMuted
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No notifications"
                    color: Theme.textDim
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Notifications.dnd
                    text: "Do not disturb is on"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ── grouped list ──
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
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

                    Item {
                        id: group
                        required property var modelData
                        required property int index
                        readonly property string app: modelData.appName
                        readonly property bool folded: root.collapsed[app] === true
                        readonly property bool muted: Notifications.muted.indexOf(app) !== -1
                        readonly property bool leaving: root.clearing || root.leavingApps[app] === true
                        property real shrink: 1

                        width: groupsCol.width
                        height: body.implicitHeight * shrink
                        clip: true

                        function leave(): void {
                            // clear all: groups leave one after another, top first
                            groupOut.delay = root.clearing ? Math.min(index, 8) * Anim.stagger : 0;
                            groupOut.start();
                        }
                        onLeavingChanged: if (leaving) leave()
                        Component.onCompleted: if (leaving) leave()

                        SequentialAnimation {
                            id: groupOut
                            property int delay: 0
                            PauseAnimation {
                                duration: groupOut.delay
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: body
                                    property: "x"
                                    to: group.width
                                    duration: Anim.normal
                                    easing.type: Anim.exit
                                }
                                NumberAnimation {
                                    target: body
                                    property: "opacity"
                                    to: 0
                                    duration: Anim.normal
                                    easing.type: Anim.exit
                                }
                            }
                            NumberAnimation {
                                target: group
                                property: "shrink"
                                to: 0
                                duration: Anim.fast
                                easing.type: Anim.standard
                            }
                            ScriptAction {
                                script: root.groupGone(group.app)
                            }
                        }

                        Column {
                            id: body
                            width: parent.width
                            spacing: 6
                            enabled: !group.leaving

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
                                        onClicked: root.removeApp(group.app)
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

                                    Item {
                                        id: slot
                                        required property var modelData
                                        readonly property bool leaving: root.leaving[modelData.uid] === true
                                        property real shrink: 1

                                        width: parent.width
                                        height: card.implicitHeight * shrink
                                        clip: true

                                        onLeavingChanged: if (leaving) cardOut.start()
                                        Component.onCompleted: if (leaving) cardOut.start()

                                        NotificationCard {
                                            id: card
                                            uid: slot.modelData.uid
                                            width: parent.width
                                            enabled: !slot.leaving
                                            onCloseClicked: root.removeItem(uid)
                                        }

                                        SequentialAnimation {
                                            id: cardOut
                                            ParallelAnimation {
                                                NumberAnimation {
                                                    target: card
                                                    property: "x"
                                                    to: slot.width
                                                    duration: Anim.normal
                                                    easing.type: Anim.exit
                                                }
                                                NumberAnimation {
                                                    target: card
                                                    property: "opacity"
                                                    to: 0
                                                    duration: Anim.normal
                                                    easing.type: Anim.exit
                                                }
                                            }
                                            NumberAnimation {
                                                target: slot
                                                property: "shrink"
                                                to: 0
                                                duration: Anim.fast
                                                easing.type: Anim.standard
                                            }
                                            ScriptAction {
                                                script: root.itemGone(slot.modelData.uid)
                                            }
                                        }
                                    }
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
