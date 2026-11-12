import QtQuick
import Quickshell
import Quickshell.Io
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

    IpcHandler {
        target: "keyboard"

        function next(): void {
            KbLayout.next();
        }
    }
}
