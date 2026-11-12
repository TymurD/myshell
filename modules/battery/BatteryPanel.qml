import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Expanded battery: charge, rate, time left, health, power profile (TLP via tlp-pd).
PanelSurface {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 14

        // header: icon, percent, state
        RowLayout {
            spacing: 12
            Icon {
                code: Battery.icon()
                font.pixelSize: 34
                color: Battery.low ? Theme.urgent : Theme.text
            }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Battery.percent + "%"
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: Battery.stateText + (Battery.secondsLeft > 0 ? " · " + Battery.formatDuration(Battery.secondsLeft) + (Battery.charging ? " to full" : " left") : "")
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // charge bar
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.surface
            Rectangle {
                width: parent.width * Battery.percent / 100
                height: parent.height
                radius: parent.radius
                color: Battery.low ? Theme.urgent : Theme.accent
                Behavior on width {
                    NumberAnimation {
                        duration: Anim.normal
                        easing.type: Anim.standard
                    }
                }
            }
        }

        // stats
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 4
            columnSpacing: 12

            component Key: StyledText {
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
            component Val: StyledText {
                Layout.alignment: Qt.AlignRight
                font.pixelSize: Theme.fontSizeSmall
            }

            Key {
                text: "Power draw"
            }
            Val {
                text: Battery.watts > 0 ? Battery.watts.toFixed(1) + " W" : "—"
            }
            Key {
                text: "Energy"
            }
            Val {
                text: Battery.energy.toFixed(1) + " / " + Battery.capacity.toFixed(1) + " Wh"
            }
            Key {
                visible: Battery.healthSupported
                text: "Health"
            }
            Val {
                visible: Battery.healthSupported
                text: Math.round(Battery.health) + "%"
            }
        }

        // power profiles
        StyledText {
            text: "Power profile"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Battery.profiles

                MouseArea {
                    id: btn
                    required property var modelData
                    readonly property bool current: Battery.profile === modelData.id
                    readonly property bool available: modelData.name !== "Performance" || Battery.hasPerformance

                    Layout.fillWidth: true
                    implicitHeight: 52
                    enabled: available
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Battery.setProfile(modelData.id)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: btn.current ? Theme.accent : btn.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.color: btn.current ? Theme.accent : Theme.border
                        border.width: Theme.borderWidth
                        opacity: btn.available ? 1 : 0.4
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.fast
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            code: btn.modelData.icon
                            color: btn.current ? Theme.bgSolid : Theme.text
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            color: btn.current ? Theme.bgSolid : Theme.text
                        }
                    }
                }
            }
        }

        StyledText {
            visible: Battery.degradation !== ""
            text: "Performance limited: " + Battery.degradation
            color: Theme.urgent
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
