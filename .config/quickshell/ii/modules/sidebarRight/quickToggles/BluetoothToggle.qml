import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/modules/common"
import "root:/modules/common/functions/string_utils.js" as StringUtils
import "root:/modules/common/widgets"
import "root:/services"

QuickToggleButton {
    toggled: Bluetooth.bluetoothEnabled
    buttonIcon: Bluetooth.bluetoothConnected ? "bluetooth_connected" : Bluetooth.bluetoothEnabled ? "bluetooth" : "bluetooth_disabled"
    onClicked: {
        toggleBluetooth.running = true;
    }
    altAction: () => {
        Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`])
        GlobalStates.sidebarRightOpen = false
    }

    Process {
        id: toggleBluetooth

        command: ["bash", "-c", `bluetoothctl power ${Bluetooth.bluetoothEnabled ? "off" : "on"}`]
        onRunningChanged: {
            if (!running)
                Bluetooth.update();

        }
    }
    StyledToolTip {
        content: Translation.tr("%1 | Right-click to configure").arg(
            (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothDeviceName.length > 0) ? 
            Bluetooth.bluetoothDeviceName : Translation.tr("Bluetooth"))

    StyledToolTip {
        content: StringUtils.format(qsTr("{0} | Right-click to configure"), (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothDeviceName.length > 0) ? Bluetooth.bluetoothDeviceName : qsTr("Bluetooth"))
    }

}
