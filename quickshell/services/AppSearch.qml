pragma Singleton
import QtQuick
import Quickshell

// Minimal AppSearch stub for hypr-lens - basic icon guessing
Singleton {
    id: root

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        // Try the string as-is first
        var iconPath = Quickshell.iconPath(str, true);
        if (iconPath.length > 0) return str;

        // Try lowercase
        var lower = str.toLowerCase();
        iconPath = Quickshell.iconPath(lower, true);
        if (iconPath.length > 0) return lower;

        // Try with hyphens instead of spaces
        var kebab = str.toLowerCase().replace(/\s+/g, "-");
        iconPath = Quickshell.iconPath(kebab, true);
        if (iconPath.length > 0) return kebab;

        return "image-missing";
    }
}
