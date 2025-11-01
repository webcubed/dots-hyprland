import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// Scroll hint
Revealer {
    id: root

    property string icon
    property string side: "left"
    property string tooltipText: ""

    // Helper hoisted to root scope
    function plumpyFromIcon(name) {
        switch (name) {
        case 'light_mode':
            return 'sun';
        case 'volume_up':
            return '';
        default:
            return '';
        }
    }

    MouseArea {
        id: mouseArea
        anchors.right: root.side === "left" ? parent.right : undefined
        anchors.left: root.side === "right" ? parent.left : undefined
        implicitWidth: contentColumn.implicitWidth
        implicitHeight: contentColumn.implicitHeight
        property bool hovered: false

        hoverEnabled: true
        onEntered: hovered = true
        onExited: hovered = false
        acceptedButtons: Qt.NoButton

        property bool showHintTimedOut: false
        onHoveredChanged: showHintTimedOut = false
        Timer {
            running: mouseArea.hovered
            interval: 500
            onTriggered: mouseArea.showHintTimedOut = true
        }

        PopupToolTip {
            extraVisibleCondition: (tooltipText.length > 0 && mouseArea.showHintTimedOut)
            text: tooltipText
        }

        Column {
            id: contentColumn

            anchors {
                fill: parent
            }
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
