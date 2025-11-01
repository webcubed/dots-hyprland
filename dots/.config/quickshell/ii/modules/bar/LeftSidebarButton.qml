import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

RippleButton {
    id: root

    property bool showPing: false
    property real buttonPadding: 5

    implicitWidth: distroIcon.width + buttonPadding * 2
    implicitHeight: distroIcon.height + buttonPadding * 2
    buttonRadius: Appearance.rounding.howthingsshouldbe
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: "#24273a"
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: true
    onPressed: {
        GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
    }

    Connections {
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen)
                return ;

            root.showPing = true;
        }

        target: Ai
    }

    Connections {
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen)
                return ;

            root.showPing = true;
        }

        target: Booru
    }

    Connections {
        function onSidebarLeftOpenChanged() {
            root.showPing = false;
        }

        target: GlobalStates
    }

    CustomIcon {
        id: distroIcon

        anchors.centerIn: parent
        width: 19.5
        height: 19.5
        source: `arch-symbolic.svg`
        colorize: true
        color: Appearance.colors.colOnLayer0

        StyledText {
            id: btw

            text: "btw"
            color: Appearance.colors.colOnLayer0
            font.pixelSize: Appearance.font.pixelSize.smaller
            // Right of the icon
            anchors.left: distroIcon.right
            anchors.leftMargin: 10
            anchors.bottom: distroIcon.bottom
        }

        Rectangle {
            opacity: root.showPing ? 1 : 0
            visible: opacity > 0
            implicitWidth: 8
            implicitHeight: 8
            radius: Appearance.rounding.howthingsshouldbe
            color: Appearance.colors.colTertiary

            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: -2
                rightMargin: -2
            }

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

        }

    }

}
