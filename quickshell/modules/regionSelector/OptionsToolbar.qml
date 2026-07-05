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
import Quickshell.Hyprland

// Options toolbar for region selector
// Displays action icon, selection mode tabs, and monitor capture buttons
Toolbar {
    id: root

    // action uses a Synchronizer (display-only here, never written back).
    // selectionMode/captureMode are plain read-only bindings from RegionSelection — the
    // single owner. Tab clicks *request* a change via the *Selected signals instead of
    // writing state, and the tab indices are derived display. (The previous bidirectional
    // Synchronizer + currentIndex write-back + the C-key external writer left three copies
    // of the mode that desynced under re-entrant sync.)
    property var action
    property var selectionMode
    property int captureMode

    signal selectionModeSelected(var mode)
    signal captureModeSelected(int mode)
    // True while the adjustable crop editor is open (plain binding from RegionSelection)
    property bool cropEditing: false
    // Monitor list for full-screen capture buttons
    property var monitors: []
    // Signals
    signal dismiss()
    signal captureFullMonitor(string monitorName)
    signal editFullMonitor(string monitorName)

    // Use ActionConfig singleton for action metadata
    readonly property var actionConfig: ActionConfig.getConfig(root.action)
    readonly property bool showMonitorButtons: actionConfig.allowsMonitorButtons
    readonly property bool cropActive: root.captureMode === RegionSelection.CaptureMode.Crop

    // Follow the owner: whenever the bound-in mode changes (C key, forced RectCorners,
    // sessionReset, or an accepted tab request), reflect it in the tab index. Reads the
    // just-changed property directly — never a derived property that may not have
    // re-evaluated yet.
    onCaptureModeChanged: {
        const idx = root.captureMode === RegionSelection.CaptureMode.Crop ? 1 : 0;
        if (captureModeTabBar.currentIndex !== idx) captureModeTabBar.setCurrentIndex(idx);
    }
    onSelectionModeChanged: {
        const idx = root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1;
        if (tabBar.currentIndex !== idx) tabBar.setCurrentIndex(idx);
    }

    // Action indicator shape
    MaterialShape {
        Layout.fillHeight: true
        Layout.leftMargin: 2
        Layout.rightMargin: 2
        implicitSize: 36 // Intentionally smaller because this one is brighter than others
        shape: root.actionConfig.shape
        color: Appearance.colors.colPrimary

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 22
            color: Appearance.colors.colOnPrimary
            animateChange: true
            text: root.actionConfig.icon
        }
    }

    // Selection mode tabs (Rect/Circle) - usable in Crop too (a circle loop seeds the
    // editor via its bounding box); inert only while the crop editor is open, same as
    // the capture tabs
    ToolbarTabBar {
        id: tabBar
        enabled: !root.cropEditing
        opacity: enabled ? 1 : 0.4
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Freehand")}
        ]
        Component.onCompleted: {
            currentIndex = root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1
        }
        onCurrentIndexChanged: {
            // Emit only for genuine user input; index changes that merely follow the
            // bound-in state compute the same mode and stay silent (no echo loop).
            const mode = currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
            if (mode !== root.selectionMode) root.selectionModeSelected(mode);
        }
    }

    // Capture mode tabs (Instant/Crop) - inert while the crop editor is open so a
    // stray click/wheel can't flip to Instant and destroy the adjusted crop
    // (Esc, C and the FABs are the editor exits)
    ToolbarTabBar {
        id: captureModeTabBar
        enabled: !root.cropEditing
        opacity: enabled ? 1 : 0.4
        tabButtonList: [
            {"icon": "bolt", "name": Translation.tr("Instant")},
            {"icon": "crop", "name": Translation.tr("Crop")}
        ]
        Component.onCompleted: {
            currentIndex = root.cropActive ? 1 : 0
        }
        onCurrentIndexChanged: {
            const mode = currentIndex === 0 ? RegionSelection.CaptureMode.Instant : RegionSelection.CaptureMode.Crop;
            if (mode !== root.captureMode) root.captureModeSelected(mode);
        }
    }

    // Monitor capture buttons - one-click full-screen capture for each monitor
    // Left-click: capture and copy to clipboard
    // Right-click: capture and edit with swappy
    Repeater {
        model: root.showMonitorButtons ? root.monitors : []
        delegate: MonitorButton {
            required property var modelData
            monitor: modelData
            onCaptureRequested: (name) => root.captureFullMonitor(name)
            onEditRequested: (name) => root.editFullMonitor(name)
        }
    }
}
