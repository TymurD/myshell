import QtQuick
import QtQuick.Layouts
import qs.modules.weather
import qs.components
import qs.services
import qs.theme

// Current conditions: icon, temperature, condition, feels like, high/low, wind, humidity.
Item {
    id: root

    readonly property var c: Weather.current
    readonly property var t: Weather.today

    implicitHeight: col.implicitHeight

    WeatherHold {
        active: root.visible
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        // not configured / error / loading
        RowLayout {
            visible: !root.c
            Layout.fillWidth: true
            spacing: 8
            Icon {
                code: Weather.configured ? 0xF0590 : 0xF034E
                font.pixelSize: Theme.fontSizeLarge
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                text: !Weather.configured ? Weather.setupHint : Weather.error !== "" ? "Weather unavailable: " + Weather.error : "Loading weather…"
            }
        }

        RowLayout {
            visible: !!root.c
            Layout.fillWidth: true
            spacing: 12

            Icon {
                code: root.c?.icon ?? 0
                color: Theme.text
                font.pixelSize: Theme.fontSizeDisplay
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Weather.formatTemp(root.c?.temp) + (Weather.units === "imperial" ? "F" : "C")
                    font.pixelSize: Theme.fontSizeXL
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.c?.text ?? ""
                    color: Theme.textDim
                }
            }
            ColumnLayout {
                spacing: 0
                visible: !!root.t
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: "H " + Weather.formatTemp(root.t?.max)
                    font.pixelSize: Theme.fontSizeSmall
                }
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: "L " + Weather.formatTemp(root.t?.min)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
            }
        }

        RowLayout {
            visible: !!root.c
            Layout.fillWidth: true
            spacing: 6

            Stat {
                icon: 0xF050F
                text: "Feels " + Weather.formatTemp(root.c?.feelsLike)
            }
            Stat {
                icon: 0xF059D
                text: Math.round(root.c?.wind ?? 0) + " " + Weather.windUnit + " " + Weather.windDirText(root.c?.windDir ?? 0)
            }
            Stat {
                icon: 0xF058E
                text: (root.c?.humidity ?? 0) + "%"
            }
        }
    }

    component Stat: RowLayout {
        property int icon
        property string text
        spacing: 4
        Layout.fillWidth: true
        Icon {
            code: parent.icon
            font.pixelSize: Theme.fontSizeSmall
        }
        StyledText {
            text: parent.text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
        }
    }
}
