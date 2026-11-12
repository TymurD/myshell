import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.core
import qs.services
import qs.theme

// App launcher: fuzzy search over desktop entries, ranked by match + frecency.
// Up/Down select, Enter launches, Left (at the start of the input) / Tab moves to
// the attached clipboard panel, Esc closes (handled by OverlayWindow).
PanelSurface {
    id: root

    property string panelId: "launcher"
    readonly property bool focused: PanelManager.focusId === panelId

    implicitWidth: 560
    implicitHeight: 520
    border.color: focused && PanelManager.attachedId !== "" ? Theme.borderStrong : Theme.border

    function launch(entry: var): void {
        Apps.launch(entry);
        PanelManager.close();
    }

    function reset(): void {
        search.text = "";
        list.currentIndex = 0;
        list.positionViewAtBeginning();
    }

    Connections {
        target: PanelManager
        function onOpenIdChanged(): void {
            if (PanelManager.openId === root.panelId)
                root.reset();
        }
    }

    MouseArea {
        // clicking anywhere in the panel gives it keyboard focus
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
            placeholder: "Search apps"
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
                case Qt.Key_PageDown:
                    list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8);
                    break;
                case Qt.Key_PageUp:
                    list.currentIndex = Math.max(0, list.currentIndex - 8);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.launch(appsModel.values[list.currentIndex]);
                    break;
                case Qt.Key_Tab:
                case Qt.Key_Backtab:
                    PanelManager.moveFocus(PanelManager.attachedSide);
                    break;
                case Qt.Key_Left:
                    if (search.input.cursorPosition !== 0 || search.input.selectedText !== "" || !PanelManager.moveFocus("left"))
                        return;
                    break;
                case Qt.Key_Right:
                    if (search.input.cursorPosition !== search.text.length || !PanelManager.moveFocus("right"))
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
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Anim.fast
            highlightMoveVelocity: -1
            highlightResizeDuration: 0
            keyNavigationEnabled: false

            model: ScriptModel {
                id: appsModel
                values: Apps.query(search.text)
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
                NumberAnimation {
                    property: "scale"
                    from: 0.96
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
                    properties: "opacity,scale"
                    to: 1
                    duration: Anim.fast
                }
            }

            delegate: MouseArea {
                id: row
                required property var modelData
                required property int index

                width: ListView.view.width
                height: 52
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: list.currentIndex = index
                onClicked: root.launch(modelData)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.itemPadding - 4
                    anchors.rightMargin: Theme.itemPadding - 4
                    spacing: Theme.itemPadding - 2

                    IconImage {
                        implicitSize: 32
                        asynchronous: true
                        source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.genericName || row.modelData.comment
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No matching apps"
                color: Theme.textDim
            }
        }
    }
}
