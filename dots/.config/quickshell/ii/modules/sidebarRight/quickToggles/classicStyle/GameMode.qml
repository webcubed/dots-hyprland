import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets

QuickToggleButton {
    id: root

    buttonIcon: "gamepad"
    toggled: toggled
    onClicked: {
        root.toggled = !root.toggled;
        if (root.toggled)
            Quickshell.execDetached(["bash", "-c", `hyprctl --batch "keyword animations:enabled 0; keyword decoration:shadow:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0; keyword general:allow_tearing 1"`]);
        else
            Quickshell.execDetached(["hyprctl", "reload"]);
    }

    Process {
        id: fetchActiveState

        running: true
        command: ["bash", "-c", `test "$(hyprctl getoption animations:enabled -j | jq ".int")" -ne 0`]
        onExited: (exitCode, exitStatus) => {
            root.toggled = exitCode !== 0; // Inverted because enabled = nonzero exit
        }
    }

    StyledToolTip {
        text: Translation.tr("Game mode")
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
            name: "gamepad"
            primaryColor: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !parent.usePlumpy || !plumpy.available
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
