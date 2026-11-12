pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Desktop applications: fuzzy search + frecency ranking for the launcher.
// Launch counts / last-launch times persist in Quickshell.statePath("apps.json").
Singleton {
    id: root

    readonly property int maxResults: Config.launcher?.maxResults ?? 50
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

    // Ranked entries for a query (all apps by frecency when the query is empty).
    function query(text: string): var {
        const q = text.trim().toLowerCase();
        const now = Date.now();
        const out = [];
        for (const e of apps) {
            const m = q === "" ? 0 : matchEntry(q, e);
            if (m < 0)
                continue;
            out.push({
                entry: e,
                score: m + frecency(e.id, now)
            });
        }
        out.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return out.slice(0, maxResults).map(r => r.entry);
    }

    function launch(entry: var): void {
        if (!entry)
            return;
        const u = Object.assign({}, adapter.usage);
        const prev = u[entry.id] ?? {
            count: 0,
            last: 0
        };
        u[entry.id] = {
            count: prev.count + 1,
            last: Date.now()
        };
        adapter.usage = u;
        store.writeAdapter();
        entry.execute();
    }

    // Launch frequency, decayed by how long ago the app was last used. 0..~250.
    function frecency(id: string, now: real): real {
        const u = adapter.usage[id];
        if (!u)
            return 0;
        const days = (now - u.last) / 86400000;
        const recency = 1 / (1 + days / 7);
        return Math.min(250, 60 * Math.log2(1 + u.count) * (0.4 + 0.6 * recency));
    }

    // Best field score, weighted: name > generic name > keywords > exec.
    function matchEntry(q: string, e: var): real {
        let best = score(q, e.name);
        best = Math.max(best, score(q, e.genericName) * 0.75);
        for (const k of e.keywords ?? [])
            best = Math.max(best, score(q, k) * 0.65);
        const exec = (e.command?.[0] ?? "").split("/").pop();
        best = Math.max(best, score(q, exec) * 0.6);
        return best > 0 ? best : -1;
    }

    // Fuzzy score of query q (lowercase) against s. -1 = no match.
    function score(q: string, s: string): real {
        if (!s)
            return -1;
        const t = s.toLowerCase();
        if (t === q)
            return 1000;
        if (t.startsWith(q))
            return 900 - Math.min(100, t.length - q.length);
        const idx = t.indexOf(q);
        if (idx > 0) {
            const boundary = /[\s\-_.]/.test(t[idx - 1]);
            return (boundary ? 800 : 650) - Math.min(100, idx);
        }
        // subsequence with bonuses for consecutive chars and word starts
        let si = 0, sc = 0, run = 0, first = -1;
        for (let i = 0; i < q.length; i++) {
            const c = q[i];
            let found = -1;
            for (let j = si; j < t.length; j++)
                if (t[j] === c) {
                    found = j;
                    break;
                }
            if (found < 0)
                return -1;
            if (first < 0)
                first = found;
            // too scattered to be a meaningful match
            if (found - first + 1 > q.length * 3 + 2)
                return -1;
            run = found === si && i > 0 ? run + 1 : 0;
            const start = found === 0 || /[\s\-_.]/.test(t[found - 1]);
            sc += 10 + run * 15 + (start ? 25 : 0) - Math.min(10, found - si);
            si = found + 1;
        }
        return Math.max(1, Math.min(500, sc * 3));
    }

    FileView {
        id: store
        path: Quickshell.statePath("apps.json")
        printErrors: false

        JsonAdapter {
            id: adapter
            property var usage: ({})
        }
    }
}
