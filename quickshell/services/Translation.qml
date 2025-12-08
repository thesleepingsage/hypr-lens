pragma Singleton
import QtQuick
import Quickshell

// Translation service for hypr-lens
//
// Currently a pass-through stub - returns input text unchanged.
// This is intentional for the minimal extraction from dots-hyprland.
//
// To implement full i18n:
// 1. Create a translations/ folder with JSON files per locale
// 2. Load translations based on system locale (Qt.locale().name)
// 3. Replace tr() implementation with lookup logic
//
// Example future implementation:
//   property var translations: ({})
//   function tr(text) { return translations[text] ?? text; }
Singleton {
    id: root

    function tr(text) {
        return text ? text.toString() : "";
    }
}
