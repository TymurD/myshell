import QtQuick
import qs.theme

// Nerd Font glyph by code point, e.g. Icon { code: 0xF0150 }
StyledText {
    property int code: 0
    text: code ? String.fromCodePoint(code) : ""
    color: Theme.textDim
}
