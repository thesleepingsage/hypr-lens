pragma ComponentBehavior: Bound
import "../common"
import "../common/functions"
import "../common/widgets"
import "../../services"
import "RegionUtils.js" as RegionUtils
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound }
    enum SelectionMode { RectCorners, Circle }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    signal dismiss()

    // Monitor capture support
    property var allMonitors: []
    property string targetMonitorCapture: ""
    signal captureMonitorRequested(string monitorName)

    // Watch for cross-monitor capture requests (only when UI is visible and ready)
    onTargetMonitorCaptureChanged: {
        if (!root.visible || targetMonitorCapture === "" || targetMonitorCapture !== root.hyprlandMonitor.name) return;
        captureFullMonitorLocal();
    }

    // Capture the full region of this monitor
    function captureFullMonitorLocal() {
        dragState.regionX = 0;
        dragState.regionY = 0;
        dragState.regionWidth = root.screen.width;
        dragState.regionHeight = root.screen.height;
        dragState.endDrag();
        root.snip();
    }

    // Handle monitor button click - capture full screen of the specified monitor
    function captureFullMonitor(monitorName: string) {
        if (monitorName === root.hyprlandMonitor.name) {
            // This is our monitor, capture locally
            captureFullMonitorLocal();
        } else {
            // Request parent to coordinate capture on the target monitor
            root.captureMonitorRequested(monitorName);
        }
    }

    // Handle monitor button right-click - capture full screen and edit with swappy
    function editFullMonitor(monitorName: string) {
        root.action = RegionSelection.SnipAction.Edit;
        captureFullMonitor(monitorName);
    }
    
    property string saveScreenshotDir: Config.options.screenSnip.savePath !== ""
                                       ? Config.options.screenSnip.savePath
                                       : ""

    property string screenshotDir: Directories.screenshotTemp
    property color overlayColor: "#88111111"
    property color brightText: Appearance.m3colors.darkmode ? Appearance.colors.colOnLayer0 : Appearance.colors.colLayer0
    property color brightSecondary: Appearance.m3colors.darkmode ? Appearance.colors.colSecondary : Appearance.colors.colOnSecondary
    property color brightTertiary: Appearance.m3colors.darkmode ? Appearance.colors.colTertiary : Qt.lighter(Appearance.colors.colPrimary)
    property color selectionBorderColor: ColorUtils.mix(brightText, brightSecondary, 0.5)
    property color selectionFillColor: "#33ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: ColorUtils.transparentize(windowBorderColor, 0.85)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: ColorUtils.transparentize(imageBorderColor, 0.85)
    property color onBorderColor: "#ff000000"
    readonly property real falsePositivePreventionRatio: 0.5

    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: hyprlandMonitor.scale
    readonly property real monitorOffsetX: hyprlandMonitor.x
    readonly property real monitorOffsetY: hyprlandMonitor.y
    property int activeWorkspaceId: hyprlandMonitor.activeWorkspace?.id ?? 0
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}.png`
    property var imageRegions: []

    // Encapsulated drag/selection state
    RegionDragState { id: dragState }

    // Computed region lists using RegionFunctions
    readonly property list<var> layerRegions: RegionFunctions.computeLayerRegions(
        HyprlandData.layers, root.hyprlandMonitor.name, root.monitorOffsetX, root.monitorOffsetY
    )
    readonly property list<var> windowRegions: RegionFunctions.computeWindowRegions(
        HyprlandData.windowList, root.activeWorkspaceId, root.monitorOffsetX, root.monitorOffsetY, root.layerRegions
    )

    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: Config.options.regionSelector.targetRegions.windows && !isCircleSelection
    property bool enableLayerRegions: Config.options.regionSelector.targetRegions.layers && !isCircleSelection
    property bool enableContentRegions: Config.options.regionSelector.targetRegions.content
    property real targetRegionOpacity: Config.options.regionSelector.targetRegions.opacity
    property bool contentRegionOpacity: Config.options.regionSelector.targetRegions.contentRegionOpacity

    function updateTargetedRegion(x, y) {
        // Priority: content regions > layer regions > window regions
        const clickedRegion = RegionFunctions.findRegionAtPoint(root.imageRegions, x, y)
            ?? RegionFunctions.findRegionAtPoint(root.layerRegions, x, y)
            ?? RegionFunctions.findRegionAtPoint(root.windowRegions, x, y);
        dragState.setTargetedRegion(clickedRegion);
    }

    Process {
        id: screenshotProc
        running: true
        command: ["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}' && grim -o '${StringUtils.shellSingleQuoteEscape(root.screen.name)}' '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn(`[Region Selector] Screenshot capture failed (grim exit code ${exitCode})`);
                root.dismiss();
                return;
            }
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        command: ["pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached([Directories.recordScriptPath]);
            root.dismiss();
            return;
        }
        root.visible = true;
    }

    Process {
        id: imageDetectionProcess
        command: ["bash", "-c", `${Directories.scriptPath}/images/find-regions-venv.sh ` 
            + `--hyprctl ` 
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ` 
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} ` 
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                try {
                    if (imageDimensionCollector.text) {
                        imageRegions = RegionFunctions.filterImageRegions(
                            JSON.parse(imageDimensionCollector.text),
                            root.windowRegions
                        );
                    }
                } catch (e) {
                    // Ignore parse errors from empty/invalid output
                }
            }
        }
    }

    // Table of command builders indexed by SnipAction enum value.
    // Each builder takes (rx, ry, rw, rh, absX, absY) and returns a command array.
    readonly property var commandBuilders: ({
        [RegionSelection.SnipAction.Copy]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildCopyCommand(root.screenshotPath, rx, ry, rw, rh, root.saveScreenshotDir, Config.options.screenSnip.copyAlsoSaves),
        [RegionSelection.SnipAction.Edit]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildEditCommand(root.screenshotPath, rx, ry, rw, rh, root.saveScreenshotDir, Config.options.screenSnip.copyAlsoSaves),
        [RegionSelection.SnipAction.Search]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildSearchCommand(root.screenshotPath, rx, ry, rw, rh, "https://lens.google.com"),
        [RegionSelection.SnipAction.CharRecognition]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildOcrCommand(root.screenshotPath, rx, ry, rw, rh),
        [RegionSelection.SnipAction.Record]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildRecordCommand(Directories.recordScriptPath, absX, absY, rw, rh, false),
        [RegionSelection.SnipAction.RecordWithSound]: (rx, ry, rw, rh, absX, absY) =>
            SnipCommands.buildRecordCommand(Directories.recordScriptPath, absX, absY, rw, rh, true)
    })

    function snip() {
        // Validity check
        if (dragState.regionWidth <= 0 || dragState.regionHeight <= 0) {
            console.warn("[Region Selector] Invalid region size, skipping snip.");
            root.dismiss();
            return;
        }

        // Clamp region to screen bounds using utility function
        const clamped = RegionUtils.clampRegionToScreen({
            x: dragState.regionX,
            y: dragState.regionY,
            width: dragState.regionWidth,
            height: dragState.regionHeight
        }, root.screen.width, root.screen.height);
        dragState.regionX = clamped.x;
        dragState.regionY = clamped.y;
        dragState.regionWidth = clamped.width;
        dragState.regionHeight = clamped.height;

        // Adjust action based on mouse button (right-click = edit)
        // Only override if action is Copy - if already Edit (e.g., from monitor button right-click), keep it
        if (root.action === RegionSelection.SnipAction.Copy) {
            root.action = dragState.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        // Scale coordinates to physical pixels (monitors may have non-1x scaling)
        const rx = Math.round(clamped.x * root.monitorScale);
        const ry = Math.round(clamped.y * root.monitorScale);
        const rw = Math.round(clamped.width * root.monitorScale);
        const rh = Math.round(clamped.height * root.monitorScale);
        // Absolute coordinates for recording (add monitor offset for multi-monitor setups)
        const absX = rx + Math.round(root.monitorOffsetX * root.monitorScale);
        const absY = ry + Math.round(root.monitorOffsetY * root.monitorScale);

        // Build command using table-driven approach
        const builder = commandBuilders[root.action];
        if (!builder) {
            console.warn("[Region Selector] Unknown snip action, skipping snip.");
            root.dismiss();
            return;
        }
        snipProc.command = builder(rx, ry, rw, rh, absX, absY);

        snipProc.startDetached();
        root.dismiss();
    }

    Process {
        id: snipProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn(`[Region Selector] Snip process failed with exit code ${exitCode}`);
            }
        }
    }

    ScreencopyView {
        anchors.fill: parent
        live: false
        captureSource: root.screen

        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            // Controls
            onPressed: (mouse) => {
                dragState.startDrag(mouse.x, mouse.y, mouse.button);
            }
            onReleased: (mouse) => {
                // Detect if it was a click -> Try to select targeted region
                if (!dragState.draggedAway) {
                    if (dragState.targetedRegionValid()) {
                        const padding = Config.options.regionSelector.targetRegions.selectionPadding;
                        dragState.setRegionToTargeted(padding);
                    }
                }
                // Circle dragging?
                else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                    const padding = Config.options.regionSelector.circle.padding + Config.options.regionSelector.circle.strokeWidth / 2;
                    dragState.setRegionFromCirclePoints(padding, mouseArea.mouseX, mouseArea.mouseY);
                }
                dragState.endDrag();
                root.snip();
            }
            onPositionChanged: (mouse) => {
                root.updateTargetedRegion(mouse.x, mouse.y);
                dragState.updateDrag(mouse.x, mouse.y);
            }
            
            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
                sourceComponent: RectCornersSelectionDetails {
                    regionX: dragState.regionX
                    regionY: dragState.regionY
                    regionWidth: dragState.regionWidth
                    regionHeight: dragState.regionHeight
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                }
            }

            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.Circle
                sourceComponent: CircleSelectionDetails {
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                    points: dragState.points
                }
            }

            // Window regions
            TargetRegionRepeater {
                regions: root.enableWindowRegions ? root.windowRegions : []
                zIndex: 2
                showIcon: true
                borderColor: root.windowBorderColor
                fillColor: root.windowFillColor
                regionOpacity: root.targetRegionOpacity
                radius: Appearance.rounding.windowRounding
                labelProperty: "class"
                draggedAway: dragState.draggedAway
                targetedRegionX: dragState.targetedRegionX
                targetedRegionY: dragState.targetedRegionY
                targetedRegionWidth: dragState.targetedRegionWidth
                targetedRegionHeight: dragState.targetedRegionHeight
            }

            // Layer regions
            TargetRegionRepeater {
                regions: root.enableLayerRegions ? root.layerRegions : []
                zIndex: 3
                borderColor: root.windowBorderColor
                fillColor: root.windowFillColor
                regionOpacity: root.targetRegionOpacity
                radius: Appearance.rounding.windowRounding
                labelProperty: "namespace"
                draggedAway: dragState.draggedAway
                targetedRegionX: dragState.targetedRegionX
                targetedRegionY: dragState.targetedRegionY
                targetedRegionWidth: dragState.targetedRegionWidth
                targetedRegionHeight: dragState.targetedRegionHeight
            }

            // Content regions
            TargetRegionRepeater {
                regions: root.enableContentRegions ? root.imageRegions : []
                zIndex: 4
                borderColor: root.imageBorderColor
                fillColor: root.imageFillColor
                regionOpacity: root.contentRegionOpacity
                fixedLabel: Translation.tr("Content region")
                draggedAway: dragState.draggedAway
                targetedRegionX: dragState.targetedRegionX
                targetedRegionY: dragState.targetedRegionY
                targetedRegionWidth: dragState.targetedRegionWidth
                targetedRegionHeight: dragState.targetedRegionHeight
            }

            // Controls - slides up from bottom when visible
            Row {
                id: regionSelectionControls
                z: 9999
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                }
                spacing: 6

                // Slide-in animation using state binding
                state: root.visible ? "visible" : "hidden"
                states: [
                    State {
                        name: "hidden"
                        PropertyChanges { target: regionSelectionControls; opacity: 0; anchors.bottomMargin: -regionSelectionControls.height }
                    },
                    State {
                        name: "visible"
                        PropertyChanges { target: regionSelectionControls; opacity: 1; anchors.bottomMargin: 8 }
                    }
                ]
                transitions: [
                    Transition {
                        from: "hidden"; to: "visible"
                        NumberAnimation { property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                        NumberAnimation { property: "anchors.bottomMargin"; duration: 200; easing.type: Easing.OutCubic }
                    }
                ]

                OptionsToolbar {
                    monitors: root.allMonitors
                    Synchronizer on action {
                        property alias source: root.action
                    }
                    Synchronizer on selectionMode {
                        property alias source: root.selectionMode
                    }
                    onDismiss: root.dismiss();
                    onCaptureFullMonitor: (monitorName) => root.captureFullMonitor(monitorName)
                    onEditFullMonitor: (monitorName) => root.editFullMonitor(monitorName)
                }
                Item {
                    anchors {
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: closeFab.implicitWidth
                    implicitHeight: closeFab.implicitHeight
                    StyledRectangularShadow {
                        target: closeFab
                        radius: closeFab.buttonRadius
                    }
                    FloatingActionButton {
                        id: closeFab
                        baseSize: 48
                        iconText: "close"
                        onClicked: root.dismiss();
                        StyledToolTip {
                            text: Translation.tr("Close")
                        }
                        colBackground: Appearance.colors.colTertiaryContainer
                        colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                        colRipple: Appearance.colors.colTertiaryContainerActive
                        colOnBackground: Appearance.colors.colOnTertiaryContainer
                    }
                }
            }
            
        }
    }
}
