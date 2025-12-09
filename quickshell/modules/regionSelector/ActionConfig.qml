pragma Singleton
import "../common/widgets"
import Quickshell

// Centralized configuration for all region selector actions.
// This singleton provides metadata about each action type to avoid
// duplicating switch statements across multiple components.
//
// Action enum values from RegionSelection.SnipAction:
//   0 = Copy, 1 = Edit, 2 = Search, 3 = CharRecognition, 4 = Record, 5 = RecordWithSound
Singleton {
    id: root

    // Action metadata indexed by SnipAction enum value.
    // Each entry contains: shape (MaterialShape enum), icon, allowsMonitorButtons, circleSelectionConfig
    readonly property var actions: ({
        // Copy action (screenshot to clipboard)
        0: {
            shape: MaterialShape.Shape.Cookie4Sided,
            icon: "content_cut",
            allowsMonitorButtons: true,
            circleSelectionConfig: null
        },
        // Edit action (screenshot to editor)
        1: {
            shape: MaterialShape.Shape.Cookie4Sided,
            icon: "content_cut",
            allowsMonitorButtons: true,
            circleSelectionConfig: null
        },
        // Search action (image search)
        2: {
            shape: MaterialShape.Shape.Pentagon,
            icon: "image_search",
            allowsMonitorButtons: false,
            circleSelectionConfig: { section: "search", subsection: "imageSearch", key: "useCircleSelection" }
        },
        // CharRecognition action (OCR)
        3: {
            shape: MaterialShape.Shape.Sunny,
            icon: "document_scanner",
            allowsMonitorButtons: false,
            circleSelectionConfig: { section: "ocr", key: "useCircleSelection" }
        },
        // Record action (screen recording)
        4: {
            shape: MaterialShape.Shape.Gem,
            icon: "videocam",
            allowsMonitorButtons: true,
            circleSelectionConfig: null
        },
        // RecordWithSound action (screen recording with audio)
        5: {
            shape: MaterialShape.Shape.Gem,
            icon: "videocam",
            allowsMonitorButtons: true,
            circleSelectionConfig: null
        }
    })

    // Default config for unknown actions
    readonly property var defaultConfig: ({
        shape: MaterialShape.Shape.Cookie12Sided,
        icon: "",
        allowsMonitorButtons: false,
        circleSelectionConfig: null
    })

    // Get configuration for a specific action
    function getConfig(action) {
        return actions[action] ?? defaultConfig;
    }

    // Check if an action allows monitor capture buttons
    function allowsMonitorButtons(action) {
        return getConfig(action).allowsMonitorButtons;
    }

    // Get the MaterialShape.Shape enum value for an action
    function getShape(action) {
        return getConfig(action).shape;
    }

    // Get the icon name for an action
    function getIcon(action) {
        return getConfig(action).icon;
    }

    // Get circle selection config path if applicable
    function getCircleSelectionConfig(action) {
        return getConfig(action).circleSelectionConfig;
    }
}
