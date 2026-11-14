import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell
import qs.modules.settings
import qs.components
import qs.config
import qs.core
import qs.theme

// Settings: edits the user's overrides (Config.set → ~/.config/myshell/settings.json).
// Every change applies immediately; values equal to the defaults are dropped from the
// user file, and each section's Reset removes its overrides.
PanelSurface {
    id: root

    property string panelId

    readonly property var spots: ["edge-left", "pill", "edge-right"]

    implicitWidth: content.implicitWidth + 2 * Theme.panelPadding
    implicitHeight: Math.min(content.implicitHeight + 2 * Theme.panelPadding, Screen.height * 0.8)

    FolderListModel {
        id: palettes
        folder: "file://" + Quickshell.shellPath("palettes")
        nameFilters: ["*.json"]
        showDirs: false
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        contentWidth: content.implicitWidth
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: implicitWidth
            spacing: Theme.panelPadding * 1.5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.panelGap

                Icon {
                    code: 0xF0493 // nf-md-cog
                    color: Theme.text
                    font.pixelSize: Theme.fontSizeLarge
                }
                StyledText {
                    text: "Settings"
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: Config.userPath.replace(Quickshell.env("HOME"), "~")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Rectangle {
                visible: Config.userFileBroken
                Layout.fillWidth: true
                implicitHeight: warn.implicitHeight + Theme.panelPadding
                radius: Theme.radiusSmall
                color: "transparent"
                border.color: Theme.urgent
                border.width: Theme.borderWidth

                StyledText {
                    id: warn
                    anchors.centerIn: parent
                    text: "settings.json has a syntax error. Fix it to save changes."
                    color: Theme.urgent
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Section {
                title: "Bar layout"
                paths: ["bar.left", "bar.center", "bar.right"]

                ListEditor {
                    columns: [
                        {
                            title: "Left",
                            path: "bar.left"
                        },
                        {
                            title: "Center",
                            path: "bar.center"
                        },
                        {
                            title: "Right",
                            path: "bar.right"
                        }
                    ]
                    allIds: Object.keys(Registry.modules)
                }
            }

            Section {
                title: "Panel position per pill"
                paths: ["bar.panelAt"]

                Repeater {
                    model: ["left", "center", "right"]

                    OptionRow {
                        id: spotRow
                        required property string modelData
                        label: modelData.charAt(0).toUpperCase() + modelData.slice(1) + " pill"
                        path: "bar.panelAt." + modelData

                        Repeater {
                            model: root.spots

                            Chip {
                                required property string modelData
                                text: modelData
                                checked: (Config.bar.panelAt?.[spotRow.modelData] ?? "") === modelData
                                onClicked: Config.set(spotRow.path, modelData)
                            }
                        }
                    }
                }
            }

            Section {
                title: "Dashboard cards"
                paths: ["dashboard.left", "dashboard.right"]

                ListEditor {
                    columns: [
                        {
                            title: "Left column",
                            path: "dashboard.left"
                        },
                        {
                            title: "Right column",
                            path: "dashboard.right"
                        }
                    ]
                    allIds: Object.keys(Registry.cards)
                }
            }

            Section {
                title: "General"
                paths: ["palette", "clock.format", "workspaces.persistent", "network.showSpeed", "session.dryRun"]

                OptionRow {
                    label: "Palette"
                    path: "palette"

                    Repeater {
                        model: palettes

                        Chip {
                            required property string fileBaseName
                            text: fileBaseName
                            checked: Config.palette === fileBaseName
                            onClicked: Config.set("palette", fileBaseName)
                        }
                    }
                }

                OptionRow {
                    label: "Clock format (Enter to apply)"
                    path: "clock.format"

                    TextBox {
                        id: clockFormat
                        implicitWidth: Theme.barHeight * 5
                        placeholder: "HH:mm"
                        text: Config.clock.format ?? ""
                        onAccepted: if (text.trim() !== "")
                            Config.set("clock.format", text.trim())
                    }
                }

                OptionRow {
                    id: wsRow
                    label: "Persistent workspaces"
                    path: "workspaces.persistent"

                    readonly property int value: Config.workspaces.persistent ?? 6

                    IconButton {
                        icon: 0xF0374 // nf-md-minus
                        enabled: wsRow.value > 1
                        onClicked: Config.set("workspaces.persistent", wsRow.value - 1)
                    }
                    StyledText {
                        width: Theme.barHeight
                        height: Theme.barHeight
                        horizontalAlignment: Text.AlignHCenter
                        text: wsRow.value
                    }
                    IconButton {
                        icon: 0xF0415 // nf-md-plus
                        enabled: wsRow.value < 10
                        onClicked: Config.set("workspaces.persistent", wsRow.value + 1)
                    }
                }

                OptionRow {
                    label: "Network speed in bar"
                    path: "network.showSpeed"

                    Chip {
                        text: Config.network.showSpeed ? "On" : "Off"
                        checked: Config.network.showSpeed === true
                        onClicked: Config.set("network.showSpeed", !Config.network.showSpeed)
                    }
                }

                OptionRow {
                    label: "Session dry run (only log power actions)"
                    path: "session.dryRun"

                    Chip {
                        text: Config.session.dryRun ? "On" : "Off"
                        checked: Config.session.dryRun === true
                        onClicked: Config.set("session.dryRun", !Config.session.dryRun)
                    }
                }
            }
        }
    }
}
