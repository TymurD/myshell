pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// The "current" MPRIS player: the one the user picked (until another player starts
// playing), else the one playing, else the last one that played, else the first.
// Also: live position (MPRIS doesn't push it) and read-only default sink volume.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastPlaying: null
    // Player picked in the panel's switcher. Cleared when it goes away or another one starts playing.
    property var pinned: null
    readonly property var playingPlayer: players.find(p => p.isPlaying) ?? null
    readonly property var active: (players.includes(pinned) ? pinned : null) ?? playingPlayer ?? (players.includes(lastPlaying) ? lastPlaying : null) ?? players[0] ?? null

    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || ""
    readonly property string artist: active?.trackArtist || ""
    readonly property string album: active?.trackAlbum || ""
    readonly property string artUrl: active?.trackArtUrl || ""
    readonly property string identity: active ? playerName(active) : ""

    // seconds
    readonly property real position: active?.position ?? 0
    readonly property real length: (active?.lengthSupported ?? false) ? active.length : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property bool canSeek: (active?.canSeek ?? false) && (active?.positionSupported ?? false) && length > 0

    readonly property bool shuffleSupported: active?.shuffleSupported ?? false
    readonly property bool shuffle: active?.shuffle ?? false
    readonly property bool loopSupported: active?.loopSupported ?? false
    readonly property int loopState: active?.loopState ?? MprisLoopState.None

    onActiveChanged: if (active?.isPlaying)
        lastPlaying = active
    onPlayingPlayerChanged: {
        if (playingPlayer)
            lastPlaying = playingPlayer;
        if (playingPlayer && pinned && playingPlayer !== pinned)
            pinned = null;
    }

    function select(player: var): void {
        pinned = player;
    }

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
    // frac: 0..1 of the track
    function seekTo(frac: real): void {
        if (!canSeek)
            return;
        active.position = Math.max(0, Math.min(1, frac)) * length;
    }
    function toggleShuffle(): void {
        if (shuffleSupported)
            active.shuffle = !active.shuffle;
    }
    // None → Playlist → Track → None
    function cycleLoop(): void {
        if (!loopSupported)
            return;
        active.loopState = loopState === MprisLoopState.None ? MprisLoopState.Playlist : loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    function playerName(p: var): string {
        return p?.identity || p?.desktopEntry || p?.dbusName || "Player";
    }
    function playerIcon(p: var): int {
        const id = ((p?.identity ?? "") + " " + (p?.desktopEntry ?? "") + " " + (p?.dbusName ?? "")).toLowerCase();
        if (id.includes("spotify"))
            return 0xF04C7;
        if (id.includes("firefox"))
            return 0xF0239;
        if (id.includes("vlc"))
            return 0xF057C;
        if (id.includes("mpv") || id.includes("video"))
            return 0xF0567;
        if (id.includes("chrom") || id.includes("brave"))
            return 0xF059F;
        return 0xF075A;
    }

    function formatTime(s: real): string {
        if (!s || s < 0 || !isFinite(s))
            s = 0;
        s = Math.floor(s);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    // MPRIS position is computed on read but never notified: poke it while playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing && (root.active?.positionSupported ?? false)
        onTriggered: root.active.positionChanged()
    }

    // ---- default sink volume, read-only (DAC stays at 100%; no control here) ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool volumeKnown: sink?.audio !== undefined && sink?.audio !== null
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string sinkName: sink?.description || sink?.nickName || sink?.name || ""

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
