pragma Singleton
import Quickshell

Singleton {
    id: root

    function intersectionOverUnion(regionA, regionB) {
        // region: { at: [x, y], size: [w, h] }
        const ax1 = regionA.at[0], ay1 = regionA.at[1];
        const ax2 = ax1 + regionA.size[0], ay2 = ay1 + regionA.size[1];
        const bx1 = regionB.at[0], by1 = regionB.at[1];
        const bx2 = bx1 + regionB.size[0], by2 = by1 + regionB.size[1];

        const interX1 = Math.max(ax1, bx1);
        const interY1 = Math.max(ay1, by1);
        const interX2 = Math.min(ax2, bx2);
        const interY2 = Math.min(ay2, by2);

        const interArea = Math.max(0, interX2 - interX1) * Math.max(0, interY2 - interY1);
        const areaA = (ax2 - ax1) * (ay2 - ay1);
        const areaB = (bx2 - bx1) * (by2 - by1);
        const unionArea = areaA + areaB - interArea;

        return unionArea > 0 ? interArea / unionArea : 0;
    }

    function filterOverlappingImageRegions(regions) {
        let keep = [];
        let removed = new Set();
        for (let i = 0; i < regions.length; ++i) {
            if (removed.has(i)) continue;
            let regionA = regions[i];
            for (let j = i + 1; j < regions.length; ++j) {
                if (removed.has(j)) continue;
                let regionB = regions[j];
                if (intersectionOverUnion(regionA, regionB) > 0) {
                    // Compare areas
                    let areaA = regionA.size[0] * regionA.size[1];
                    let areaB = regionB.size[0] * regionB.size[1];
                    if (areaA <= areaB) {
                        removed.add(j);
                    } else {
                        removed.add(i);
                    }
                }
            }
        }
        for (let i = 0; i < regions.length; ++i) {
            if (!removed.has(i)) keep.push(regions[i]);
        }
        return keep;
    }

    function filterWindowRegionsByLayers(windowRegions, layerRegions) {
        return windowRegions.filter(windowRegion => {
            for (let i = 0; i < layerRegions.length; ++i) {
                if (intersectionOverUnion(windowRegion, layerRegions[i]) > 0)
                    return false;
            }
            return true;
        });
    }

    function filterImageRegions(regions, windowRegions, threshold = 0.1) {
        // Remove image regions that overlap too much with any window region
        let filtered = regions.filter(region => {
            for (let i = 0; i < windowRegions.length; ++i) {
                if (intersectionOverUnion(region, windowRegions[i]) > threshold)
                    return false;
            }
            return true;
        });
        // Remove overlapping image regions, keep only the smaller one
        return filterOverlappingImageRegions(filtered);
    }

    // Hit-test: find region containing point (x, y)
    // Returns the region object or undefined if none found
    function findRegionAtPoint(regions, x, y) {
        return regions.find(region =>
            region.at[0] <= x && x <= region.at[0] + region.size[0] &&
            region.at[1] <= y && y <= region.at[1] + region.size[1]
        );
    }

    // Compute layer regions for a specific monitor
    // Filters out bar/dock layers and adjusts coordinates to monitor-relative
    function computeLayerRegions(layers, monitorName, monitorOffsetX, monitorOffsetY) {
        const layersOfThisMonitor = layers[monitorName];
        if (!layersOfThisMonitor) return [];

        const topLayers = layersOfThisMonitor.levels?.["2"];
        if (!topLayers) return [];

        // Filter out bars/docks and convert to region format
        const nonBarTopLayers = topLayers
            .filter(layer => !(
                layer.namespace.includes(":bar") ||
                layer.namespace.includes(":verticalBar") ||
                layer.namespace.includes(":dock")
            ))
            .map(layer => ({
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }));

        // Adjust coordinates relative to monitor offset
        return nonBarTopLayers.map(layer => ({
            at: [layer.at[0] - monitorOffsetX, layer.at[1] - monitorOffsetY],
            size: layer.size,
            namespace: layer.namespace,
        }));
    }

    // Compute window regions for a specific workspace
    // Sorts floating windows first and adjusts coordinates to monitor-relative
    function computeWindowRegions(windows, activeWorkspaceId, monitorOffsetX, monitorOffsetY, layerRegions) {
        // Sort: floating windows first
        const sortedWindows = [...windows].sort((a, b) => {
            if (a.floating === b.floating) return 0;
            return a.floating ? -1 : 1;
        });

        // Filter by workspace
        const workspaceWindows = sortedWindows.filter(w => w.workspace.id === activeWorkspaceId);

        // Filter out windows overlapping with layers
        const filteredWindows = filterWindowRegionsByLayers(workspaceWindows, layerRegions);

        // Convert to region format with monitor-relative coordinates
        return filteredWindows.map(window => ({
            at: [window.at[0] - monitorOffsetX, window.at[1] - monitorOffsetY],
            size: [window.size[0], window.size[1]],
            class: window.class,
            title: window.title,
        }));
    }
}
