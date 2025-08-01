import "root:/"
import "root:/services/"
import "root:/modules/overview"
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/modules/session"
import "root:/modules/common/functions/color_utils.js" as ColorUtils
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor.id)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: Math.min(workspaceImplicitHeight, workspaceImplicitWidth) * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: Appearance.rounding.screenRounding * root.scale + padding
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant
    SessionActionButton {
        id: bottomBar
        height: 40 * root.scale
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 5

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight

                SessionActionButton {
                    MaterialSymbol {
                        text: "power_settings_new"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Quickshell.execDetached(["bash", "-c", `systemctl poweroff || loginctl poweroff`]); }
                }
                SessionActionButton {
                    MaterialSymbol {
                        text: "restart_alt"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Quickshell.execDetached(["bash", "-c", `reboot || loginctl reboot`]); }
                }
                SessionActionButton {
                    MaterialSymbol {
                        text: "downloading"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Quickshell.execDetached(["bash", "-c", `systemctl hibernate || loginctl hibernate`]); }
                }
                SessionActionButton {
                    MaterialSymbol {
                        text: "dark_mode"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Quickshell.execDetached(["bash", "-c", `systemctl suspend || loginctl suspend`]); }
                }
                SessionActionButton {
                    MaterialSymbol {
                        text: "lock"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Hyprland.dispatch("exec loginctl lock-session"); }
                }
                SessionActionButton {
                    MaterialSymbol {
                        text: "logout"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    onPressed: { Hyprland.dispatch("exit"); }
                }
            }
        }
    }
    }
}
