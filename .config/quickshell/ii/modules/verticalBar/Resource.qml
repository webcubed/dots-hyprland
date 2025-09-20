import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    required property string iconName
    required property double percentage
    property int warningThreshold: 100
    implicitHeight: resourceProgress.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    property bool warning: percentage * 100 >= warningThreshold

    ClippedFilledCircularProgress {
        id: resourceProgress
        anchors.centerIn: parent
        value: percentage
        enableAnimation: false
        colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
        accountForLightBleeding: !root.warning

        // Prefer Plumpy icons when available; fallback to Material symbols
        function plumpyFromMaterial(name) {
            switch (name) {
            case 'memory': // CPU icon in this context or memory based on placement
            case 'planner_review':
                return 'cpu';
            case 'memory_alt':
                return 'memory-slot';
            default:
                return '';
            }
        }

        PlumpyIcon {
            id: vResPlumpy
            anchors.centerIn: parent
            visible: (Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false) && name !== ''
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
