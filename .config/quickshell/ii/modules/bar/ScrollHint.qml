import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// Scroll hint
Revealer {
    id: root

    property string icon
    property string side: "left"
    property string tooltipText: ""

    MouseArea {
        // StyledToolTip {
        //     extraVisibleCondition: tooltipText.length > 0
        //     text: tooltipText
        // }

        property bool hovered: false

        anchors.right: root.side === "left" ? parent.right : undefined
        anchors.left: root.side === "right" ? parent.left : undefined
        implicitWidth: contentColumnLayout.implicitWidth
        implicitHeight: contentColumnLayout.implicitHeight
        hoverEnabled: true
        onEntered: hovered = true
        onExited: hovered = false
        acceptedButtons: Qt.NoButton

        ColumnLayout {
            id: contentColumnLayout

            anchors.centerIn: parent
            spacing: -5

            Item {
                readonly property bool usePlumpy: true

                implicitWidth: 14
                implicitHeight: 14

                PlumpyIcon {
                    id: upPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'chevron-up'
                    primaryColor: Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !upPlumpy.available
                    text: 'keyboard_arrow_up'
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colSubtext
                }

            }

            Item {
                readonly property bool usePlumpy: true

                function plumpyFromIcon(name) {
                    switch (name) {
                    case 'light_mode':
                        return 'sun';
                    case 'volume_up':
                        // Unknowns: return empty to use Material fallback
                        return '';
                    default:
                        return '';
                    }
                }

                implicitWidth: 14
                implicitHeight: 14

                PlumpyIcon {
                    id: midPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy && name !== ''
                    iconSize: parent.implicitWidth
                    name: plumpyFromIcon(root.icon)
                    primaryColor: Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !midPlumpy.available || midPlumpy.name === ''
                    text: root.icon
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colSubtext
                }

            }

            Item {
                readonly property bool usePlumpy: true

                implicitWidth: 14
                implicitHeight: 14

                PlumpyIcon {
                    id: downPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'chevron-down'
                    primaryColor: Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !downPlumpy.available
                    text: 'keyboard_arrow_down'
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colSubtext
                }

            }

        }

    }

}
