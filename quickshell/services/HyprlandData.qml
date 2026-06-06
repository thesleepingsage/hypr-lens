pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// HyprlandData service for hypr-lens - provides window and layer information
Singleton {
    id: root
    property var windowList: []
    property var layers: ({})
    property int decorationRounding: 18

    function updateWindowList() {
        getClients.running = true;
    }

    function updateLayers() {
        getLayers.running = true;
    }

    function updateRounding() {
        getRounding.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateLayers();
        updateRounding();
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            updateAll()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text)
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse clients JSON:", e.message);
                    root.windowList = [];
                }
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(layersCollector.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse layers JSON:", e.message);
                    root.layers = {};
                }
            }
        }
    }

    // Mirror Hyprland's decoration:rounding so selection overlays match real window corners.
    // Reads the runtime-resolved value over IPC (config-language-agnostic; survives hyprlang->Lua).
    Process {
        id: getRounding
        command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
        stdout: StdioCollector {
            id: roundingCollector
            onStreamFinished: {
                try {
                    root.decorationRounding = JSON.parse(roundingCollector.text).int ?? 18;
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse rounding JSON:", e.message);
                    root.decorationRounding = 18;
                }
            }
        }
    }
}
