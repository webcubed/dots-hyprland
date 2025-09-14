import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    property bool vertical: false
    property real padding: 5
    default property alias items: gridLayout.children

    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight

    Rectangle {
        id: background

        color: "#24273a"
        radius: Appearance.rounding.howthingsshouldbe

        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        // color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1

    }

    GridLayout {
        id: gridLayout

        columns: root.vertical ? 1 : -1
        columnSpacing: 4
        rowSpacing: 12

        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            left: root.vertical ? undefined : parent.left
            right: root.vertical ? undefined : parent.right
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }

    }

}
