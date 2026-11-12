import QtQuick
import QtQuick.Layouts
import qs.modules.weather
import qs.components
import qs.services
import qs.theme

// 7-day forecast: day, icon, rain chance, low, range bar (relative to the week), high.
Item {
    id: root

    readonly property var days: Weather.daily
    readonly property real weekMin: days.length ? Math.min(...days.map(d => d.min)) : 0
    readonly property real weekMax: days.length ? Math.max(...days.map(d => d.max)) : 1

    implicitHeight: col.implicitHeight

    WeatherHold {
        active: root.visible
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 4

        RowLayout {
            spacing: 8
            Icon {
                code: 0xF00ED
                color: Theme.text
            }
            StyledText {
                text: "7-day forecast"
            }
        }

        StyledText {
            visible: root.days.length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            text: !Weather.configured ? Weather.setupHint : Weather.error !== "" ? "Forecast unavailable: " + Weather.error : "Loading forecast…"
        }

        Repeater {
            model: root.days

            RowLayout {
                id: day
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.preferredWidth: 46
                    text: day.index === 0 ? "Today" : Qt.locale().dayName(day.modelData.date.getDay(), Locale.ShortFormat)
                    font.pixelSize: Theme.fontSizeSmall
                    color: day.index === 0 ? Theme.text : Theme.textDim
                }
                Icon {
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignHCenter
                    code: day.modelData.icon
                    color: Theme.text
                }
                StyledText {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: day.modelData.precip ? day.modelData.precip + "%" : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
                StyledText {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Weather.formatTemp(day.modelData.min)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.textFaint
                    }
                    Rectangle {
                        readonly property real span: Math.max(1, root.weekMax - root.weekMin)
                        x: parent.width * (day.modelData.min - root.weekMin) / span
                        width: Math.max(height, parent.width * (day.modelData.max - day.modelData.min) / span)
                        height: parent.height
                        radius: height / 2
                        color: Theme.accent
                    }
                }
                StyledText {
                    Layout.preferredWidth: 34
                    text: Weather.formatTemp(day.modelData.max)
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
