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
    property real dragThreshold: 0

    // Computed drag properties
    readonly property real dragDiffX: draggingX - dragStartX
    readonly property real dragDiffY: draggingY - dragStartY
    readonly property bool draggedAway: (Math.abs(dragDiffX) > dragThreshold || Math.abs(dragDiffY) > dragThreshold)

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
    // Validity is a dedicated flag, not a sign check on the coordinates: origins are
    // legitimately negative for windows/layers straddling the monitor's left/top edge
    // (so even (-1,-1) can be a real origin). What keeps the cleared values from ever
    // matching a real region in the repeaters' equality highlight is the zero size.
    property bool targetedRegionActive: false

    function targetedRegionValid(): bool {
        return targetedRegionActive;
    }

    function setTargetedRegion(region) {
        if (region) {
            targetedRegionX = region.at[0];
            targetedRegionY = region.at[1];
            targetedRegionWidth = region.size[0];
            targetedRegionHeight = region.size[1];
            targetedRegionActive = true;
        } else {
            clearTargetedRegion();
        }
    }

    function clearTargetedRegion() {
        targetedRegionX = -1;
        targetedRegionY = -1;
        targetedRegionWidth = 0;
        targetedRegionHeight = 0;
        targetedRegionActive = false;
    }

    function setRegionToTargeted(padding: real) {
        regionX = targetedRegionX - padding;
        regionY = targetedRegionY - padding;
        regionWidth = targetedRegionWidth + padding * 2;
        regionHeight = targetedRegionHeight + padding * 2;
    }

    // Seed the selection region by writing drag endpoints (Crop mode).
    // The only sanctioned way Crop paths set geometry: region* are bindings
    // over dragStart*/dragging*, and assigning them directly would break the
    // bindings for the rest of the overlay session (Esc-back-to-draw).
    function seedRect(x: real, y: real, w: real, h: real) {
        dragStartX = x;
        dragStartY = y;
        draggingX = x + w;
        draggingY = y + h;
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

    // Compute the padded bounding box of the circle selection points without touching
    // any state — safe for crop-mode seeding, where region* must stay binding-driven
    // padding: extra space around the bounding box
    // fallbackX, fallbackY: coordinates to use if no points recorded
    function circleBoundingBox(padding: real, fallbackX: real, fallbackY: real): var {
        const dragPoints = (points.length > 0) ? points : [{ x: fallbackX, y: fallbackY }];
        const maxX = Math.max(...dragPoints.map(p => p.x));
        const minX = Math.min(...dragPoints.map(p => p.x));
        const maxY = Math.max(...dragPoints.map(p => p.y));
        const minY = Math.min(...dragPoints.map(p => p.y));
        return {
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + padding * 2,
            height: maxY - minY + padding * 2
        };
    }

    // Set the selection region to the circle points' bounding box (breaks the region*
    // bindings — only safe on paths that end in dispatch/dismissal)
    function setRegionFromCirclePoints(padding: real, fallbackX: real, fallbackY: real) {
        const box = circleBoundingBox(padding, fallbackX, fallbackY);
        regionX = box.x;
        regionY = box.y;
        regionWidth = box.width;
        regionHeight = box.height;
    }
}
