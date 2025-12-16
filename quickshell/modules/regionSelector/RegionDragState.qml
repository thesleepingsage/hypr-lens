import QtQuick

// Encapsulates drag and selection state for region selection
// Each RegionSelection instance creates its own RegionDragState
QtObject {
    id: root

    // Drag tracking
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property bool dragging: false
    property var mouseButton: null
    property list<point> points: []

    // Computed drag properties
    readonly property real dragDiffX: draggingX - dragStartX
    readonly property real dragDiffY: draggingY - dragStartY
    readonly property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)

    // Selection region (computed from drag or set explicitly)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)
    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)

    // Targeted region (hovered)
    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0

    function targetedRegionValid(): bool {
        return (targetedRegionX >= 0 && targetedRegionY >= 0);
    }

    function setTargetedRegion(region) {
        if (region) {
            targetedRegionX = region.at[0];
            targetedRegionY = region.at[1];
            targetedRegionWidth = region.size[0];
            targetedRegionHeight = region.size[1];
        } else {
            clearTargetedRegion();
        }
    }

    function clearTargetedRegion() {
        targetedRegionX = -1;
        targetedRegionY = -1;
        targetedRegionWidth = 0;
        targetedRegionHeight = 0;
    }

    function setRegionToTargeted(padding: real) {
        regionX = targetedRegionX - padding;
        regionY = targetedRegionY - padding;
        regionWidth = targetedRegionWidth + padding * 2;
        regionHeight = targetedRegionHeight + padding * 2;
    }

    function startDrag(x: real, y: real, button) {
        dragStartX = x;
        dragStartY = y;
        draggingX = x;
        draggingY = y;
        dragging = true;
        mouseButton = button;
    }

    function updateDrag(x: real, y: real) {
        if (!dragging) return;
        draggingX = x;
        draggingY = y;
        points.push({ x: x, y: y });
    }

    function endDrag() {
        dragging = false;
    }

    function reset() {
        dragStartX = 0;
        dragStartY = 0;
        draggingX = 0;
        draggingY = 0;
        dragging = false;
        mouseButton = null;
        points = [];
        clearTargetedRegion();
    }

    // Compute bounding box from circle selection points
    // padding: extra space around the bounding box
    // fallbackX, fallbackY: coordinates to use if no points recorded
    function setRegionFromCirclePoints(padding: real, fallbackX: real, fallbackY: real) {
        const dragPoints = (points.length > 0) ? points : [{ x: fallbackX, y: fallbackY }];
        const maxX = Math.max(...dragPoints.map(p => p.x));
        const minX = Math.min(...dragPoints.map(p => p.x));
        const maxY = Math.max(...dragPoints.map(p => p.y));
        const minY = Math.min(...dragPoints.map(p => p.y));
        regionX = minX - padding;
        regionY = minY - padding;
        regionWidth = maxX - minX + padding * 2;
        regionHeight = maxY - minY + padding * 2;
    }
}
