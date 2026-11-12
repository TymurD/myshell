pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Notification daemon (org.freedesktop.Notifications), history, DND and per-app mutes.
// UI never touches the server: toasts read `toasts`, the center reads `history`/`groups`.
// History, DND and mutes persist in ~/.local/state/.../notifications.json.
Singleton {
    id: root

    // ── settings (settings.json → notifications) ──
    readonly property var cfg: Config.notifications ?? {}
    readonly property int defaultTimeout: cfg.defaultTimeout ?? 5000       // ms, when the app sends none
    readonly property bool criticalSticky: cfg.criticalSticky ?? true      // critical toasts never auto-expire
    readonly property bool dndAllowCritical: cfg.dndAllowCritical ?? true  // critical still toasts under DND
    readonly property int historyLimit: cfg.historyLimit ?? 100
    readonly property int maxToasts: cfg.maxToasts ?? 5
    readonly property string monitor: cfg.monitor ?? "focused"            // "focused" | output name

    // ── state ──
    // Entry: { uid, nid, appName, appIcon, image, summary, body, urgency, time, actions: [{identifier, text}] }
    property var history: []          // newest first
    readonly property alias dnd: state.dnd
    readonly property alias muted: state.muted
    readonly property int unread: history.filter(e => e.time > state.lastRead).length
    readonly property int count: history.length
    property bool centerOpen: false   // set by the notification center while it is shown

    // Live toasts (newest first). Roles: uid. Entry data comes from entry(uid).
    readonly property ListModel toasts: ListModel {}

    // Live Notification objects by uid (only while the server tracks them; needed for actions).
    property var live: ({})
    property int liveRev: 0           // bumped when `live` changes; bind to it for canInvoke()
    property int nextUid: 1

    // History grouped by app, groups ordered by newest notification.
    readonly property var groups: {
        const map = {};
        const out = [];
        for (const e of history) {
            let g = map[e.appName];
            if (!g) {
                g = map[e.appName] = {
                    appName: e.appName,
                    appIcon: e.appIcon,
                    items: []
                };
                out.push(g);
            }
            g.items.push(e);
        }
        return out;
    }

    // ── public API ──
    function entry(uid: int): var {
        return history.find(e => e.uid === uid) ?? toastOnly[uid] ?? null;
    }

    function isMuted(app: string): bool {
        return state.muted.indexOf(app) !== -1;
    }

    function setDnd(on: bool): void {
        state.dnd = on;
        save();
    }

    function toggleDnd(): void {
        setDnd(!state.dnd);
    }

    function mute(app: string): void {
        if (app === "" || isMuted(app))
            return;
        state.muted = state.muted.concat([app]);
        save();
    }

    function unmute(app: string): void {
        state.muted = state.muted.filter(a => a !== app);
        save();
    }

    function toggleMute(app: string): void {
        isMuted(app) ? unmute(app) : mute(app);
    }

    function markAllRead(): void {
        if (unread === 0)
            return;
        state.lastRead = Date.now();
        save();
    }

    // Remove one notification everywhere (history + toast) and tell the app.
    function dismiss(uid: int): void {
        removeToast(uid);
        removeFromHistory([uid]);
        closeLive(uid);
    }

    function dismissApp(app: string): void {
        const uids = history.filter(e => e.appName === app).map(e => e.uid);
        uids.forEach(u => {
            removeToast(u);
            closeLive(u);
        });
        removeFromHistory(uids);
    }

    function clear(): void {
        const uids = history.map(e => e.uid);
        uids.forEach(u => {
            removeToast(u);
            closeLive(u);
        });
        removeFromHistory(uids);
    }

    // Toast timed out: hide the toast, keep it in history.
    function expireToast(uid: int): void {
        removeToast(uid);
        if (toastOnly[uid]) { // transient: never in history, so it is done now
            delete toastOnly[uid];
            const n = live[uid];
            if (n)
                n.expire();
        }
    }

    function canInvoke(uid: int): bool {
        return !!live[uid];
    }

    // Run an action ("default" = click on the notification body).
    function invoke(uid: int, identifier: string): void {
        const n = live[uid];
        if (!n)
            return;
        const a = acts(n).find(x => x.identifier === identifier);
        if (!a)
            return;
        const resident = n.resident;
        a.invoke();
        if (!resident)
            dismiss(uid);
        else
            removeToast(uid);
    }

    function invokeLatest(identifier: string): void {
        const e = history.concat(Object.values(toastOnly)).filter(x => live[x.uid] && acts(live[x.uid]).some(a => a.identifier === identifier)).sort((x, y) => y.time - x.time)[0];
        if (e)
            invoke(e.uid, identifier);
    }

    function hasDefaultAction(uid: int): bool {
        const n = live[uid];
        return !!n && acts(n).some(x => x.identifier === "default");
    }

    // Image source for an entry: notification image, else app icon (theme name or path).
    function imageFor(e: var): string {
        if (!e)
            return "";
        if (e.image)
            return e.image;
        return iconFor(e.appIcon);
    }

    function iconFor(icon: string): string {
        if (!icon)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon, true) : "";
    }

    function relativeTime(t: real, now: var): string {
        const s = Math.max(0, Math.floor((now.getTime() - t) / 1000));
        if (s < 60)
            return "now";
        const m = Math.floor(s / 60);
        if (m < 60)
            return m + "m ago";
        const h = Math.floor(m / 60);
        if (h < 24)
            return h + "h ago";
        const d = Math.floor(h / 24);
        return d === 1 ? "yesterday" : d + "d ago";
    }

    // ── internals ──
    property var toastOnly: ({})  // transient notifications: toast without history entry

    function removeToast(uid: int): void {
        for (let i = 0; i < toasts.count; i++) {
            if (toasts.get(i).uid === uid) {
                toasts.remove(i);
                return;
            }
        }
    }

    function removeFromHistory(uids: var): void {
        if (uids.length === 0)
            return;
        history = history.filter(e => uids.indexOf(e.uid) === -1);
        save();
    }

    function acts(n: var): var {
        const out = [];
        const l = n.actions;
        for (let i = 0; i < l.length; i++)
            out.push(l[i]);
        return out;
    }

    function closeLive(uid: int): void {
        const n = live[uid];
        delete live[uid];
        liveRev++;
        delete toastOnly[uid];
        if (n && n.tracked)
            n.dismiss();
    }

    function snapshot(n: var, uid: int): var {
        return {
            uid: uid,
            nid: n.id,
            appName: n.appName || "Unknown",
            appIcon: n.appIcon || n.desktopEntry || "",
            image: n.image || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            time: Date.now(),
            timeout: n.expireTimeout,
            actions: acts(n).filter(a => a.identifier !== "default").map(a => ({
                        identifier: a.identifier,
                        text: a.text
                    }))
        };
    }

    // Follow a live notification: closes, and in-place updates (replaces_id reuses the object).
    function watch(n: var, uid: int): void {
        n.closed.connect(reason => root.handleClosed(uid, n, reason));
        const upd = () => root.refresh(uid, n);
        n.summaryChanged.connect(upd);
        n.bodyChanged.connect(upd);
        n.imageChanged.connect(upd);
        n.appIconChanged.connect(upd);
        n.urgencyChanged.connect(upd);
        n.actionsChanged.connect(upd);
    }

    // Coalesce the burst of property changes from one replace into a single update.
    property var pendingRefresh: ({})
    function refresh(uid: int, n: var): void {
        pendingRefresh[uid] = n;
        refreshTimer.restart();
    }
    Timer {
        id: refreshTimer
        interval: 0
        onTriggered: {
            const p = root.pendingRefresh;
            root.pendingRefresh = {};
            let changed = false;
            const h = root.history.slice();
            for (const k in p) {
                const uid = parseInt(k);
                if (root.live[uid] !== p[k])
                    continue;
                const fresh = root.snapshot(p[k], uid);
                const i = h.findIndex(e => e.uid === uid);
                if (i !== -1) {
                    fresh.time = Date.now();
                    h.splice(i, 1);
                    h.unshift(fresh);
                    changed = true;
                    if (!root.isQuiet(fresh) && !root.hasToast(uid))
                        root.toasts.insert(0, {
                            uid: uid
                        });
                } else if (root.toastOnly[uid]) {
                    root.toastOnly[uid] = fresh;
                }
            }
            if (changed) {
                root.history = h;
                root.save();
            }
        }
    }

    function handle(n: var): void {
        // Carried over from before a hot reload (keepOnReload): already in history, just relink.
        if (n.lastGeneration) {
            const prev = history.find(e => e.nid === n.id && e.summary === (n.summary || ""));
            if (prev && !live[prev.uid]) {
                n.tracked = true;
                live[prev.uid] = n;
                liveRev++;
                root.watch(n, prev.uid);
            }
            return;
        }
        // Replacement (replaces_id): same server id → update the existing entry in place.
        const old = history.find(e => e.nid === n.id && live[e.uid] === n);
        const uid = old ? old.uid : nextUid++;
        const e = snapshot(n, uid);
        n.tracked = true;
        if (!old) {
            live[uid] = n;
            liveRev++;
            root.watch(n, uid);
        }

        if (n.transient) {
            toastOnly[uid] = e;
        } else {
            let h = history.filter(x => x.uid !== uid);
            h.unshift(e);
            // Trim the oldest beyond the cap.
            while (h.length > historyLimit) {
                const gone = h.pop();
                closeLive(gone.uid);
            }
            history = h;
            save();
        }

        if (isQuiet(e)) {
            if (n.transient)
                closeLive(uid);
            return;
        }
        removeToast(uid);
        toasts.insert(0, {
            uid: uid
        });
        while (toasts.count > maxToasts)
            toasts.remove(toasts.count - 1);
    }

    function isQuiet(e: var): bool {
        const critical = e.urgency === NotificationUrgency.Critical;
        return centerOpen || isMuted(e.appName) || (state.dnd && !(critical && dndAllowCritical));
    }

    function hasToast(uid: int): bool {
        for (let i = 0; i < toasts.count; i++)
            if (toasts.get(i).uid === uid)
                return true;
        return false;
    }

    // Toast lifetime in ms; 0 = sticky.
    function toastTimeout(e: var): int {
        if (!e)
            return defaultTimeout;
        if (e.urgency === NotificationUrgency.Critical && criticalSticky)
            return 0;
        if (e.timeout > 0)
            return Math.round(e.timeout); // the server reports milliseconds
        if (e.timeout === 0)
            return 0;
        return defaultTimeout;
    }

    function handleClosed(uid: int, n: var, reason: int): void {
        if (live[uid] !== n)
            return;
        delete live[uid];
        liveRev++;
        // The app withdrew it: drop it everywhere. Our own expire/dismiss already handled state.
        if (reason === NotificationCloseReason.CloseRequested) {
            removeToast(uid);
            delete toastOnly[uid];
            removeFromHistory([uid]);
        }
    }

    function save(): void {
        state.history = history.map(e => {
            const c = Object.assign({}, e);
            if (c.image.startsWith("image://"))
                c.image = ""; // in-memory pixmaps don't survive a restart
            return c;
        });
        state.nextUid = nextUid;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: store.writeAdapter()
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: n => root.handle(n)
    }

    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        blockLoading: true
        printErrors: false
        onLoaded: root.restore()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.restored = true;
                store.writeAdapter();
            }
            else
                console.warn("Notifications: failed to load state:", FileViewError.toString(err));
        }

        JsonAdapter {
            id: state
            property bool dnd: false
            property list<string> muted: []
            property var history: []
            property real lastRead: 0
            property int nextUid: 1
        }
    }

    property bool restored: false
    function restore(): void {
        if (restored)
            return;
        restored = true;
        const h = (state.history ?? []).slice(0, historyLimit);
        nextUid = Math.max(state.nextUid, ...h.map(e => e.uid + 1), 1);
        // After a hot reload (keepOnReload) the server still tracks some notifications:
        // relink them so their actions keep working.
        const tracked = server.trackedNotifications.values;
        for (const e of h) {
            const n = tracked.find(t => t.id === e.nid && t.summary === e.summary);
            if (n && !Object.values(live).includes(n)) {
                live[e.uid] = n;
                root.watch(n, e.uid);
            }
        }
        liveRev++;
        history = history.concat(h);
    }
}
