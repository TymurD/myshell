pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Clipboard history backed by cliphist (`wl-paste --watch cliphist store` fills it).
// Image entries are decoded once into Quickshell.cachePath("clipboard") for thumbnails.
Singleton {
    id: root

    property bool available: false      // cliphist found in PATH
    property bool loading: false
    property var entries: []            // [{ id, text, image, ext, info }]
    property var thumbs: ({})           // id → file path of a decoded image

    readonly property int maxItems: Config.clipboard?.maxItems ?? 500
    readonly property string cacheDir: Quickshell.cachePath("clipboard")

    function refresh(): void {
        if (!available) {
            detect.running = true;
            return;
        }
        loading = true;
        list.running = true;
    }

    function filter(text: string): var {
        const q = text.trim().toLowerCase();
        if (q === "")
            return entries;
        return entries.filter(e => (e.image ? e.info : e.text).toLowerCase().includes(q));
    }

    function copy(id: string): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist decode | wl-copy", "sh", id]);
    }

    function remove(id: string): void {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", id]);
        entries = entries.filter(e => e.id !== id);
    }

    function wipe(): void {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    // "[[ binary data 12 KiB png 1920x1080 ]]"
    function parse(line: string): var {
        const tab = line.indexOf("\t");
        if (tab < 0)
            return null;
        const id = line.slice(0, tab);
        const text = line.slice(tab + 1);
        const bin = text.match(/^\[\[ binary data (.*?) ?(png|jpe?g|gif|bmp|webp|svg)? ?(\d+x\d+)? \]\]$/i);
        if (!bin)
            return {
                id,
                text,
                image: false,
                ext: "",
                info: ""
            };
        const ext = (bin[2] ?? "").toLowerCase();
        return {
            id,
            text,
            image: ext !== "",
            ext: ext.startsWith("svg") ? "svg" : ext,
            info: [ext.toUpperCase(), bin[3], bin[1]].filter(Boolean).join(" · ")
        };
    }

    Process {
        id: detect
        running: true
        command: ["sh", "-c", "command -v cliphist"]
        onExited: code => {
            root.available = code === 0;
            if (root.available)
                root.refresh();
        }
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const e = root.parse(line);
                    if (e)
                        out.push(e);
                    if (out.length >= root.maxItems)
                        break;
                }
                root.entries = out;
                root.loading = false;
                root.decodeImages();
            }
        }
        onExited: code => {
            if (code !== 0)
                root.loading = false;
        }
    }

    function decodeImages(): void {
        const todo = [];
        for (const e of entries)
            if (e.image && !thumbs[e.id])
                todo.push(e.id + "." + e.ext);
        if (todo.length === 0 || decoder.running)
            return;
        decoder.command = ["sh", "-c", 'd="$1"; shift; mkdir -p "$d"; for f in "$@"; do id="${f%%.*}"; ' + '[ -s "$d/$f" ] || printf "%s\\t\\n" "$id" | cliphist decode > "$d/$f"; ' + '[ -s "$d/$f" ] && printf "%s\\t%s\\n" "$id" "$d/$f"; done', "sh", cacheDir].concat(todo);
        decoder.running = true;
    }

    Process {
        id: decoder
        stdout: SplitParser {
            onRead: line => {
                const tab = line.indexOf("\t");
                if (tab < 0)
                    return;
                const t = Object.assign({}, root.thumbs);
                t[line.slice(0, tab)] = line.slice(tab + 1);
                root.thumbs = t;
            }
        }
    }
}
