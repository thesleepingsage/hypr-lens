pragma ComponentBehavior: Bound
import "../common"
import "../common/functions"
import "../common/widgets"
import "../../services"
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

    // TODO: Ask: sidebar AI; Ocr: tesseract
    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound } 
    enum SelectionMode { RectCorners, Circle }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    signal dismiss()
    
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

    function snip() {
        // Validity check
        if (dragState.regionWidth <= 0 || dragState.regionHeight <= 0) {
            console.warn("[Region Selector] Invalid region size, skipping snip.");
            root.dismiss();
            return;
        }

        // Clamp region to screen bounds
        dragState.regionX = Math.max(0, Math.min(dragState.regionX, root.screen.width - dragState.regionWidth));
        dragState.regionY = Math.max(0, Math.min(dragState.regionY, root.screen.height - dragState.regionHeight));
        dragState.regionWidth = Math.max(0, Math.min(dragState.regionWidth, root.screen.width - dragState.regionX));
        dragState.regionHeight = Math.max(0, Math.min(dragState.regionHeight, root.screen.height - dragState.regionY));

        // Adjust action based on mouse button
        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = dragState.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        // Scale coordinates to physical pixels
        const rx = Math.round(dragState.regionX * root.monitorScale);
        const ry = Math.round(dragState.regionY * root.monitorScale);
        const rw = Math.round(dragState.regionWidth * root.monitorScale);
        const rh = Math.round(dragState.regionHeight * root.monitorScale);
        // Absolute coordinates for recording (add monitor offset)
        const absX = rx + Math.round(root.monitorOffsetX * root.monitorScale);
        const absY = ry + Math.round(root.monitorOffsetY * root.monitorScale);

        // Build command using SnipCommands singleton
        switch (root.action) {
            case RegionSelection.SnipAction.Copy:
                snipProc.command = SnipCommands.buildCopyCommand(
                    root.screenshotPath, rx, ry, rw, rh, root.saveScreenshotDir
                );
                break;
            case RegionSelection.SnipAction.Edit:
                snipProc.command = SnipCommands.buildEditCommand(root.screenshotPath, rx, ry, rw, rh);
                break;
            case RegionSelection.SnipAction.Search:
                snipProc.command = SnipCommands.buildSearchCommand(
                    root.screenshotPath, rx, ry, rw, rh,
                    "https://lens.google.com"  // Clipboard-based: user pastes with Ctrl+V
                );
                break;
            case RegionSelection.SnipAction.CharRecognition:
                snipProc.command = SnipCommands.buildOcrCommand(root.screenshotPath, rx, ry, rw, rh);
                break;
            case RegionSelection.SnipAction.Record:
                snipProc.command = SnipCommands.buildRecordCommand(Directories.recordScriptPath, absX, absY, rw, rh, false);
                break;
            case RegionSelection.SnipAction.RecordWithSound:
                snipProc.command = SnipCommands.buildRecordCommand(Directories.recordScriptPath, absX, absY, rw, rh, true);
                break;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                root.dismiss();
                return;
        }

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
                    const dragPoints = (dragState.points.length > 0) ? dragState.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                    const maxX = Math.max(...dragPoints.map(p => p.x));
                    const minX = Math.min(...dragPoints.map(p => p.x));
                    const maxY = Math.max(...dragPoints.map(p => p.y));
                    const minY = Math.min(...dragPoints.map(p => p.y));
                    dragState.regionX = minX - padding;
                    dragState.regionY = minY - padding;
                    dragState.regionWidth = maxX - minX + padding * 2;
                    dragState.regionHeight = maxY - minY + padding * 2;
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

            // Controls
            Row {
                id: regionSelectionControls
                z: 9999
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: -height
                }
                opacity: 0
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (!visible) return;
                        regionSelectionControls.anchors.bottomMargin = 8;
                        regionSelectionControls.opacity = 1;
                    }
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on anchors.bottomMargin {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                spacing: 6

                OptionsToolbar {
                    Synchronizer on action {
                        property alias source: root.action
                    }
                    Synchronizer on selectionMode {
                        property alias source: root.selectionMode
                    }
                    onDismiss: root.dismiss();
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
