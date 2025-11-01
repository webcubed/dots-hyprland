import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    id: root
    visible: EasyEffects.available
    toggled: EasyEffects.active
    buttonIcon: "instant_mix"
    Component.onCompleted: {
        EasyEffects.fetchActiveState();
    }
    onClicked: {
        EasyEffects.toggle();
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", "flatpak run com.github.wwmm.easyeffects || easyeffects"]);
        GlobalStates.sidebarRightOpen = false;
    }

    StyledToolTip {
        text: Translation.tr("EasyEffects | Right-click to configure")
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
            name: "speaker-mute" // placeholder until an EasyEffects-appropriate icon is added
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
