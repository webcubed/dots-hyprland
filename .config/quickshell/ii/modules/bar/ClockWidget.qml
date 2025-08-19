import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose

    implicitHeight: Appearance.sizes.barHeight
    clip: false
    // Reserve fixed space for time and date using TextMetrics, similar to Resource.qml
    // Root-level metrics so we can also compute implicitWidth correctly
    TextMetrics {
        id: fullTimeTextMetrics
        text: "00:00:00"
        font.pixelSize: Appearance.font.pixelSize.small
    }
    TextMetrics {
        id: sepTextMetrics
        text: " \u2022 " // " • "
        font.pixelSize: Appearance.font.pixelSize.small
    }
    TextMetrics {
        id: fullDateTextMetrics
        text: "Wed, 28/08"
        font.pixelSize: Appearance.font.pixelSize.small
    }

    // Announce the true implicit width so backgrounds/layouts size correctly
    implicitWidth: fullTimeTextMetrics.width + (root.showDate ? (sepTextMetrics.width + fullDateTextMetrics.width) : 0) + (rowLayout.spacing * (root.showDate ? 2 : 0))
    // Hint to layouts to use the computed implicit width
    Layout.preferredWidth: implicitWidth

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 4

        // Spacer to push content to the center
        // Item { Layout.fillWidth: true }

        // Fixed-width container for time
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullTimeTextMetrics.width
            implicitHeight: timeText.implicitHeight

            StyledText {
                id: timeText
                anchors.centerIn: parent
                font.pixelSize: Appearance.font.pixelSize.small
                color: "#cad3f5"
                text: DateTime.timeWithSeconds
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: " • "
        }

        // Fixed-width container for date
        Item {
            visible: root.showDate
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullDateTextMetrics.width
            implicitHeight: dateText.implicitHeight

            StyledText {
                id: dateText
                anchors.centerIn: parent
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: "#cad3f5"
                text: DateTime.date
                elide: Text.ElideRight
            }
        }

        // Spacer to push content to the center
        Item { Layout.fillWidth: true }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton



        ClockWidgetTooltip {
            hoverTarget: mouseArea
        }
    }
}
