import qs.modules.common.widgets
import qs.services


QuickToggleButton {
    id: root

    toggled: Idle.inhibit
    buttonIcon: "coffee"
    onClicked: {
        Idle.toggleInhibit();
    }

    StyledToolTip {
        text: Translation.tr("Keep system awake")
    }

    contentItem: Item {
        readonly property bool usePlumpy: true

        anchors.centerIn: parent
        width: 20
        height: 20

        PlumpyIcon {
            id: plumpy

            anchors.centerIn: parent
            visible: parent.usePlumpy
            iconSize: 20
            name: "coffee"
            // Use themed neutral when off, on-primary when toggled
            primaryColor: toggled ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.colOnLayer2
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !parent.usePlumpy || !plumpy.available
            iconSize: 20
            fill: toggled ? 1 : 0
            // Use themed neutral when off, on-primary when toggled
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
