pragma ComponentBehavior: Bound
import "../common"
import "../common/widgets"
import "../../services"
import QtQuick

// Button for one-click full-screen capture of a specific monitor.
// Used in OptionsToolbar to provide quick monitor capture without dragging.
ToolbarTabButton {
    id: root

    // Monitor data object with at least: { name: string }
    required property var monitor

    // Signal emitted when user left-clicks to capture this monitor
    signal captureRequested(string monitorName)
    // Signal emitted when user right-clicks to edit this monitor's capture with swappy
    signal editRequested(string monitorName)

    current: false
    text: monitor.name
    materialSymbol: "desktop_windows"

    onClicked: root.captureRequested(monitor.name)
    altAction: () => root.editRequested(monitor.name)

    StyledToolTip {
        text: Translation.tr("Click to capture, right-click to edit")
    }
}
