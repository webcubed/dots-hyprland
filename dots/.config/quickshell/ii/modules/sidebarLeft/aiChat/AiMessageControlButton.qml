import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    property bool activated: false
    toggled: activated
    baseWidth: height
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    function plumpyNameFor(icon) {
        switch (icon) {
        case 'inventory': return 'clipboard-approve';
        default: return '';
        }
    }

    contentItem: Item {
        implicitWidth: Appearance.font.pixelSize.larger
        implicitHeight: Appearance.font.pixelSize.larger
        readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false

        PlumpyIcon {
            id: controlPlumpy
            anchors.centerIn: parent
            visible: parent.usePlumpy && name !== ''
            iconSize: parent.implicitWidth
            name: button.plumpyNameFor(button.buttonIcon)
            primaryColor: button.activated ? Appearance.m3colors.m3onPrimary :
                button.enabled ? Appearance.m3colors.m3onSurface :
                Appearance.colors.colOnLayer1Inactive
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: !parent.usePlumpy || controlPlumpy.name === ''
            horizontalAlignment: Text.AlignHCenter
            iconSize: parent.implicitWidth
            text: button.buttonIcon
            color: button.activated ? Appearance.m3colors.m3onPrimary :
                button.enabled ? Appearance.m3colors.m3onSurface :
                Appearance.colors.colOnLayer1Inactive

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}
