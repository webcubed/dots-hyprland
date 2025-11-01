import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight.quickToggles
import qs
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

QuickToggleButton {
    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    onClicked: Network.toggleWifi()
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
        GlobalStates.sidebarRightOpen = false;
    }

    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(Network.networkName)
    }

    // Override content with PlumpyIcon when enabled; else use default MaterialSymbol
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
            name: {
                if (Network.ethernet)
                    return "lan";

                if (!Network.wifiEnabled)
                    return "wifi-off";

                const s = Network.networkStrength;
                return s > 80 ? "wifi-4" : s > 60 ? "wifi-3" : s > 40 ? "wifi-2" : s > 20 ? "wifi-1" : "wifi-0";
            }
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
