import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    property string buttonIcon

    Layout.fillWidth: true
    implicitHeight: contentItem.implicitHeight + 8 * 2
    font.pixelSize: Appearance.font.pixelSize.small
    onClicked: checked = !checked

    contentItem: RowLayout {
        spacing: 10

        Item {
            implicitWidth: Appearance.font.pixelSize.larger
            implicitHeight: Appearance.font.pixelSize.larger

            PlumpyIcon {
                id: cfgSwitchPlumpy

                anchors.centerIn: parent
                iconSize: parent.implicitWidth
                name: root.buttonIcon
                primaryColor: Appearance.colors.colOnSecondaryContainer
            }

            OptionalMaterialSymbol {
                anchors.centerIn: parent
                visible: cfgSwitchPlumpy.name === '' || !cfgSwitchPlumpy.available
                icon: root.buttonIcon
                iconSize: parent.implicitWidth
            }

        }

        StyledText {
            id: labelWidget

            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: Appearance.colors.colOnSecondaryContainer
        }

        StyledSwitch {
            id: switchWidget

            down: root.down
            scale: 0.6
            Layout.fillWidth: false
            checked: root.checked
            onClicked: root.clicked()
        }

    }

}
