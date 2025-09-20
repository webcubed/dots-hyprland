import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    required property string iconName
    required property double percentage
    property int warningThreshold: 100
    property bool warning: percentage * 100 >= warningThreshold

    implicitHeight: resourceProgress.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    ClippedFilledCircularProgress {
        id: resourceProgress

        // Prefer Plumpy icons when available; fallback to Material symbols
        function plumpyFromMaterial(name) {
            // CPU icon in this context or memory based on placement

            switch (name) {
            case 'memory':
            case 'planner_review':
                return 'cpu';
            case 'memory_alt':
                return 'memory-slot';
            default:
                return '';
            }
        }

        anchors.centerIn: parent
        value: percentage
        enableAnimation: false
        colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
        accountForLightBleeding: !root.warning

        PlumpyIcon {
            id: vResPlumpy

            anchors.centerIn: parent
            visible: name !== ''
            iconSize: 13
            name: plumpyFromMaterial(root.iconName)
            primaryColor: Appearance.colors.colOnSecondaryContainer
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !vResPlumpy.visible || !vResPlumpy.available
            font.weight: Font.Medium
            fill: 1
            text: root.iconName
            iconSize: 13
            color: Appearance.colors.colOnSecondaryContainer
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: root.visible
    }

}
