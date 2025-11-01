import QtQuick
import QtQuick.Controls

ProgressBar {
    id: root

    property real barWidth: 120
    property real barHeight: 4

    width: barWidth
    height: barHeight
    value: 0
    from: 0
    to: 1

    background: Rectangle {
        anchors.fill: parent
        color: "#333"
        radius: barHeight / 2
    }

    contentItem: Rectangle {
        width: root.visualPosition * root.width
        height: root.height
        color: "#685496"
        radius: barHeight / 2
    }

}
