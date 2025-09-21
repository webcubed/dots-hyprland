import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text

    // Map common weather metric symbols to Plumpy asset names
    function plumpyFromSymbol(sym) {
        switch (sym) {
        case 'wb_sunny':
            return 'sun';
        case 'air':
            return 'wind';
        case 'rainy_light':
            return 'rain';
        case 'humidity_low':
            return 'thermometer'; // approximate humidity
        case 'visibility':
            return 'visibility';
        case 'readiness_score':
            return 'piechart'; // approximate pressure gauge
        case 'wb_twilight':
            return 'sunrise';
        case 'bedtime':
            return 'moon';
        default:
            return '';
        }
    }

    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh
    implicitWidth: columnLayout.implicitWidth + 14 * 2
    implicitHeight: columnLayout.implicitHeight + 14 * 2
    Layout.fillWidth: parent

    ColumnLayout {
        id: columnLayout

        anchors.fill: parent
        spacing: -10

        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            Item {
                implicitWidth: Appearance.font.pixelSize.normal
                implicitHeight: Appearance.font.pixelSize.normal

                PlumpyIcon {
                    id: cardPlumpy

                    anchors.centerIn: parent
                    visible: name !== ''
                    iconSize: parent.implicitWidth
                    name: root.plumpyFromSymbol(root.symbol)
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    id: symbol

                    anchors.centerIn: parent
                    visible: cardPlumpy.name === ''
                    fill: 0
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colOnSurfaceVariant
                }

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
