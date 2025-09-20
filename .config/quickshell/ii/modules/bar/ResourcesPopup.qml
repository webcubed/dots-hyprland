import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    component ResourceItem: RowLayout {
        id: resourceItem
        required property string icon
        required property string label
        required property string value
        spacing: 4
        Layout.fillWidth: true

        Item {
            implicitWidth: Appearance.font.pixelSize.large
            implicitHeight: Appearance.font.pixelSize.large
            readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
            function plumpyFromSymbol(name) {
                switch(name) {
                case 'bolt': return 'bolt';
                case 'device_thermostat': return 'thermometer';
                case 'air': return 'wind';
                case 'check_circle': return 'check';
                case 'clock_loader_60': return 'piechart';
                default: return '';
                }
            }
            PlumpyIcon { id: resItemPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.implicitWidth; name: plumpyFromSymbol(resourceItem.icon); primaryColor: Appearance.colors.colOnSurfaceVariant }
            MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !resItemPlumpy.available || resItemPlumpy.name === ''; text: resourceItem.icon; color: Appearance.colors.colOnSurfaceVariant; iconSize: parent.implicitWidth }
        }
        StyledText {
            text: resourceItem.label
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: resourceItem.value !== ""
            color: Appearance.colors.colOnSurfaceVariant
            text: resourceItem.value
        }
    }

    component ResourceHeaderItem: RowLayout {
        id: headerItem
        required property var icon
        required property var label
        spacing: 5

        Item { implicitWidth: Appearance.font.pixelSize.large; implicitHeight: Appearance.font.pixelSize.large; readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false; function plumpyFromSymbol(name) { switch(name) { case 'memory': return 'cpu'; case 'memory_alt': return 'memory-slot'; default: return ''; } } PlumpyIcon { id: resHdrPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.implicitWidth; name: plumpyFromSymbol(headerItem.icon); primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !resHdrPlumpy.available || resHdrPlumpy.name === ''; fill: 0; font.weight: Font.Medium; text: headerItem.icon; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } }

        StyledText {
            text: headerItem.label
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 12

        // CPU first
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 8

            ResourceHeaderItem {
                icon: "memory"
                label: "CPU"
            }
            ColumnLayout {
                ResourceItem {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: (ResourceUsage.cpuUsage > 0.8 ? Translation.tr("High") : ResourceUsage.cpuUsage > 0.4 ? Translation.tr("Medium") : Translation.tr("Low")) + ` (${Math.round(ResourceUsage.cpuUsage * 100)}%)`
                }
                ResourceItem {
                    icon: "device_thermostat"
                    label: Translation.tr("Temp:")
                    value: (isFinite(ResourceUsage.cpuTempC) ? `${ResourceUsage.cpuTempC} °C` : "")
                }
                ResourceItem {
                    icon: "air"
                    label: Translation.tr("Fan:")
                    value: (isFinite(ResourceUsage.cpuFanRpm) ? `${Math.round(ResourceUsage.cpuFanRpm)} RPM` : "")
                }
            }
        }

        // Network throughput section (hidden per request)
        ColumnLayout {
            visible: false
            Layout.alignment: Qt.AlignTop
            spacing: 8

            ResourceHeaderItem {
                icon: "swap_horiz"
                label: Translation.tr("Network")
            }
            ColumnLayout {
                ResourceItem {
                    icon: "arrow_upward"
                    label: Translation.tr("Up:")
                    value: (NetUsage.upBps >= 1e6
                        ? `${(NetUsage.upBps/1e6).toFixed(2)} MB/s`
                        : (NetUsage.upBps >= 1e3
                            ? `${(NetUsage.upBps/1e3).toFixed(1)} KB/s`
                            : `${Math.round(NetUsage.upBps)} B/s`))
                }
                ResourceItem {
                    icon: "arrow_downward"
                    label: Translation.tr("Down:")
                    value: (NetUsage.downBps >= 1e6
                        ? `${(NetUsage.downBps/1e6).toFixed(2)} MB/s`
                        : (NetUsage.downBps >= 1e3
                            ? `${(NetUsage.downBps/1e3).toFixed(1)} KB/s`
                            : `${Math.round(NetUsage.downBps)} B/s`))
                }
            }
        }

        // RAM last
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 8

            ResourceHeaderItem {
                icon: "memory_alt"
                label: "RAM"
            }
            ColumnLayout {
                ResourceItem {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: formatKB(ResourceUsage.memoryUsed)
                }
                ResourceItem {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: formatKB(ResourceUsage.memoryFree)
                }
                ResourceItem {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: formatKB(ResourceUsage.memoryTotal)
                }
            }
        }
    }
}
