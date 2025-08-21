import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: true

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        Resource {
            iconName: "memory" // CPU icon
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || 
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
        }

        // Network throughput (replaces swap, keeps swap icon)
        Resource {
            iconName: "swap_horiz"
            // Use NetUsage normalized load (0..1)
            percentage: NetUsage.load
            shown: false
            Layout.leftMargin: 0
        }

        Resource {
            iconName: "memory_alt" // Memory icon
            percentage: ResourceUsage.memoryUsedPercentage
            shown: true
            Layout.leftMargin: shown ? 6 : 0
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
