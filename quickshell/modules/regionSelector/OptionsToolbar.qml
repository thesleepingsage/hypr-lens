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
    // Monitor list for full-screen capture buttons
    property var monitors: []
    // Signals
    signal dismiss()
    signal captureFullMonitor(string monitorName)
    signal editFullMonitor(string monitorName)

    // Use ActionConfig singleton for action metadata
    readonly property var actionConfig: ActionConfig.getConfig(root.action)
    readonly property bool showMonitorButtons: actionConfig.allowsMonitorButtons

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

    // Selection mode tabs (Rect/Circle)
    ToolbarTabBar {
        id: tabBar
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
