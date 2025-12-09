pragma ComponentBehavior: Bound
import "../common"
import "../common/widgets"
import QtQuick

// Button for one-click full-screen capture of a specific monitor.
// Used in OptionsToolbar to provide quick monitor capture without dragging.
ToolbarTabButton {
    id: root

    // Monitor data object with at least: { name: string }
    required property var monitor

    // Signal emitted when user clicks to capture this monitor
    signal captureRequested(string monitorName)

    current: false
    text: monitor.name
    materialSymbol: "desktop_windows"

    onClicked: root.captureRequested(monitor.name)

    StyledToolTip {
        text: Translation.tr("Capture full screen: %1").arg(root.monitor.name)
    }
}
