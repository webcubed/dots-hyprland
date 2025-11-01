import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: Config.options.bar.utilButtons.showScreenSnip
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Hyprland.dispatch("global quickshell:regionScreenshot")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showScreenRecord
            visible: Config.options.bar.utilButtons.showScreenRecord
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "videocam"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showColorPicker
            visible: Config.options.bar.utilButtons.showColorPicker
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                Item { anchors.centerIn: parent; width: Appearance.font.pixelSize.large; height: width; readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false; PlumpyIcon { id: colorPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: 'toolbox'; primaryColor: Appearance.colors.colOnLayer2 } MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !colorPlumpy.available; horizontalAlignment: Text.AlignHCenter; fill: 1; text: "colorize"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnLayer2 } }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showKeyboardToggle
            visible: Config.options.bar.utilButtons.showKeyboardToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                Item { anchors.centerIn: parent; width: Appearance.font.pixelSize.large; height: width; readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false; PlumpyIcon { id: kbPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: 'keyboard'; primaryColor: Appearance.colors.colOnLayer2 } MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !kbPlumpy.available; horizontalAlignment: Text.AlignHCenter; fill: 0; text: "keyboard"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnLayer2 } }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showMicToggle
            visible: Config.options.bar.utilButtons.showMicToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                Item { anchors.centerIn: parent; width: Appearance.font.pixelSize.large; height: width; readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false; PlumpyIcon { id: micPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: Pipewire.defaultAudioSource?.audio?.muted ? 'mic-mute' : 'mic'; primaryColor: Appearance.colors.colOnLayer2 } MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !micPlumpy.available; horizontalAlignment: Text.AlignHCenter; fill: 0; text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnLayer2 } }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showDarkModeToggle
            visible: Config.options.bar.utilButtons.showDarkModeToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`);
                    } else {
                        Hyprland.dispatch(`exec ${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`);
                    }
                }
                Item { anchors.centerIn: parent; width: Appearance.font.pixelSize.large; height: width; readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false; PlumpyIcon { id: themePlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: Appearance.m3colors.darkmode ? 'sun' : 'moon'; primaryColor: Appearance.colors.colOnLayer2 } MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !themePlumpy.available; horizontalAlignment: Text.AlignHCenter; fill: 0; text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnLayer2 } }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showPerformanceProfileToggle
            visible: Config.options.bar.utilButtons.showPerformanceProfileToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                Item {
                    anchors.centerIn: parent
                    width: Appearance.font.pixelSize.large; height: width
                    readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
                    function plumpyForProfile(p) {
                        switch(p) {
                        case PowerProfile.PowerSaver: return 'leaf'
                        case PowerProfile.Balanced: return 'settings'
                        case PowerProfile.Performance: return 'bolt'
                        default: return ''
                        }
                    }
                    function materialForProfile(p) {
                        switch(p) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "settings_slow_motion"
                        case PowerProfile.Performance: return "local_fire_department"
                        default: return "settings"
                        }
                    }
                    PlumpyIcon { id: profPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.width; name: plumpyForProfile(PowerProfiles.profile); primaryColor: Appearance.colors.colOnLayer2 }
                    MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !profPlumpy.available || profPlumpy.name === ''; horizontalAlignment: Text.AlignHCenter; fill: 0; text: materialForProfile(PowerProfiles.profile); iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnLayer2 }
                }
            }
        }
    }
}
