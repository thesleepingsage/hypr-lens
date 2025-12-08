pragma Singleton
import QtQuick
import Quickshell

// Minimal GlobalStates for hypr-lens
Singleton {
    id: root

    // State needed by regionSelector
    property bool regionSelectorOpen: false

    // Stub properties (not used but may be referenced)
    property bool barOpen: true
    property real screenZoom: 1
}
