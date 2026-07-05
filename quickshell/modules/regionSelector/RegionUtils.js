// RegionUtils.js - Utility functions for region selector
// This is a Qt/QML JavaScript library (.pragma library makes it stateless)
.pragma library

// Clamp a region to fit within screen bounds.
// Returns a new object with clamped coordinates; does not modify input.
function clampRegionToScreen(region, screenWidth, screenHeight) {
    // Trim, don't slide: dimensions are computed from the region's original right/bottom
    // edge, so left/top overhang shrinks the region (capturing only its visible extent)
    // instead of translating it on-screen at full size over unrelated content
    const clampedX = Math.max(0, Math.min(region.x, screenWidth));
    const clampedY = Math.max(0, Math.min(region.y, screenHeight));
    const clampedWidth = Math.max(0, Math.min(region.x + region.width, screenWidth) - clampedX);
    const clampedHeight = Math.max(0, Math.min(region.y + region.height, screenHeight) - clampedY);

    return {
        x: clampedX,
        y: clampedY,
        width: clampedWidth,
        height: clampedHeight
    };
}

// Sort monitors by layout position (Hyprland logical coordinates):
// ascending x, ties broken by ascending y (left-to-right, then top-to-bottom).
// Returns a new sorted array; does not modify input.
function sortMonitorsByPosition(monitors) {
    return [...monitors].sort((a, b) => a.x - b.x || a.y - b.y);
}

// Build a monitor info object from Quickshell screen and Hyprland monitor data.
// Used to create the monitor list for the capture buttons.
// x/y are the layout position (Hyprland logical coordinates). A null
// hyprlandMonitor falls back to ShellScreen's virtual desktop position, which
// tracks the same layout in practice; the caller logs the fallback.
function buildMonitorInfo(screen, hyprlandMonitor) {
    if (!hyprlandMonitor) {
        return {
            name: screen.name,
            x: screen.x,
            y: screen.y
        };
    }
    return {
        name: hyprlandMonitor.name,
        x: hyprlandMonitor.x,
        y: hyprlandMonitor.y
    };
}
