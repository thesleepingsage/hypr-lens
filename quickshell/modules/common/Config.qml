pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Minimal Config for hypr-lens
Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptions
    property bool ready: false

    Timer {
        id: fileReloadTimer
        interval: 50
        repeat: false
        onTriggered: configFileView.reload()
    }

    Timer {
        id: fileWriteTimer
        interval: 50
        repeat: false
        onTriggered: configFileView.writeAdapter()
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        // Config schema - see CONFIG_README.md for full documentation
        JsonAdapter {
            id: configOptions

            // ─── Appearance ───────────────────────────────────────────────
            property JsonObject appearance: JsonObject {
                property string matugenPath: ""  // Custom matugen.json path (empty = default)

                // Ripple: button click effect
                property JsonObject ripple: JsonObject {
                    property bool usePrimaryColor: true  // true = accent color, false = gray
                    property real colorMixRatio: 0.65    // 0.0 = bold, 1.0 = invisible
                    property real solidRadius: 0.45      // Solid color extent (0.0-1.0)
                    property real fadeRadius: 0.7        // Fade endpoint (0.0-1.0)
                }
            }

            // ─── Screenshots ──────────────────────────────────────────────
            property JsonObject screenSnip: JsonObject {
                property string savePath: ""  // Save location (empty = ~/Pictures/hypr-lens)
                property bool copyAlsoSaves: false  // true = Copy mode also saves to disk, false = clipboard only
            }

            // ─── Screen Recording ─────────────────────────────────────────
            property JsonObject screenRecord: JsonObject {
                property string savePath: ""  // Save location (empty = ~/Videos/hypr-lens)
            }

            // ─── OCR ──────────────────────────────────────────────────────
            property JsonObject ocr: JsonObject {
                property bool useCircleSelection: false  // true = circle tool, false = rectangle
            }

            // ─── Image Search ─────────────────────────────────────────────
            property JsonObject search: JsonObject {
                property JsonObject imageSearch: JsonObject {
                    property bool useCircleSelection: false  // true = circle tool, false = rectangle
                }
            }

            // ─── Monitor Order ───────────────────────────────────────────
            // Monitor button order for full-screen capture (empty = auto-detect)
            // Example: ["DP-2", "DP-1"] to show DP-2 first
            property var monitorOrder: []

            // ─── Region Selector ──────────────────────────────────────────
            property JsonObject regionSelector: JsonObject {
                // Auto-detection of clickable regions
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true           // Detect window boundaries
                    property bool layers: false           // Detect Hyprland layers
                    property bool content: true           // OpenCV content detection
                    property bool showLabel: false        // Show region labels
                    property real opacity: 0.3            // Highlight opacity (0.0-1.0)
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5      // Extra pixels around regions
                }
                // Rectangle selection tool
                property JsonObject rect: JsonObject {
                    property bool showAimLines: true      // Crosshair when drawing
                }
                // Circle selection tool
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6           // Outline thickness
                    property int padding: 10              // Extra space around selection
                }
            }
        }
    }
}
