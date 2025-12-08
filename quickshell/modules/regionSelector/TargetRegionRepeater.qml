import QtQuick
import Quickshell
import "../common"
import "../common/widgets"
import "../../services"

// Consolidated repeater for displaying target regions (windows, layers, content)
// Parameterized to handle all three region types with a single component
Repeater {
    id: root

    required property var regions
    required property int zIndex
    required property color borderColor
    required property color fillColor
    required property real regionOpacity

    // Targeting state from RegionDragState
    required property bool draggedAway
    required property real targetedRegionX
    required property real targetedRegionY
    required property real targetedRegionWidth
    required property real targetedRegionHeight

    // Optional properties with defaults
    property bool showIcon: false
    property real radius: 4
    property string labelProperty: ""  // "class", "namespace", or empty for fixed text
    property string fixedLabel: ""     // Used when labelProperty is empty

    model: ScriptModel {
        values: root.regions
    }

    delegate: TargetRegion {
        z: root.zIndex
        required property var modelData

        clientDimensions: modelData
        showIcon: root.showIcon

        targeted: !root.draggedAway &&
            (root.targetedRegionX === modelData.at[0]
            && root.targetedRegionY === modelData.at[1]
            && root.targetedRegionWidth === modelData.size[0]
            && root.targetedRegionHeight === modelData.size[1])

        opacity: root.draggedAway ? 0 : root.regionOpacity
        borderColor: root.borderColor
        fillColor: targeted ? root.fillColor : "transparent"
        radius: root.radius

        text: {
            if (root.labelProperty === "class") return modelData.class ?? "";
            if (root.labelProperty === "namespace") return modelData.namespace ?? "";
            return root.fixedLabel;
        }
    }
}
