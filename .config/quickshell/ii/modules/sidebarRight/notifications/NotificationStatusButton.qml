import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

GroupButton {
    id: button

    property string buttonText: ""
    property string buttonIcon: ""
    property color colText: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1

    baseWidth: content.implicitWidth + 10 * 2
    baseHeight: 30
    buttonRadius: baseHeight / 2
    buttonRadiusPressed: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colBackgroundActive: Appearance.colors.colLayer2Active

    contentItem: Item {
        id: content

        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight

        RowLayout {
            id: contentRowLayout

            anchors.centerIn: parent
            spacing: 5

            // Icon container to allow Plumpy with fallback
            Item {
                implicitWidth: Appearance.font.pixelSize.large
                implicitHeight: Appearance.font.pixelSize.large

                PlumpyIcon {
                    id: notifStatusPlumpy

                    anchors.centerIn: parent
                    iconSize: parent.implicitWidth
                    name: (buttonIcon === 'notifications_paused' ? 'no-bell' : buttonIcon === 'clear_all' ? 'trash' : '')
                    primaryColor: button.colText
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: notifStatusPlumpy.name === '' || !notifStatusPlumpy.available
                    text: buttonIcon
                    iconSize: parent.implicitWidth
                    color: button.colText
                }

            }

            StyledText {
                text: buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                color: button.colText
            }

        }

    }

}
