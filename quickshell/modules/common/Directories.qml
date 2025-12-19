pragma Singleton
import QtCore
import QtQuick
import Quickshell

// Adapted Directories for hypr-lens
Singleton {
    id: root

    // XDG standard paths - strip file:// prefix inline
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0].toString().replace("file://", "")
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0].toString().replace("file://", "")
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0].toString().replace("file://", "")

    // hypr-lens specific paths
    property string scriptPath: home + "/.local/share/hypr-lens/scripts"
    property string screenshotTemp: "/tmp/hypr-lens/screenshot"
    property string recordScriptPath: scriptPath + "/videos/record.sh"
    property string shellConfig: home + "/.config/hypr-lens"
    property string shellConfigPath: shellConfig + "/config.json"

    // Create directories on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", screenshotTemp])
        Quickshell.execDetached(["mkdir", "-p", shellConfig])
    }
}
