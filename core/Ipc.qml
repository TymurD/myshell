import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core
import qs.services

// IPC entry points. Call from Hyprland binds:
//   qs -c myshell ipc call panels toggle launcher
Scope {
    IpcHandler {
        target: "panels"

        function toggle(id: string): void {
            PanelManager.toggle(id, "ipc", null);
        }
        function open(id: string): void {
            PanelManager.open(id, "ipc", null);
        }
        function close(): void {
            PanelManager.close();
        }
        function list(): string {
            return Object.keys(Registry.panels).join("\n");
        }
    }

    // Settings overrides (what the settings panel writes). Paths are dotted, values JSON:
    //   ipc call config set bar.right '["tray","network"]'
    IpcHandler {
        target: "config"

        function get(path: string): string {
            return JSON.stringify(Config.get(path) ?? null);
        }
        function set(path: string, json: string): void {
            try {
                Config.set(path, JSON.parse(json));
            } catch (e) {
                console.warn("config set: invalid JSON:", e.message);
            }
        }
        function reset(path: string): void {
            Config.reset(path);
        }
        function userPath(): string {
            return Config.userPath;
        }
    }

    IpcHandler {
        target: "keyboard"

        function next(): void {
            KbLayout.next();
        }
    }
}
