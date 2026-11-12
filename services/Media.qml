pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The "current" MPRIS player: the one playing, else the last one that played, else the first.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastPlaying: null
    readonly property var active: players.find(p => p.isPlaying) ?? (players.includes(lastPlaying) ? lastPlaying : null) ?? players[0] ?? null

    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || ""
    readonly property string artist: active?.trackArtist || ""
    readonly property string artUrl: active?.trackArtUrl || ""

    onActiveChanged: if (active?.isPlaying)
        lastPlaying = active

    function togglePlaying(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next(): void {
        if (active?.canGoNext)
            active.next();
    }
    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }
}
