pragma ComponentBehavior: Bound
import "../.."
import "../common"
import "../common/functions"
import "../common/widgets"
import "../../services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        GlobalStates.regionSelectorOpen = false
        root.targetMonitorCapture = ""  // Reset cross-monitor capture state
    }

    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners

    // Monitor list - updated imperatively when config loads
    property var monitorList: []

    // Read monitor order from config and rebuild monitor list
    FileView {
        id: monitorOrderFileView
        path: Directories.shellConfigPath
        onLoaded: root.rebuildMonitorList()
    }

    Component.onCompleted: rebuildMonitorList()

    function rebuildMonitorList() {
        let customOrder = [];
        try {
            const rawText = monitorOrderFileView.text();
            // Extract monitorOrder array directly with regex
            const match = rawText.match(/"monitorOrder"\s*:\s*\[([^\]]*)\]/);
            if (match && match[1]) {
                // Parse the array contents: "DP-1", "DP-3", "DP-2"
                const items = match[1].match(/"([^"]+)"/g);
                if (items) {
                    customOrder = items.map(s => s.replace(/"/g, ''));
                }
            }
        } catch (e) {
            customOrder = [];
        }

        let list = [];
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(screen);
            list.push({
                name: monitor.name,
                x: monitor.x,
                y: monitor.y,
                width: screen.width,
                height: screen.height,
                scale: monitor.scale
            });
        }

        // Apply custom ordering from config if specified
        if (customOrder && customOrder.length > 0) {
            list.sort((a, b) => {
                const aIndex = customOrder.indexOf(a.name);
                const bIndex = customOrder.indexOf(b.name);
                if (aIndex === -1 && bIndex === -1) return 0;
                if (aIndex === -1) return 1;
                if (bIndex === -1) return -1;
                return aIndex - bIndex;
            });
        }

        root.monitorList = list;
    }

    // Cross-monitor capture coordination: set this to trigger capture on that monitor
    property string targetMonitorCapture: ""

    function captureMonitor(monitorName: string) {
        root.targetMonitorCapture = monitorName;
    }
    
    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData
            active: GlobalStates.regionSelectorOpen

            sourceComponent: RegionSelection {
                screen: regionSelectorLoader.modelData
                allMonitors: root.monitorList
                targetMonitorCapture: root.targetMonitorCapture
                onDismiss: root.dismiss()
                onCaptureMonitorRequested: (monitorName) => root.captureMonitor(monitorName)
                action: root.action
                selectionMode: root.selectionMode
            }
        }
    }

    function screenshot() {
        root.action = RegionSelection.SnipAction.Copy
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    function search() {
        root.action = RegionSelection.SnipAction.Search
        if (Config.options.search.imageSearch.useCircleSelection) {
            root.selectionMode = RegionSelection.SelectionMode.Circle
        } else {
            root.selectionMode = RegionSelection.SelectionMode.RectCorners
        }
        GlobalStates.regionSelectorOpen = true
    }

    function ocr() {
        root.action = RegionSelection.SnipAction.CharRecognition
        if (Config.options.ocr?.useCircleSelection) {
            root.selectionMode = RegionSelection.SelectionMode.Circle
        } else {
            root.selectionMode = RegionSelection.SelectionMode.RectCorners
        }
        GlobalStates.regionSelectorOpen = true
    }

    function record() {
        root.action = RegionSelection.SnipAction.Record
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    function recordWithSound() {
        root.action = RegionSelection.SnipAction.RecordWithSound
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    IpcHandler {
        target: "region"

        function screenshot() {
            root.screenshot()
        }
        function search() {
            root.search()
        }
        function ocr() {
            root.ocr()
        }
        function record() {
            root.record()
        }
        function recordWithSound() {
            root.recordWithSound()
        }
    }

    GlobalShortcut {
        name: "regionScreenshot"
        description: "Takes a screenshot of the selected region"
        onPressed: root.screenshot()
    }
    GlobalShortcut {
        name: "regionSearch"
        description: "Searches the selected region"
        onPressed: root.search()
    }
    GlobalShortcut {
        name: "regionOcr"
        description: "Recognizes text in the selected region"
        onPressed: root.ocr()
    }
    GlobalShortcut {
        name: "regionRecord"
        description: "Records the selected region"
        onPressed: root.record()
    }
    GlobalShortcut {
        name: "regionRecordWithSound"
        description: "Records the selected region with sound"
        onPressed: root.recordWithSound()
    }
}
