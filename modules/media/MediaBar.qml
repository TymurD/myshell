import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

// Mini player: play state + "Title · Artist" with a thin progress underline
// (settings: media.progressUnderline). Left click → expanded player,
// right click → play/pause. Hidden when no player is running.
BarButton {
    shown: Media.hasPlayer
    onRightClicked: Media.togglePlaying()

    Row {
        spacing: 6

        Icon {
            code: Media.playing ? 0xF03E4 : 0xF040A // pause / play
        }
        StyledText {
            id: label
            text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
            color: Media.playing ? Theme.text : Theme.textDim
            width: Math.min(implicitWidth, Config.media.maxWidth ?? 240)
            elide: Text.ElideRight

            // progress underline; a grandchild of the button, so it doesn't affect the pill layout
            Rectangle {
                visible: (Config.media.progressUnderline ?? true) && Media.length > 0
                anchors.left: parent.left
                anchors.top: parent.bottom
                anchors.topMargin: 1
                width: parent.width
                height: 2
                radius: 1
                color: Theme.textFaint

                Rectangle {
                    width: parent.width * Media.progress
                    height: parent.height
                    radius: parent.radius
                    color: Media.playing ? Theme.textDim : Theme.textMuted
                    Behavior on width {
                        NumberAnimation {
                            duration: Anim.normal
                        }
                    }
                }
            }
        }
    }
}
