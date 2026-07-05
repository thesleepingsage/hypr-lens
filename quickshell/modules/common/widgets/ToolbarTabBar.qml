pragma ComponentBehavior: Bound
import ".."
import "../models"
import "../../../services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    // Gate user input without `enabled: false` — disabling the bar stalls the
    // active-indicator animation until re-enable (the oval visually sticks on the
    // old tab). Callers dim via opacity and set interactive: false instead.
    property bool interactive: true

    function incrementCurrentIndex() {
        tabBar.incrementCurrentIndex()
    }
    function decrementCurrentIndex() {
        tabBar.decrementCurrentIndex()
    }
    function setCurrentIndex(index) {
        tabBar.setCurrentIndex(index)
    }

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: contentItem.implicitWidth
    implicitHeight: 40

    Row {
        id: contentItem
        z: 1
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.tabButtonList
            delegate: ToolbarTabButton {
                required property int index
                required property var modelData
                current: index == root.currentIndex
                text: modelData.name
                materialSymbol: modelData.icon
                onClicked: {
                    if (root.interactive) root.setCurrentIndex(index)
                }
            }
        }
    }


    Rectangle {
        id: activeIndicator
        z: 0
        color: Appearance.colors.colSecondaryContainer
        implicitWidth: contentItem.children[root.currentIndex]?.implicitWidth ?? 0
        implicitHeight: contentItem.children[root.currentIndex]?.implicitHeight ?? 0
        radius: height / 2
        // Animation. Bind the edge targets straight to the children/currentIndex
        // expression — an intermediate `property Item targetItem` hop silently failed
        // to re-fire the pair's index binding on programmatic index changes, leaving
        // the indicator stranded on the old tab.
        readonly property real targetX: contentItem.children[root.currentIndex]?.x ?? 0
        readonly property real targetRight: (contentItem.children[root.currentIndex]?.x ?? 0)
                                            + (contentItem.children[root.currentIndex]?.width ?? 0)
        AnimatedTabIndexPair {
            id: leftBound
            idx1Duration: 50
            idx2Duration: 200
            index: activeIndicator.targetX
        }
        AnimatedTabIndexPair {
            id: rightBound
            idx1Duration: 50
            idx2Duration: 200
            index: activeIndicator.targetRight
        }
        x: Math.min(leftBound.idx1, leftBound.idx2)
        width: Math.max(rightBound.idx1, rightBound.idx2) - x
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: (event) => {
            if (!root.interactive) return;
            if (event.angleDelta.y < 0) {
                root.incrementCurrentIndex();
            }
            else {
                root.decrementCurrentIndex();
            }
        }
    }

    // TabBar doesn't allow tabs to be of different sizes. Literally unusable. 
    // We use it only for the logic and draw stuff manually
    TabBar {
        id: tabBar
        z: -1
        background: null
        Repeater { // This is to fool the TabBar that it has tabs so it does the indices properly
            model: root.tabButtonList.length
            delegate: TabButton {
                background: null
            }
        }
    }
}
