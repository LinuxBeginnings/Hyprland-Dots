import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var target: parent
    property real radius: 0
    property real blur: 0
    property vector2d offset: Qt.vector2d(0.0, 0.0)
    property real spread: 0
    property color color: "black"
    property bool cached: false

    anchors.fill: target
    visible: target !== null

    MultiEffect {
        anchors.fill: target
        source: target
        shadowEnabled: true
        shadowColor: root.color
        shadowBlur: root.blur
        shadowHorizontalOffset: root.offset.x
        shadowVerticalOffset: root.offset.y
        shadowOpacity: 1.0
    }
}
