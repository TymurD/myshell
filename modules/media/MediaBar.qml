import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

// Mini player: play state + "Title · Artist". Left click → expanded player,
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
            text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
            color: Media.playing ? Theme.text : Theme.textDim
            width: Math.min(implicitWidth, Config.media.maxWidth ?? 240)
            elide: Text.ElideRight
        }
    }
}
