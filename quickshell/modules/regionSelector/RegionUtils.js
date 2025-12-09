// RegionUtils.js - Utility functions for region selector
// This is a Qt/QML JavaScript library (.pragma library makes it stateless)
.pragma library

// Parse monitorOrder from raw JSONC config text using regex.
// This approach bypasses JSON parsing issues with JSONC (comments + trailing commas).
// Returns an array of monitor names, or empty array if parsing fails.
function parseMonitorOrder(rawConfigText) {
    try {
        // Match "monitorOrder": ["name1", "name2", ...]
        const match = rawConfigText.match(/"monitorOrder"\s*:\s*\[([^\]]*)\]/);
        if (match && match[1]) {
            // Extract quoted strings from array contents
            const items = match[1].match(/"([^"]+)"/g);
            if (items) {
                return items.map(s => s.replace(/"/g, ''));
            }
        }
    } catch (e) {
        // Silent failure - return empty array
    }
    return [];
}

// Clamp a region to fit within screen bounds.
// Returns a new object with clamped coordinates; does not modify input.
function clampRegionToScreen(region, screenWidth, screenHeight) {
    // First clamp position, then clamp dimensions based on remaining space
    const clampedX = Math.max(0, Math.min(region.x, screenWidth - 1));
    const clampedY = Math.max(0, Math.min(region.y, screenHeight - 1));
    const clampedWidth = Math.max(0, Math.min(region.width, screenWidth - clampedX));
    const clampedHeight = Math.max(0, Math.min(region.height, screenHeight - clampedY));

    return {
        x: clampedX,
        y: clampedY,
        width: clampedWidth,
        height: clampedHeight
    };
}

// Sort monitors by custom order from config.
// Monitors in customOrder appear first in that order.
// Monitors not in customOrder appear after, in their original order.
// Returns a new sorted array; does not modify input.
function sortMonitorsByOrder(monitors, customOrder) {
    if (!customOrder || customOrder.length === 0) {
        return monitors;
    }

    return [...monitors].sort((a, b) => {
        const aIdx = customOrder.indexOf(a.name);
        const bIdx = customOrder.indexOf(b.name);

        // Both not in custom order - preserve original order
        if (aIdx === -1 && bIdx === -1) return 0;
        // Only a not in custom order - a goes after b
        if (aIdx === -1) return 1;
        // Only b not in custom order - b goes after a
        if (bIdx === -1) return -1;
        // Both in custom order - sort by index
        return aIdx - bIdx;
    });
}

// Build a monitor info object from Quickshell screen and Hyprland monitor data.
// Used to create the monitor list for the capture buttons.
function buildMonitorInfo(screen, hyprlandMonitor) {
    return {
        name: hyprlandMonitor.name,
        x: hyprlandMonitor.x,
        y: hyprlandMonitor.y,
        width: screen.width,
        height: screen.height,
        scale: hyprlandMonitor.scale
    };
}
