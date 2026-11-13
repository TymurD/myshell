import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Expanded brightness: percent, draggable slider, -/+ and presets.
PanelSurface {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    component StepButton: MouseArea {
        id: b
        property int code
        property string label
        property bool active: false

        implicitWidth: 40
        implicitHeight: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: b.active ? Theme.accent : b.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: b.active ? Theme.accent : Theme.border
            border.width: Theme.borderWidth
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
        }
        Icon {
            visible: b.label === ""
            anchors.centerIn: parent
            code: b.code
        }
        StyledText {
            visible: b.label !== ""
            anchors.centerIn: parent
            text: b.label
            font.pixelSize: Theme.fontSizeSmall
            color: b.active ? Theme.bgSolid : Theme.text
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 14

        // header
        RowLayout {
            spacing: 12
            Icon {
                code: Brightness.icon()
                font.pixelSize: 34
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: (slider.pressed ? Math.round(slider.dragFrac * 100) : Brightness.percent) + "%"
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    // Long device names must not widen the layout past the panel padding.
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    elide: Text.ElideRight
                    text: "Screen brightness · " + Brightness.device
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // slider row: - [====o----] +
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            StepButton {
                code: 0xF0374 // minus
                onClicked: Brightness.down()
            }

            MouseArea {
                id: slider

                property real dragFrac: 0
                readonly property real shownFrac: pressed ? dragFrac : Brightness.percent / 100

                function fracAt(x: real): real {
                    return Math.max(0, Math.min(1, x / width));
                }

                Layout.fillWidth: true
                implicitHeight: 24
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: mouse => {
                    dragFrac = fracAt(mouse.x);
                    Brightness.setPercent(dragFrac * 100);
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    dragFrac = fracAt(mouse.x);
                    Brightness.setPercent(dragFrac * 100);
                }
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0)
                        Brightness.up();
                    else if (wheel.angleDelta.y < 0)
                        Brightness.down();
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: slider.containsMouse || slider.pressed ? 8 : 6
                    radius: height / 2
                    color: Theme.surface
                    Behavior on height {
                        NumberAnimation {
                            duration: Anim.fast
                        }
                    }

                    Rectangle {
                        width: parent.width * slider.shownFrac
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        Behavior on width {
                            enabled: !slider.pressed
                            NumberAnimation {
                                duration: Anim.normal
                                easing.type: Anim.standard
                            }
                        }
                    }
                }
                Rectangle {
                    x: slider.width * slider.shownFrac - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.accent
                    visible: slider.containsMouse || slider.pressed
                }
            }

            StepButton {
                code: 0xF0415 // plus
                onClicked: Brightness.up()
            }
        }

        // presets
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [10, 25, 50, 75, 100]

                StepButton {
                    required property int modelData
                    Layout.fillWidth: true
                    label: modelData + "%"
                    active: Brightness.percent === modelData
                    onClicked: Brightness.setPercent(modelData)
                }
            }
        }
    }
}
