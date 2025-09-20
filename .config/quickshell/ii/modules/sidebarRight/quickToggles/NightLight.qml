import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs
import qs.services
import Quickshell.Io

QuickToggleButton {
    id: nightLightButton
    property bool enabled: Hyprsunset.active
    toggled: enabled
    buttonIcon: Config.options.light.night.automatic ? "night_sight_auto" : "bedtime"
    onClicked: {
        Hyprsunset.toggle()
    }

    altAction: () => {
        Config.options.light.night.automatic = !Config.options.light.night.automatic
    }

    Component.onCompleted: {
        Hyprsunset.fetchState()
    }
    
    StyledToolTip {
        text: Translation.tr("Night Light | Right-click to toggle Auto mode")
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
            // Requested mapping: auto → moon-and-stars (existing 'night-light.svg'); manual → 'moon.svg'
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
