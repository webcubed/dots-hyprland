import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh
    implicitWidth: columnLayout.implicitWidth + 14 * 2
    implicitHeight: columnLayout.implicitHeight + 14 * 2
    Layout.fillWidth: parent

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        spacing: -10
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Item {
                implicitWidth: Appearance.font.pixelSize.normal
                implicitHeight: Appearance.font.pixelSize.normal
                readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
                // Map common weather metric symbols to plumpy
                function plumpyFromSymbol(sym) {
                    switch(sym) {
                    case 'wb_sunny': return 'sun';
                    case 'air': return 'wind';
                    case 'rainy_light': return 'rain';
                    case 'humidity_low': return 'thermometer'; // approximate
                    case 'visibility': return 'visibility';
                    case 'wb_twilight': return 'sunrise';
                    case 'bedtime': return 'moon';
                    default: return '';
                    }
                }
                PlumpyIcon { id: cardPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.implicitWidth; name: plumpyFromSymbol(root.symbol); primaryColor: Appearance.colors.colOnSurfaceVariant }
                MaterialSymbol { id: symbol; anchors.centerIn: parent; visible: !parent.usePlumpy || !cardPlumpy.available; fill: 0; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant }
            }
            StyledText {
                id: title
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
        StyledText {
            id: value
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}
