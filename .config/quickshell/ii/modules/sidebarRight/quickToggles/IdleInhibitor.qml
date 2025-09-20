import qs.modules.common.widgets
import qs
import qs.services
import QtQuick

QuickToggleButton {
    id: root
    toggled: Idle.inhibit
    buttonIcon: "coffee"
    onClicked: {
        Idle.toggleInhibit()
    }

    StyledToolTip {
        text: Translation.tr("Keep system awake")
    }

    contentItem: Item {
        anchors.centerIn: parent
        width: 20; height: 20
        readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false

        PlumpyIcon {
            id: plumpy
            anchors.centerIn: parent
            visible: parent.usePlumpy
            iconSize: 20
            name: "coffee"
            primaryColor: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !parent.usePlumpy || !plumpy.available
            iconSize: 20
            fill: toggled ? 1 : 0
            color: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: buttonIcon

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

}
