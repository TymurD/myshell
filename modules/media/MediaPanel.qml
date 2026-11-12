import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.components
import qs.services
import qs.theme

// Expanded player: art, track info, seek bar, transport, shuffle/loop,
// player switcher (when several), read-only output volume.
PanelSurface {
    id: root

    readonly property int artSize: 132

    implicitWidth: 460
    implicitHeight: col.implicitHeight + 2 * Theme.panelPadding

    // round icon button used for transport / toggles
    component CtrlButton: MouseArea {
        id: btn

        property int code
        property bool active: false        // toggled state (shuffle / loop)
        property bool primary: false       // the big play/pause
        property int size: 38

        implicitWidth: size
        implicitHeight: size
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: btn.primary ? Theme.accent : btn.containsMouse ? Theme.surfaceHover : "transparent"
            border.color: btn.primary ? Theme.accent : Theme.border
            border.width: btn.primary || btn.containsMouse ? Theme.borderWidth : 0
            scale: btn.pressed ? 0.92 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Anim.fast
                    easing.type: Anim.standard
                }
            }
        }
        Icon {
            anchors.centerIn: parent
            code: btn.code
            font.pixelSize: btn.primary ? Theme.fontSizeLarge : Theme.fontSize
            color: btn.primary ? Theme.bgSolid : btn.active ? Theme.text : Theme.textDim
        }
        // dot under an enabled toggle
        Rectangle {
            visible: btn.active && !btn.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            width: 4
            height: 4
            radius: 2
            color: Theme.accent
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.panelPadding
        spacing: 14

        // ---- player switcher ----
        Flow {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: 6

            Repeater {
                model: Media.players

                MouseArea {
                    id: chip
                    required property var modelData
                    readonly property bool current: modelData === Media.active

                    width: chipRow.implicitWidth + 20
                    height: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.select(modelData)

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: chip.current ? Theme.accent : chip.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.color: chip.current ? Theme.accent : Theme.border
                        border.width: Theme.borderWidth
                        Behavior on color {
                            ColorAnimation {
                                duration: Anim.fast
                            }
                        }
                    }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            code: Media.playerIcon(chip.modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: chip.current ? Theme.bgSolid : Theme.textDim
                        }
                        StyledText {
                            text: Media.playerName(chip.modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            color: chip.current ? Theme.bgSolid : Theme.text
                        }
                        Icon {
                            visible: chip.modelData.isPlaying
                            code: 0xF040A
                            font.pixelSize: Theme.fontSizeSmall
                            color: chip.current ? Theme.bgSolid : Theme.textDim
                        }
                    }
                }
            }
        }

        // ---- art + track info ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ClippingRectangle {
                implicitWidth: root.artSize
                implicitHeight: root.artSize
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: Theme.border
                border.width: Theme.borderWidth

                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: root.artSize * 2
                    sourceSize.height: root.artSize * 2
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Anim.normal
                        }
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    code: Media.hasPlayer ? 0xF0025 : 0xF038A // album / music-note-off
                    font.pixelSize: Theme.fontSizeDisplay
                    color: Theme.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Media.hasPlayer ? (Media.title || "Unknown title") : "Nothing playing"
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.artist
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.album
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
                Row {
                    Layout.topMargin: 6
                    visible: Media.hasPlayer
                    spacing: 6
                    Icon {
                        code: Media.playerIcon(Media.active)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                    StyledText {
                        text: Media.identity
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }

        // ---- seek bar ----
        ColumnLayout {
            Layout.fillWidth: true
            visible: Media.hasPlayer && Media.length > 0
            spacing: 4

            MouseArea {
                id: seek

                // fraction while dragging, else live progress
                property real dragFrac: 0
                readonly property real shownFrac: pressed ? dragFrac : Media.progress

                function fracAt(x: real): real {
                    return Math.max(0, Math.min(1, x / width));
                }

                Layout.fillWidth: true
                implicitHeight: 16
                enabled: Media.canSeek
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true
                onPressed: mouse => dragFrac = fracAt(mouse.x)
                onPositionChanged: mouse => {
                    if (pressed)
                        dragFrac = fracAt(mouse.x);
                }
                onReleased: mouse => Media.seekTo(fracAt(mouse.x))

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seek.containsMouse || seek.pressed ? 6 : 4
                    radius: height / 2
                    color: Theme.surface
                    Behavior on height {
                        NumberAnimation {
                            duration: Anim.fast
                        }
                    }

                    Rectangle {
                        width: parent.width * seek.shownFrac
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        Behavior on width {
                            enabled: !seek.pressed
                            NumberAnimation {
                                duration: Anim.normal
                                easing.type: Anim.standard
                            }
                        }
                    }
                }
                // knob
                Rectangle {
                    visible: seek.enabled && (seek.containsMouse || seek.pressed)
                    x: seek.width * seek.shownFrac - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Media.formatTime(seek.pressed ? seek.dragFrac * Media.length : Media.position)
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                }
                Item {
                    Layout.fillWidth: true
                }
                StyledText {
                    text: Media.formatTime(Media.length)
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ---- transport ----
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: Media.hasPlayer
            spacing: 10

            CtrlButton {
                code: Media.shuffle ? 0xF049D : 0xF049E
                active: Media.shuffle
                enabled: Media.shuffleSupported
                onClicked: Media.toggleShuffle()
            }
            CtrlButton {
                code: 0xF04AE
                enabled: Media.active?.canGoPrevious ?? false
                onClicked: Media.previous()
            }
            CtrlButton {
                code: Media.playing ? 0xF03E4 : 0xF040A
                primary: true
                size: 50
                enabled: Media.active?.canTogglePlaying ?? false
                onClicked: Media.togglePlaying()
            }
            CtrlButton {
                code: 0xF04AD
                enabled: Media.active?.canGoNext ?? false
                onClicked: Media.next()
            }
            CtrlButton {
                code: Media.loopState === MprisLoopState.Track ? 0xF0458 : Media.loopState === MprisLoopState.Playlist ? 0xF0456 : 0xF0457
                active: Media.loopState !== MprisLoopState.None
                enabled: Media.loopSupported
                onClicked: Media.cycleLoop()
            }
        }

        // ---- output volume (read-only) ----
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: Media.volumeKnown
            spacing: 6
            opacity: 0.8

            Icon {
                code: Media.muted ? 0xF0581 : 0xF057E
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
            StyledText {
                text: (Media.muted ? "muted" : Media.volume + "%") + (Media.sinkName ? "  ·  " + Media.sinkName : "")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSmall
                width: Math.min(implicitWidth, root.implicitWidth - 2 * Theme.panelPadding - 30)
                elide: Text.ElideRight
            }
        }
    }
}
