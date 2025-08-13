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

    implicitHeight: 32

    FontMetrics {
        id: fontMetrics
        font.pixelSize: Appearance.font.pixelSize.small
    }

    // Set a fixed, constant width for the entire widget to prevent layout shifts.
    // The width is calculated as the sum of each component's width plus spacing.
    implicitWidth: fontMetrics.advanceWidth("00:00:00") + fontMetrics.advanceWidth(" • ") + fontMetrics.advanceWidth("Wed, 28/08") + (rowLayout.spacing * 2)

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 4

        // Spacer to push content to the center
        Item { Layout.fillWidth: true }

        StyledText {
            id: timeText
            // Set a fixed width for the time to prevent it from shifting the date.
            width: fontMetrics.advanceWidth("00:00:00")
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: DateTime.timeWithSeconds
            // Left-align the text to prevent jitter within its fixed-width container.
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: " • "
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: DateTime.date
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
