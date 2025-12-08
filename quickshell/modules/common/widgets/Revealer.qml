import ".."
import QtQuick

/**
 * Recreation of GTK revealer. Expects one single child.
 */
Item {
    id: root
    property bool reveal
    property bool vertical: false
    clip: true

    // Use first child's implicit size instead of childrenRect to avoid animation feedback loop
    readonly property Item contentItem: contentChildren.length > 0 ? contentChildren[0] : null
    implicitWidth: (reveal || vertical) ? (contentItem?.implicitWidth ?? 0) : 0
    implicitHeight: (reveal || !vertical) ? (contentItem?.implicitHeight ?? 0) : 0
    visible: reveal || (width > 0 && height > 0)

    Behavior on implicitWidth {
        enabled: !vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        enabled: vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
}
