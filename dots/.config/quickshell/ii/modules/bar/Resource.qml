import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property string iconName
    required property double percentage
    property int warningThreshold: 100
    property bool shown: true
    property bool warning: percentage * 100 >= warningThreshold

    // Map Material icon names used by Resources to Plumpy asset names
    function plumpyFromMaterial(name) {
        switch (name) {
        case 'memory':
            return 'cpu';
        case 'swap_horiz':
            return 'speed-circle';
        case 'memory_alt':
            return 'memory-slot';
        default:
            return '';
        }
    }

    clip: true
    visible: width > 0 && height > 0
    implicitWidth: resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: resourceRowLayout

        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width

        anchors {
            verticalCenter: parent.verticalCenter
        }

        ClippedFilledCircularProgress {
            id: resourceCircProg

            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: percentage
            implicitSize: 20
            colPrimary: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSecondaryContainer
            accountForLightBleeding: !root.warning
            enableAnimation: false

            Item {
                // Prefer Plumpy icons when available; fallback to Material symbols
                anchors.centerIn: parent
                width: resourceCircProg.implicitSize
                height: resourceCircProg.implicitSize

                PlumpyIcon {
                    id: resPlumpy

                    anchors.centerIn: parent
                    visible: name !== ''
                    iconSize: Appearance.font.pixelSize.normal
                    name: root.plumpyFromMaterial(root.iconName)
                    monochrome: false
                    primaryColor: Appearance.colors.colOnSecondaryContainer
                    debug: true
                }

                // Fallback to Material if no Plumpy name or the asset fails to load
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: resPlumpy.name === '' || !resPlumpy.available
                    font.weight: Font.DemiBold
                    fill: 1
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }

            }

        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullPercentageTextMetrics.width
            implicitHeight: percentageText.implicitHeight

            TextMetrics {
                id: fullPercentageTextMetrics

                text: "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                id: percentageText

                anchors.centerIn: parent
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                text: `${Math.round(percentage * 100).toString()}`
            }

        }

        Behavior on x {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: resourceRowLayout.x >= 0 && root.width > 0 && root.visible
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }

    }

}
