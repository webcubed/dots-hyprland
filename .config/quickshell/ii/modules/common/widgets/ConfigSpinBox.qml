import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property string text: ""
    property string icon
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to

    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    RowLayout {
        spacing: 10

        Item {
            implicitWidth: Appearance.font.pixelSize.larger
            implicitHeight: Appearance.font.pixelSize.larger

            PlumpyIcon {
                id: cfgSpinPlumpy

                anchors.centerIn: parent
                iconSize: parent.implicitWidth
                name: root.icon
                primaryColor: Appearance.colors.colOnSecondaryContainer
            }

            OptionalMaterialSymbol {
                anchors.centerIn: parent
                visible: cfgSpinPlumpy.name === '' || !cfgSpinPlumpy.available
                icon: root.icon
            }

        }

        StyledText {
            id: labelWidget

            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
        }

    }

    StyledSpinBox {
        id: spinBoxWidget

        Layout.fillWidth: false
        value: root.value
    }

}
