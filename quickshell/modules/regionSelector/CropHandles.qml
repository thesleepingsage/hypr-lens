pragma ComponentBehavior: Bound
import "../common"
import "RegionUtils.js" as RegionUtils
import QtQuick

// Crop editor interaction layer: 8 resize handles (4 corners + 4 edges) plus an
// interior move-grab over the current selection region.
//
// Load-bearing invariant: dragState.region* are bindings over the drag endpoints
// (dragStart*/dragging*). This component NEVER assigns region* directly — every
// mutation goes through dragState.seedRect (endpoint writes), which also keeps the
// rect normalized so "drag left edge past right" cannot flip min/abs on us.
// startDrag is never called either, so dragState.mouseButton (the Copy/Edit
// discriminator from the seeding gesture) survives the whole edit session.
Item {
    id: root
    required property var dragState
    required property real screenWidth
    required property real screenHeight
    required property color handleColor
    required property color handleBorderColor

    // Config values clamped at the consumption site (same idea as the
    // Math.max(0, ...dragThreshold) guard in RegionSelection): minSize <= 0 would
    // let the rect collapse to nothing, handleSize <= 0 would be ungrabbable
    readonly property int minSize: Math.max(1, Config.options.regionSelector.crop.minSize)
    readonly property int handleSize: Math.max(4, Config.options.regionSelector.crop.handleSize)
    // Hit target is larger than the visual so handles stay grabbable when small,
    // but shrinks with the rect (floored at the visual size) so the 8 hit areas
    // can't fully overlap — and shadow each other — at min rect size
    readonly property real hitSize: Math.max(handleSize,
        Math.min(handleSize * 2, Math.min(dragState.regionWidth, dragState.regionHeight) / 2))

    // Rect + pointer position captured at press; deltas are applied against these
    // so per-event rounding/clamping never accumulates
    property real pressRectX: 0
    property real pressRectY: 0
    property real pressRectW: 0
    property real pressRectH: 0
    property real pressMouseX: 0
    property real pressMouseY: 0

    function beginGrab(item, mouse) {
        pressRectX = root.dragState.regionX;
        pressRectY = root.dragState.regionY;
        pressRectW = root.dragState.regionWidth;
        pressRectH = root.dragState.regionHeight;
        const p = item.mapToItem(root, mouse.x, mouse.y);
        pressMouseX = p.x;
        pressMouseY = p.y;
    }

    // Resize: move only the grabbed edges, clamping each axis to >= minSize and
    // to the screen bounds. Edges that aren't grabbed stay anchored.
    function applyResize(item, mouse, grabLeft, grabTop, grabRight, grabBottom) {
        const p = item.mapToItem(root, mouse.x, mouse.y);
        const dx = p.x - pressMouseX;
        const dy = p.y - pressMouseY;
        let left = pressRectX;
        let top = pressRectY;
        let right = pressRectX + pressRectW;
        let bottom = pressRectY + pressRectH;
        if (grabLeft) left = Math.min(Math.max(0, pressRectX + dx), right - root.minSize);
        if (grabTop) top = Math.min(Math.max(0, pressRectY + dy), bottom - root.minSize);
        if (grabRight) right = Math.max(Math.min(root.screenWidth, right + dx), left + root.minSize);
        if (grabBottom) bottom = Math.max(Math.min(root.screenHeight, bottom + dy), top + root.minSize);
        seedClamped(left, top, right - left, bottom - top);
    }

    // Move: translate the whole rect, keeping its size
    function applyMove(item, mouse) {
        const p = item.mapToItem(root, mouse.x, mouse.y);
        const x = Math.max(0, Math.min(pressRectX + (p.x - pressMouseX), root.screenWidth - pressRectW));
        const y = Math.max(0, Math.min(pressRectY + (p.y - pressMouseY), root.screenHeight - pressRectH));
        seedClamped(x, y, pressRectW, pressRectH);
    }

    // Final guard on every mutation: clamp to screen, then write endpoints only
    function seedClamped(x, y, w, h) {
        const clamped = RegionUtils.clampRegionToScreen(
            { x: x, y: y, width: w, height: h },
            root.screenWidth, root.screenHeight
        );
        root.dragState.seedRect(clamped.x, clamped.y, clamped.width, clamped.height);
    }

    // Interior move-grab (below the handles so they win on overlap)
    MouseArea {
        id: moveArea
        z: 1
        x: root.dragState.regionX
        y: root.dragState.regionY
        width: root.dragState.regionWidth
        height: root.dragState.regionHeight
        cursorShape: Qt.SizeAllCursor
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        onPressed: (mouse) => root.beginGrab(moveArea, mouse)
        onPositionChanged: (mouse) => {
            if (moveArea.pressed) root.applyMove(moveArea, mouse);
        }
    }

    // 8 handles: fx/fy are the handle's fractional position on the rect
    // (0 = left/top edge, 0.5 = edge midpoint, 1 = right/bottom edge)
    Repeater {
        model: [
            { fx: 0.0, fy: 0.0, cursor: Qt.SizeFDiagCursor }, // top-left
            { fx: 0.5, fy: 0.0, cursor: Qt.SizeVerCursor },   // top
            { fx: 1.0, fy: 0.0, cursor: Qt.SizeBDiagCursor }, // top-right
            { fx: 0.0, fy: 0.5, cursor: Qt.SizeHorCursor },   // left
            { fx: 1.0, fy: 0.5, cursor: Qt.SizeHorCursor },   // right
            { fx: 0.0, fy: 1.0, cursor: Qt.SizeBDiagCursor }, // bottom-left
            { fx: 0.5, fy: 1.0, cursor: Qt.SizeVerCursor },   // bottom
            { fx: 1.0, fy: 1.0, cursor: Qt.SizeFDiagCursor }  // bottom-right
        ]
        delegate: MouseArea {
            id: handleArea
            required property var modelData
            // Corners above edge midpoints: on small rects their hit areas still
            // brush against each other, and the corner must win the overlap
            z: (handleArea.modelData.fx === 0.5 || handleArea.modelData.fy === 0.5) ? 2 : 3
            x: root.dragState.regionX + handleArea.modelData.fx * root.dragState.regionWidth - root.hitSize / 2
            y: root.dragState.regionY + handleArea.modelData.fy * root.dragState.regionHeight - root.hitSize / 2
            width: root.hitSize
            height: root.hitSize
            cursorShape: handleArea.modelData.cursor
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            onPressed: (mouse) => root.beginGrab(handleArea, mouse)
            onPositionChanged: (mouse) => {
                if (handleArea.pressed) {
                    root.applyResize(handleArea, mouse,
                        handleArea.modelData.fx === 0.0, handleArea.modelData.fy === 0.0,
                        handleArea.modelData.fx === 1.0, handleArea.modelData.fy === 1.0);
                }
            }

            // Handle visual: filled dot matching the selection border color
            Rectangle {
                anchors.centerIn: parent
                width: root.handleSize
                height: root.handleSize
                radius: root.handleSize / 2
                color: root.handleColor
                border.color: root.handleBorderColor
                border.width: 1
            }
        }
    }
}
