import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Network indicator: compact throughput only (up/down speeds)
BarGroup {
    id: root
    padding: 6
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        spacing: 6
        Layout.alignment: Qt.AlignVCenter

        // Simple up/down throughput only; hide when interface not found
        StyledText {
            visible: NetUsage.interfaceName.length > 0
            text: `${NetUsage.upKbps.toFixed(0)}↑  ${NetUsage.downKbps.toFixed(0)}↓`
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer0
        }
    }
}
