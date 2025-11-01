import QtQuick
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: nightLightButton
    toggled: Hyprsunset.active
    buttonIcon: Config.options.light.night.automatic ? "night_sight_auto" : "bedtime"
    onClicked: {
        Hyprsunset.toggle();
    }
    altAction: () => {
        Config.options.light.night.automatic = !Config.options.light.night.automatic;
    }
    Component.onCompleted: {
        Hyprsunset.fetchState();
    }

    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to toggle Auto mode")
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
            // Mapping: auto → night-light.svg (moon + stars), manual → moon.svg
            name: Config.options.light.night.automatic ? "night-light" : "moon"
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
