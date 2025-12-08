//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// hypr-lens - Standalone region selector for Hyprland
// Provides screenshot, OCR, image search, and recording functionality

import "."
import "./modules/common"
import "./modules/common/functions"
import "./modules/common/widgets"
import "./modules/regionSelector"
import "./services"

import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    id: root

    // Main region selector component - includes GlobalShortcuts and IpcHandler
    RegionSelector {
        id: regionSelector
    }
}
