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
    enum CaptureMode { Instant, Crop }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    // int, not var: int properties skip the changed signal on same-value writes, so
    // redundant assignments (sessionReset, echo paths) can't retrigger onCaptureModeChanged
    property int captureMode: RegionSelection.CaptureMode.Instant
    // Crop mode: true while the adjustable crop editor is open (post-release, pre-confirm)
    property bool cropEditing: false
    // Freehand true-shape capture: the drawn path, staged by the freehand release branch
    // for the immediately following snip() (which masks pixels outside it). Empty for
    // every other path — rect drags, target clicks, monitor buttons, crop confirms.
    property var pendingSnipPoints: []
    signal dismiss()

    property bool isCropMode: (root.captureMode === RegionSelection.CaptureMode.Crop)

    // Swapping capture modes resets the editor and any in-progress drag — never the
    // frame or the selection mode. Circle works in Crop too: the drawn loop's bounding
    // box seeds the editor. Lives here so both the C key and the toolbar tabs get the
    // same behavior.
    onCaptureModeChanged: {
        root.cropEditing = false;
        root.pendingSnipPoints = [];
        dragState.reset();
    }

    // Restore session defaults when a capture shortcut re-triggers while the overlay is
    // already open. Local writes (the C key) break the captureMode binding from
    // RegionSelector, so the reset must be pushed as a call, not a binding.
    function sessionReset() {
        root.cropEditing = false;
        root.pendingSnipPoints = [];
        dragState.reset();
        root.captureMode = RegionSelection.CaptureMode.Instant;
    }

    // Monitor capture support
    property var allMonitors: []
    property string targetMonitorCapture: ""
    signal captureMonitorRequested(string monitorName)

    // Watch for cross-monitor capture requests (only when UI is visible and ready)
    onTargetMonitorCaptureChanged: {
        if (!root.visible || targetMonitorCapture === "" || targetMonitorCapture !== root.hyprlandMonitor.name) return;
        captureFullMonitorLocal();
    }

    // Open the crop editor seeded with the given rect, normalized for editability:
    // clamped to screen bounds, then grown per axis to >= minSize while staying on
    // screen. Every editor entry path (drag release, targeted click, full monitor)
    // goes through here so sub-minSize or offscreen seeds can't produce an editor
    // with unreachable handles or jumping clamps.
    // Seeds via dragState.seedRect (endpoint writes) — region* bindings stay intact.
    function openCropEditor(x, y, w, h) {
        const minSize = Math.max(1, Config.options.regionSelector.crop.minSize);
        const clamped = RegionUtils.clampRegionToScreen(
            { x: x, y: y, width: w, height: h },
            root.screen.width, root.screen.height
        );
        const rw = Math.min(root.screen.width, Math.max(clamped.width, minSize));
        const rh = Math.min(root.screen.height, Math.max(clamped.height, minSize));
        const rx = Math.min(clamped.x, root.screen.width - rw);
        const ry = Math.min(clamped.y, root.screen.height - rh);
        dragState.seedRect(rx, ry, rw, rh);
        dragState.endDrag();
        root.cropEditing = true;
    }

    // Confirm the crop editor: latch it closed before dispatching so a held Enter
    // key or a queued FAB click can't fire snip() a second time before teardown
    function confirmCrop() {
        if (!root.cropEditing) return;
        root.cropEditing = false;
        root.snip();
    }

    // Capture the full region of this monitor
    function captureFullMonitorLocal() {
        root.pendingSnipPoints = [];  // full-monitor capture is never freehand-masked
        if (root.isCropMode) {
            // Crop: seed the editor with the full-monitor rect instead of snipping
            root.openCropEditor(0, 0, root.screen.width, root.screen.height);
            return;
        }
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
    RegionDragState {
        id: dragState
        dragThreshold: root.isCircleSelection ? 0 : Math.max(0, Config.options.regionSelector.dragThreshold)
    }

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
        [RegionSelection.SnipAction.Copy]: (rx, ry, rw, rh, absX, absY, polygon) =>
            SnipCommands.buildCopyCommand(root.screenshotPath, rx, ry, rw, rh, root.saveScreenshotDir, Config.options.screenSnip.copyAlsoSaves, polygon),
        [RegionSelection.SnipAction.Edit]: (rx, ry, rw, rh, absX, absY, polygon) =>
            SnipCommands.buildEditCommand(root.screenshotPath, rx, ry, rw, rh, root.saveScreenshotDir, Config.options.screenSnip.copyAlsoSaves, polygon),
        [RegionSelection.SnipAction.Search]: (rx, ry, rw, rh, absX, absY, polygon) =>
            SnipCommands.buildSearchCommand(root.screenshotPath, rx, ry, rw, rh, "https://lens.google.com", polygon),
        [RegionSelection.SnipAction.CharRecognition]: (rx, ry, rw, rh, absX, absY, polygon) =>
            SnipCommands.buildOcrCommand(root.screenshotPath, rx, ry, rw, rh, polygon),
        // Recording is rectangle-only (wf-recorder captures rects); polygon unused
        [RegionSelection.SnipAction.Record]: (rx, ry, rw, rh, absX, absY, polygon) =>
            SnipCommands.buildRecordCommand(Directories.recordScriptPath, absX, absY, rw, rh, false),
        [RegionSelection.SnipAction.RecordWithSound]: (rx, ry, rw, rh, absX, absY, polygon) =>
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

        // Freehand true-shape mask: transform the staged path to crop-local physical
        // pixels, downsampled to <= 150 vertices (a slow scribble records hundreds of
        // samples; ImageMagick doesn't need them all). Empty string = plain bbox crop.
        let polygon = "";
        if (root.pendingSnipPoints.length >= 3) {
            const pts = root.pendingSnipPoints;
            const stride = Math.max(1, Math.ceil(pts.length / 150));
            const parts = [];
            for (let i = 0; i < pts.length; i += stride) {
                const px = Math.round((pts[i].x - clamped.x) * root.monitorScale);
                const py = Math.round((pts[i].y - clamped.y) * root.monitorScale);
                parts.push(`${px},${py}`);
            }
            polygon = parts.join(" ");
        }
        root.pendingSnipPoints = [];

        // Build command using table-driven approach
        const builder = commandBuilders[root.action];
        if (!builder) {
            console.warn("[Region Selector] Unknown snip action, skipping snip.");
            root.dismiss();
            return;
        }
        snipProc.command = builder(rx, ry, rw, rh, absX, absY, polygon);

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
        id: screencopyView
        anchors.fill: parent
        live: false
        captureSource: root.screen

        focus: root.visible
        // QQC2 buttons (toolbar tabs, FABs, monitor buttons) grab focus on click and
        // would silently kill Esc/C/Enter. Nothing else in the overlay takes keyboard
        // input, so always reclaim it while visible.
        onActiveFocusChanged: {
            if (root.visible && !screencopyView.activeFocus) screencopyView.forceActiveFocus();
        }
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.cropEditing) {
                    // First Esc: cancel the editor, back to draw (frame retained)
                    root.cropEditing = false;
                    dragState.reset();
                } else {
                    root.dismiss();
                }
            } else if (event.key === Qt.Key_C && event.modifiers === Qt.NoModifier && !dragState.dragging) {
                // Hardcoded toggle, per-screen scope (same as the Rect/Circle toolbar
                // toggle). Ignored mid-drag: the mode swap resets dragState, and the
                // orphaned release would then dismiss the overlay as an empty click.
                root.captureMode = root.isCropMode
                    ? RegionSelection.CaptureMode.Instant
                    : RegionSelection.CaptureMode.Crop;
            } else if (event.key === Qt.Key_R && event.modifiers === Qt.NoModifier && !dragState.dragging && !root.cropEditing) {
                // Rect/Freehand toggle — same guards as C (no mid-drag swaps), plus
                // inert while the editor is open, matching the toolbar tab gating
                root.selectionMode = root.selectionMode === RegionSelection.SelectionMode.RectCorners
                    ? RegionSelection.SelectionMode.Circle
                    : RegionSelection.SelectionMode.RectCorners;
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) && root.cropEditing && !event.isAutoRepeat) {
                root.confirmCrop();
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            // While the crop editor is open, CropHandles owns the mouse
            // (MouseArea.enabled only mutes this area, not its children)
            enabled: !root.cropEditing

            // Controls
            onPressed: (mouse) => {
                // Every new gesture invalidates any freehand mask staged by a previous
                // (e.g. Esc-cancelled) selection
                root.pendingSnipPoints = [];
                dragState.startDrag(mouse.x, mouse.y, mouse.button);
                root.updateTargetedRegion(mouse.x, mouse.y);
            }
            onReleased: (mouse) => {
                // Detect if it was a click -> Try to select targeted region
                if (!dragState.draggedAway) {
                    if (dragState.targetedRegionValid()) {
                        const padding = Config.options.regionSelector.targetRegions.selectionPadding;
                        if (root.isCropMode) {
                            // Crop: open the editor seeded with the padded target
                            // (openCropEditor normalizes edge-of-screen overhang)
                            root.openCropEditor(
                                dragState.targetedRegionX - padding,
                                dragState.targetedRegionY - padding,
                                dragState.targetedRegionWidth + padding * 2,
                                dragState.targetedRegionHeight + padding * 2
                            );
                            return;
                        } else {
                            dragState.setRegionToTargeted(padding);
                        }
                    } else {
                        dragState.endDrag();
                        root.dismiss();
                        return;
                    }
                }
                // Circle dragging?
                else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                    const padding = Config.options.regionSelector.circle.padding + Config.options.regionSelector.circle.strokeWidth / 2;
                    if (root.isCropMode) {
                        // Crop: seed the editor from the loop's bounding box WITHOUT
                        // setRegionFromCirclePoints — that writes region* directly and
                        // would break the bindings Esc-back-to-draw depends on.
                        // No mask staging: the crop editor is a rectangle tool, and a
                        // mask its handles can't reshape only confuses — true-shape
                        // capture is Instant-mode freehand only.
                        const box = dragState.circleBoundingBox(padding, mouseArea.mouseX, mouseArea.mouseY);
                        dragState.endDrag();
                        root.openCropEditor(box.x, box.y, box.width, box.height);
                        return;
                    }
                    dragState.setRegionFromCirclePoints(padding, mouseArea.mouseX, mouseArea.mouseY);
                    // True-shape capture (Instant only): stage the path for snip()'s
                    // polygon mask. Degenerate paths (< 3 vertices) keep the bbox.
                    if (dragState.points.length >= 3) {
                        root.pendingSnipPoints = dragState.points.slice();
                    }
                }
                dragState.endDrag();
                if (root.isCropMode) {
                    // Crop: open the adjustable editor instead of dispatching
                    // (openCropEditor normalizes sub-minSize/one-axis drags)
                    root.openCropEditor(dragState.regionX, dragState.regionY,
                                        dragState.regionWidth, dragState.regionHeight);
                    return;
                }
                root.snip();
            }
            onPositionChanged: (mouse) => {
                root.updateTargetedRegion(mouse.x, mouse.y);
                dragState.updateDrag(mouse.x, mouse.y);
            }
            
            Loader {
                z: 2
                anchors.fill: parent
                // Also active while crop-editing regardless of selection mode: the editor
                // is always rectangular (a circle seed becomes its bounding box)
                active: root.selectionMode === RegionSelection.SelectionMode.RectCorners || root.cropEditing
                sourceComponent: RectCornersSelectionDetails {
                    regionX: dragState.regionX
                    regionY: dragState.regionY
                    regionWidth: dragState.regionWidth
                    regionHeight: dragState.regionHeight
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                    // mouseArea is muted while crop-editing, so hide the (frozen) crosshair
                    showAimLines: Config.options.regionSelector.rect.showAimLines && !root.cropEditing
                }
            }

            // Crop editor: resize handles + interior move-grab, rendered above the
            // selection details (border/label stay live via the region* bindings)
            Loader {
                z: 5
                anchors.fill: parent
                active: root.cropEditing
                sourceComponent: CropHandles {
                    dragState: dragState
                    screenWidth: root.screen.width
                    screenHeight: root.screen.height
                    handleColor: root.selectionBorderColor
                    handleBorderColor: root.onBorderColor
                }
            }

            Loader {
                z: 2
                anchors.fill: parent
                // Hidden while crop-editing: the drawn loop has been consumed into the
                // editor's rect (and dragState.points survive until the next reset)
                active: root.selectionMode === RegionSelection.SelectionMode.Circle && !root.cropEditing
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
                radius: HyprlandData.decorationRounding
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
                radius: HyprlandData.decorationRounding
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
                    cropEditing: root.cropEditing
                    // Single source of truth is root.captureMode/selectionMode: state flows
                    // down through these bindings, tab clicks flow up as *Selected requests.
                    // (The old bidirectional Synchronizers + index write-backs desynced once
                    // the C key became an external writer.)
                    selectionMode: root.selectionMode
                    captureMode: root.captureMode
                    onSelectionModeSelected: (mode) => {
                        if (root.selectionMode !== mode) root.selectionMode = mode;
                    }
                    onCaptureModeSelected: (mode) => {
                        if (root.captureMode !== mode) root.captureMode = mode;
                    }
                    Synchronizer on action {
                        property alias source: root.action
                    }
                    onDismiss: root.dismiss();
                    onCaptureFullMonitor: (monitorName) => root.captureFullMonitor(monitorName)
                    onEditFullMonitor: (monitorName) => root.editFullMonitor(monitorName)
                }
                Item {
                    visible: root.cropEditing
                    anchors {
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: confirmFab.implicitWidth
                    implicitHeight: confirmFab.implicitHeight
                    StyledRectangularShadow {
                        target: confirmFab
                        radius: confirmFab.buttonRadius
                    }
                    FloatingActionButton {
                        id: confirmFab
                        baseSize: 48
                        iconText: "check"
                        onClicked: root.confirmCrop();
                        StyledToolTip {
                            text: Translation.tr("Confirm")
                        }
                    }
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
