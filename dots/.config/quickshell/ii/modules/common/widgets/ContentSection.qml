import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property string title
    property string icon: ""
    default property alias data: sectionContent.data

    // Prefer Plumpy icons in settings when available; fallback to Material
    function plumpyFromMaterial(name) {
        switch (name) {
        case 'wallpaper':
            return 'image';
        case 'call_to_action':
            return 'apps';
        case 'lock':
            return 'lock';
        case 'notifications':
            return 'bell';
        case 'side_navigation':
            return 'menu';
        case 'voting_chip':
            return 'shapes';
        case 'overview_key':
            return 'apps';
        case 'screenshot_frame_2':
            return 'image';
        case 'spoke':
            return 'lan';
        case 'workspaces':
            return 'apps';
        case 'widgets':
            return 'shapes';
        case 'shelf_auto_hide':
            return 'pin';
        case 'cloud':
            return 'cloud';
        case 'volume_up':
            return 'volume';
        case 'battery_android_full':
            return 'battery';
        case 'language':
            return 'translation';
        case 'rule':
            return 'check';
        case 'box':
            return 'apps';
        default:
            return '';
        }
    }

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        spacing: 6

        Item {
            implicitWidth: Appearance.font.pixelSize.hugeass
            implicitHeight: Appearance.font.pixelSize.hugeass

            PlumpyIcon {
                id: sectionPlumpy

                anchors.centerIn: parent
                iconSize: parent.implicitWidth
                name: root.plumpyFromMaterial(root.icon)
                primaryColor: Appearance.colors.colOnSecondaryContainer
            }

            OptionalMaterialSymbol {
                anchors.centerIn: parent
                visible: sectionPlumpy.name === '' || !sectionPlumpy.available
                icon: root.icon
                iconSize: parent.implicitWidth
            }

        }

        StyledText {
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.Medium
            color: Appearance.colors.colOnSecondaryContainer
        }

    }

    ColumnLayout {
        id: sectionContent

        Layout.fillWidth: true
        spacing: 4
    }

}
