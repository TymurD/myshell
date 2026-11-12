import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme
import qs.modules.launcher

// Clipboard history (cliphist), attached left of the launcher.
// Up/Down select, Enter/click copies back, Delete removes, Right (at the end of
// the input) / Tab goes back to the launcher, Esc closes both.
PanelSurface {
    id: root

    property string panelId: "clipboard"
    readonly property bool focused: PanelManager.focusId === panelId

    implicitWidth: 420
    implicitHeight: 520
    border.color: focused ? Theme.borderStrong : Theme.border

    function copy(e: var): void {
        if (!e)
            return;
        Clipboard.copy(e.id);
        PanelManager.close();
    }

    Connections {
        target: PanelManager
        function onOpenIdChanged(): void {
            if (PanelManager.isShowing(root.panelId)) {
                search.text = "";
                list.currentIndex = 0;
                Clipboard.refresh();
            }
        }
    }
    Component.onCompleted: Clipboard.refresh()

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            PanelManager.focus(root.panelId);
            mouse.accepted = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: Theme.panelGap + 4

        SearchField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search clipboard"
            iconCode: 0xF014C // nf-md-clipboard_outline
            focus: true
            onActivated: PanelManager.focus(root.panelId)
            onTextChanged: list.currentIndex = 0

            onKeyPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                    list.incrementCurrentIndex();
                    break;
                case Qt.Key_Up:
                    list.decrementCurrentIndex();
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.copy(clipModel.values[list.currentIndex]);
                    break;
                case Qt.Key_Delete:
                    if (search.text !== "" && search.input.cursorPosition < search.text.length)
                        return;
                    if (clipModel.values[list.currentIndex])
                        Clipboard.remove(clipModel.values[list.currentIndex].id);
                    break;
                case Qt.Key_Tab:
                case Qt.Key_Backtab:
                    PanelManager.focus(PanelManager.openId);
                    break;
                case Qt.Key_Right:
                    if (search.input.cursorPosition !== search.text.length || !PanelManager.moveFocus("right"))
                        return;
                    break;
                case Qt.Key_Left:
                    if (search.input.cursorPosition !== 0 || !PanelManager.moveFocus("left"))
                        return;
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Clipboard.available
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Anim.fast
            highlightMoveVelocity: -1
            highlightResizeDuration: Anim.fast
            keyNavigationEnabled: false

            model: ScriptModel {
                id: clipModel
                objectProp: "id"
                values: Clipboard.filter(search.text)
            }

            highlight: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: Theme.border
                border.width: Theme.borderWidth
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Anim.normal
                    easing.type: Anim.standard
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Anim.fast
                    easing.type: Anim.exit
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

            delegate: MouseArea {
                id: row
                required property var modelData
                required property int index
                readonly property string thumb: Clipboard.thumbs[modelData.id] ?? ""

                width: ListView.view.width
                height: modelData.image ? 92 : Math.max(44, label.implicitHeight + 2 * Theme.panelGap + 4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onEntered: list.currentIndex = index
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        Clipboard.remove(modelData.id);
                    else
                        root.copy(modelData);
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.itemPadding - 4
                    anchors.rightMargin: Theme.panelGap
                    spacing: Theme.itemPadding - 4

                    Rectangle {
                        visible: row.modelData.image
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 76
                        radius: Theme.radiusSmall
                        color: Theme.surface
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: row.thumb ? "file://" + row.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 240
                            cache: false
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Anim.normal
                                }
                            }
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !row.thumb
                            code: 0xF02E9 // nf-md-image
                        }
                    }

                    StyledText {
                        id: label
                        Layout.fillWidth: true
                        text: row.modelData.image ? row.modelData.info : row.modelData.text
                        color: row.modelData.image ? Theme.textDim : Theme.text
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        // delete button, shown on hover / selection
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        opacity: row.containsMouse || row.ListView.isCurrentItem ? 1 : 0
                        onClicked: Clipboard.remove(row.modelData.id)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Anim.fast
                            }
                        }
                        Icon {
                            anchors.centerIn: parent
                            code: 0xF09E7 // nf-md-delete_outline
                            color: parent.containsMouse ? Theme.urgent : Theme.textDim
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0 && !Clipboard.loading
                text: search.text ? "No matches" : "Clipboard history is empty"
                color: Theme.textDim
            }
        }

        // cliphist missing
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Clipboard.available
            spacing: Theme.panelGap

            Item {
                Layout.fillHeight: true
            }
            Icon {
                Layout.alignment: Qt.AlignHCenter
                code: 0xF014C
                font.pixelSize: Theme.fontSizeDisplay
                color: Theme.textMuted
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No clipboard history"
                font.pixelSize: Theme.fontSizeLarge
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: "Install cliphist and add\nwl-paste --watch cliphist store\nto hyprland.lua"
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}
