import qs.modules.common
import qs.modules.common.widgets
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    // Map common Material buttonIcon names to our Plumpy asset names (hoisted for stable scope)
    function plumpyFromMaterial(name) {
        switch (name) {
        case 'wifi':
        case 'wifi_off':
        case 'network_wifi_3_bar':
        case 'network_wifi_2_bar':
        case 'network_wifi_1_bar':
        case 'signal_wifi_0_bar':
            return ''; // Network toggle comp overrides content and handles Wi‑Fi mapping
        case 'bluetooth':
        case 'bluetooth_connected':
        case 'bluetooth_disabled':
            return 'bluetooth'; // connected/disabled variants handled by specific toggle
        case 'night_sight_auto':
            return 'night-light';
        case 'bedtime':
            return 'moon';
        case 'sports_esports':
        case 'gamepad':
            return 'gamepad';
        case 'coffee':
            return 'coffee';
        case 'tune':
            return 'tune';
        case 'speaker':
        case 'speaker_mute':
            return 'speaker-mute';
        default:
            return '';
        }
    }
    baseWidth: 40
    baseHeight: 40
    clickedWidth: baseWidth + 20
    toggled: false
    buttonRadius: (altAction && toggled) ? Appearance?.rounding.normal : Math.min(baseHeight, baseWidth) / 2
    buttonRadiusPressed: Appearance?.rounding?.small

    // Prefer Plumpy icons; fallback to Material symbol only if no Plumpy mapping/name
    contentItem: Item {
        anchors.centerIn: parent
        iconSize: 22
        fill: toggled ? 1 : 0
        color: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: buttonIcon

        PlumpyIcon {
            id: qtPlumpy
            anchors.centerIn: parent
            visible: name !== ''
            iconSize: 20
            name: button.plumpyFromMaterial(buttonIcon)
            primaryColor: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: qtPlumpy.name === ''
            iconSize: 20
            fill: toggled ? 1 : 0
            color: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: buttonIcon

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

}
