import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// Mini player: round album art ringed by a track-progress arc, then the track
// title. Left click → expanded player, right click → play/pause. Hidden when no
// player is running.
BarButton {
    id: root

    shown: Media.hasPlayer
    onRightClicked: Media.togglePlaying()

    Row {
        spacing: 8

        Item {
            id: art

            readonly property real size: Theme.barHeight - 8
            readonly property real ring: 2

            width: size
            height: size
            anchors.verticalCenter: parent.verticalCenter

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: art.ring + 1
                radius: width / 2
                color: Theme.surface

                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 64
                    sourceSize.height: 64
                    opacity: Media.playing ? 1 : 0.6

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Anim.fast
                        }
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    code: 0xF075A // music note
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // progress ring: faint full track + arc from 12 o'clock
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.textFaint
                    strokeWidth: art.ring
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: art.size / 2
                        centerY: art.size / 2
                        radiusX: (art.size - art.ring) / 2
                        radiusY: radiusX
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    strokeColor: Media.playing ? Theme.text : Theme.textDim
                    strokeWidth: art.ring
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: art.size / 2
                        centerY: art.size / 2
                        radiusX: (art.size - art.ring) / 2
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360 * Media.progress

                        Behavior on sweepAngle {
                            NumberAnimation {
                                duration: Anim.normal
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Media.title || Media.identity
            color: Media.playing ? Theme.text : Theme.textDim
            width: Math.min(implicitWidth, Config.media.maxWidth ?? 240)
            elide: Text.ElideRight
        }
    }
}
