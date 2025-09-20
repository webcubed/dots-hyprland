import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root

    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: 100
    default property alias data: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding // Add some padding at the bottom
    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight + root.bottomContentPadding

    ColumnLayout {
        id: contentColumn

        width: root.forceWidth ? root.baseWidth : Math.max(root.baseWidth, implicitWidth)
        spacing: 30

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            margins: 20
        }

    }

}
