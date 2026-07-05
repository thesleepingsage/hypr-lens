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

    // Use a synchronizer on these
    property var action
    property var selectionMode
    property var captureMode
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

    // Keep tab indices in sync with externally driven state (C-key toggle swaps
    // captureMode; entering Crop forces selectionMode back to RectCorners)
    onCaptureModeChanged: {
        const idx = root.cropActive ? 1 : 0;
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

    // Selection mode tabs (Rect/Circle) - inert while Crop is active (Crop implies rectangles)
    ToolbarTabBar {
        id: tabBar
        enabled: !root.cropActive
        opacity: enabled ? 1 : 0.4
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]
        Component.onCompleted: {
            currentIndex = root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1
        }
        onCurrentIndexChanged: {
            root.selectionMode = currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
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
            root.captureMode = currentIndex === 0 ? RegionSelection.CaptureMode.Instant : RegionSelection.CaptureMode.Crop;
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
