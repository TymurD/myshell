pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Semantic design tokens. Colors come from palettes/<Config.palette>.json.
// Modules must use these tokens, never literal colors/sizes.
Singleton {
    id: root

    // colors
    readonly property color bg: p.bg
    readonly property color bgSolid: p.bgSolid
    readonly property color surface: p.surface
    readonly property color surfaceHover: p.surfaceHover
    readonly property color border: p.border
    readonly property color borderStrong: p.borderStrong
    readonly property color text: p.text
    readonly property color textDim: p.textDim
    readonly property color textMuted: p.textMuted
    readonly property color textFaint: p.textFaint
    readonly property color accent: p.accent
    readonly property color urgent: p.urgent

    // typography
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 17
    readonly property int fontSizeSmall: 13
    readonly property int fontSizeLarge: 22

    // geometry
    readonly property int barHeight: Config.bar.height ?? 34
    readonly property int barMargin: Config.bar.margin ?? 12
    readonly property int itemPadding: 14
    readonly property int panelGap: 8
    readonly property int panelPadding: 16
    readonly property int radius: 16
    readonly property int radiusSmall: 8
    readonly property int borderWidth: 1

    FileView {
        path: Quickshell.shellPath("palettes/" + Config.palette + ".json")
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: err => console.warn("Theme: failed to load palette", Config.palette, FileViewError.toString(err))

        JsonAdapter {
            id: p

            property string bg: "#a6111111"
            property string bgSolid: "#ee0b0b0b"
            property string surface: "#1a1a1a"
            property string surfaceHover: "#050505"
            property string border: "#2e2e2e"
            property string borderStrong: "#555555"
            property string text: "#f2f2f2"
            property string textDim: "#8a8a8a"
            property string textMuted: "#707070"
            property string textFaint: "#2a2a2a"
            property string accent: "#f2f2f2"
            property string urgent: "#e06c75"
        }
    }
}
