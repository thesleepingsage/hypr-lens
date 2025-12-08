pragma Singleton
import QtQuick
import Quickshell

Singleton {
    function trimFileProtocol(path) {
        return path.replace(/^file:\/\//, '')
    }
}
