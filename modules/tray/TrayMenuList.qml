import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.theme
import qs.modules.tray

// Entries of one DBusMenu level. Submenus expand inline (recursively) under
// their entry, indented. `triggered` bubbles up so the popup can close.
Column {
    id: root

    property var handle          // QsMenuHandle (tray item's menu, or a submenu entry)
    property int depth: 0

    signal triggered

    readonly property int count: entries.count

    spacing: 1

    QsMenuOpener {
        id: opener
        menu: root.handle
    }

    Repeater {
        id: entries
        model: opener.children
        // A Column only lays out on polish, which never happens while the menu window is
        // still hidden; TrayMenu waits for a real height before mapping, so force it.
        onItemAdded: Qt.callLater(root.forceLayout)
        onItemRemoved: Qt.callLater(root.forceLayout)

        Item {
            id: entry

            required property QsMenuEntry modelData
            property bool expanded: false

            width: root.width
            height: modelData.isSeparator ? 9 : row.height + (sub.item?.height ?? 0)

            // separator
            Rectangle {
                visible: entry.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                x: Theme.panelGap
                width: parent.width - 2 * Theme.panelGap
                height: Theme.borderWidth
                color: Theme.border
            }

            MouseArea {
                id: row

                visible: !entry.modelData.isSeparator
                width: parent.width
                height: 30
                hoverEnabled: true
                enabled: entry.modelData.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (entry.modelData.hasChildren) {
                        entry.expanded = !entry.expanded;
                    } else {
                        entry.modelData.triggered();
                        root.triggered();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: row.containsMouse ? Theme.surfaceHover : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Anim.fast
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.panelGap + root.depth * 14
                    spacing: 8
                    opacity: entry.modelData.enabled ? 1 : 0.4

                    // check / radio indicator
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.buttonType !== QsMenuButtonType.None
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                        code: {
                            const on = entry.modelData.checkState === Qt.Checked;
                            if (entry.modelData.buttonType === QsMenuButtonType.RadioButton)
                                return on ? 0xF043E : 0xF0130; // radiobox-marked / -blank
                            return on ? 0xF0C52 : 0xF0131;     // checkbox-marked / -blank-outline
                        }
                    }
                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.icon !== ""
                        source: entry.modelData.icon
                        implicitSize: 16
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.text.replace(/_(?!_)/g, "")
                        font.pixelSize: Theme.fontSizeSmall + 1
                        width: Math.min(implicitWidth, 320)
                        elide: Text.ElideRight
                    }
                }

                Icon {
                    visible: entry.modelData.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.panelGap
                    anchors.verticalCenter: parent.verticalCenter
                    code: entry.expanded ? 0xF0140 : 0xF0142 // chevron down / right
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Loader {
                id: sub
                anchors.top: row.bottom
                width: parent.width
                // by URL: QML refuses a type that instantiates itself directly
                active: entry.expanded
                onActiveChanged: if (active)
                    setSource(Qt.resolvedUrl("TrayMenuList.qml"), {
                        width: Qt.binding(() => entry.width),
                        handle: entry.modelData,
                        depth: root.depth + 1
                    })
                Connections {
                    target: sub.item
                    function onTriggered(): void {
                        root.triggered();
                    }
                }
            }
        }
    }
}
