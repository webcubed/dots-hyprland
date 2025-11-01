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
        // CPU icon in this context or memory based on placement

        id: resourceProgress

        // Prefer Plumpy icons when available; fallback to Material symbols
        function plumpyFromMaterial(name) {
            // Normalize CPU vs Memory to explicit Plumpy assets
            const key = (name || '').trim();
            switch (key) {
            case 'planner_review':
                return 'cpu';
            case 'swap_horiz':
                return 'speed-circle';
            case 'memory':
            case 'memory_alt':
                return 'memory-slot';
            default:
                return '';
            }
        }

        function resolvedPlumpyName() {
            const mapped = (plumpyFromMaterial(root.iconName) || '').trim();
            if (mapped.length > 0)
                return mapped;

            const raw = (root.iconName || '').toLowerCase();
            if (raw.includes('memory'))
                return 'memory-slot';

            if (raw.includes('planner'))
                return 'cpu';

            if (raw.includes('swap'))
                return 'speed-circle';

            return '';
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
            name: resourceProgress.resolvedPlumpyName()
            monochrome: false
            primaryColor: Appearance.colors.colOnSecondaryContainer
            Component.onCompleted: {
                console.log(`[Resource-Vert] iconName=`, root.iconName, ' -> plumpy=', name);
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            // Fallback to Material only if no Plumpy name or icon unavailable
            visible: vResPlumpy.name === '' || !vResPlumpy.available
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
