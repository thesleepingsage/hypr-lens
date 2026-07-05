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
    property int captureMode: RegionSelection.CaptureMode.Instant

    // Emitted by openWithAction so live RegionSelection instances (whose property
    // bindings may have been broken by local writes) reset to session defaults
    signal sessionReset()

    // ─── Monitor List Management ─────────────────────────────────────────────────
    property var monitorList: []

    Component.onCompleted: rebuildMonitorList()

    // Re-snapshot the monitor list every time the overlay opens: Hyprland's monitor
    // data may not be populated yet at Component.onCompleted (startup race), and
    // monitors can be hotplugged or rearranged between opens. The overlay Loaders
    // below react to the same signal with no guaranteed handler order — safe only
    // because allMonitors is a live binding, not a one-shot read.
    Connections {
        target: GlobalStates
        function onRegionSelectorOpenChanged() {
            if (GlobalStates.regionSelectorOpen) root.rebuildMonitorList();
        }
    }

    // Hotplug while the overlay is open: the Variants below tracks Quickshell.screens
    // live, so the button row must follow too or it desyncs from the overlay windows
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (GlobalStates.regionSelectorOpen) root.rebuildMonitorList();
        }
    }

    // Builds the monitor list from Quickshell.screens, sorted by layout position
    // (Hyprland logical coordinates): left-to-right, ties top-to-bottom.
    function rebuildMonitorList() {
        // Ask Hyprland to re-fetch monitor state; some rearrangements emit no event.
        // Async — this rebuild reads current values, the refresh benefits the next one
        Hyprland.refreshMonitors();

        // Build monitor info list
        let list = [];
        for (let i = 0; i < Quickshell.screens.length; i++) {
            const screen = Quickshell.screens[i];
            const monitor = Hyprland.monitorFor(screen);
            // monitorFor creates its object eagerly; x/y stay 0 until IPC data
            // arrives, so treat unpopulated the same as missing. Only warn when the
            // overlay is open — the startup rebuild is replaced at first open anyway
            const populated = monitor && monitor.lastIpcObject;
            if (!populated && GlobalStates.regionSelectorOpen)
                console.warn("RegionSelector: Hyprland monitor data unavailable for " + screen.name + "; using ShellScreen position");
            list.push(RegionUtils.buildMonitorInfo(screen, populated ? monitor : null));
        }

        // Sort by layout position
        root.monitorList = RegionUtils.sortMonitorsByPosition(list);
    }

    // ─── Cross-Monitor Capture Coordination ──────────────────────────────────────
    property string targetMonitorCapture: ""
    // Initiator state stashed before the pulse so the target instance can adopt the
    // initiating screen's Crop mode and action instead of replaying with its own.
    // Only meaningful DURING the targetMonitorCapture pulse — deliberately not cleared
    // after, so never read these outside a pulse handler (stale previous-relay values).
    property int crossCaptureMode: RegionSelection.CaptureMode.Instant
    property var crossCaptureAction: RegionSelection.SnipAction.Copy

    // Params named relay* to avoid shadowing the selector's own session
    // captureMode/action properties inside this function
    function captureMonitor(monitorName: string, relayMode: int, relayAction) {
        // Stash BEFORE the pulse: the change signal fires synchronously on the target,
        // which reads these through its bindings
        root.crossCaptureMode = relayMode;
        root.crossCaptureAction = relayAction;
        root.targetMonitorCapture = monitorName;
        // Clear immediately (the change signal has already fired synchronously on the
        // target instance): in Crop mode the capture seeds the editor without
        // dismissing, and a stale value would make re-clicking the same monitor
        // button a silent no-op
        root.targetMonitorCapture = "";
    }

    // ─── Region Selection Windows ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData
            active: GlobalStates.regionSelectorOpen

            sourceComponent: RegionSelection {
                id: selectionWindow
                screen: regionSelectorLoader.modelData
                allMonitors: root.monitorList
                targetMonitorCapture: root.targetMonitorCapture
                crossCaptureMode: root.crossCaptureMode
                crossCaptureAction: root.crossCaptureAction
                onDismiss: root.dismiss()
                onCaptureMonitorRequested: (monitorName, captureMode, action) => root.captureMonitor(monitorName, captureMode, action)
                action: root.action
                selectionMode: root.selectionMode
                captureMode: root.captureMode

                // Re-triggering a capture shortcut while the overlay is open must
                // restore Instant/draw defaults even on instances whose captureMode/
                // selectionMode bindings were broken by local writes (C key, toolbar)
                Connections {
                    target: root
                    function onSessionReset() {
                        selectionWindow.sessionReset();
                        selectionWindow.selectionMode = root.selectionMode;
                        // action's binding breaks on every cross-monitor relay (the
                        // target adopts the initiator's action) — re-push it too, or a
                        // later OCR/Search re-trigger runs the stale action on that screen
                        selectionWindow.action = root.action;
                    }
                }
            }
        }
    }

    // ─── Action Launcher ─────────────────────────────────────────────────────────
    // Opens the region selector with the specified action.
    // Selection mode is determined by config or defaults to RectCorners.
    function openWithAction(action) {
        // Re-triggering while already open emits no regionSelectorOpenChanged, so
        // rebuild explicitly to pick up mid-session monitor rearrangement
        root.rebuildMonitorList();
        root.action = action;
        root.selectionMode = getSelectionModeForAction(action);
        root.captureMode = RegionSelection.CaptureMode.Instant;  // Never persists across opens
        // Instances alive from a still-open overlay may hold locally-written state
        // (broken bindings); push the Instant/draw defaults to them explicitly
        root.sessionReset();
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
