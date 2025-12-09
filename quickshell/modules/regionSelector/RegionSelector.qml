pragma ComponentBehavior: Bound
import "../.."
import "../common"
import "../common/functions"
import "../common/widgets"
import "../../services"
import "RegionUtils.js" as RegionUtils
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Main region selector scope
// Manages the overlay window(s) for selecting screen regions
Scope {
    id: root

    function dismiss() {
        GlobalStates.regionSelectorOpen = false
        root.targetMonitorCapture = ""
    }

    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners

    // ─── Monitor List Management ─────────────────────────────────────────────────
    property var monitorList: []

    FileView {
        id: monitorOrderFileView
        path: Directories.shellConfigPath
        onLoaded: root.rebuildMonitorList()
    }

    Component.onCompleted: rebuildMonitorList()

    // Builds the monitor list from Quickshell.screens and applies custom ordering.
    // Uses regex to parse monitorOrder from JSONC config (handles comments/trailing commas).
    function rebuildMonitorList() {
        // Parse custom order from config
        const rawText = monitorOrderFileView.text();
        const customOrder = RegionUtils.parseMonitorOrder(rawText);

        // Build monitor info list
        let list = [];
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(screen);
            list.push(RegionUtils.buildMonitorInfo(screen, monitor));
        }

        // Apply custom ordering
        root.monitorList = RegionUtils.sortMonitorsByOrder(list, customOrder);
    }

    // ─── Cross-Monitor Capture Coordination ──────────────────────────────────────
    property string targetMonitorCapture: ""

    function captureMonitor(monitorName: string) {
        root.targetMonitorCapture = monitorName;
    }

    // ─── Region Selection Windows ────────────────────────────────────────────────
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

    // ─── Action Launcher ─────────────────────────────────────────────────────────
    // Opens the region selector with the specified action.
    // Selection mode is determined by config or defaults to RectCorners.
    function openWithAction(action) {
        root.action = action;
        root.selectionMode = getSelectionModeForAction(action);
        GlobalStates.regionSelectorOpen = true;
    }

    // Determines the selection mode for an action based on config settings.
    // Note: Direct property access is required for QML JsonObject compatibility.
    function getSelectionModeForAction(action) {
        let useCircle = false;
        switch (action) {
            case RegionSelection.SnipAction.Search:
                useCircle = Config.options.search?.imageSearch?.useCircleSelection ?? false;
                break;
            case RegionSelection.SnipAction.CharRecognition:
                useCircle = Config.options.ocr?.useCircleSelection ?? false;
                break;
        }
        return useCircle ? RegionSelection.SelectionMode.Circle : RegionSelection.SelectionMode.RectCorners;
    }

    // Thin wrappers for IPC and shortcut compatibility
    function screenshot() { openWithAction(RegionSelection.SnipAction.Copy); }
    function search() { openWithAction(RegionSelection.SnipAction.Search); }
    function ocr() { openWithAction(RegionSelection.SnipAction.CharRecognition); }
    function record() { openWithAction(RegionSelection.SnipAction.Record); }
    function recordWithSound() { openWithAction(RegionSelection.SnipAction.RecordWithSound); }

    // ─── IPC Handler ─────────────────────────────────────────────────────────────
    IpcHandler {
        target: "region"
        function screenshot() { root.screenshot(); }
        function search() { root.search(); }
        function ocr() { root.ocr(); }
        function record() { root.record(); }
        function recordWithSound() { root.recordWithSound(); }
    }

    // ─── Global Shortcuts ────────────────────────────────────────────────────────
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
