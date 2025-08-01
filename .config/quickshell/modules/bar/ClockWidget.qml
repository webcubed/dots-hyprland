import QtQuick
import QtQuick.Layouts
import "root:/modules/common"
import "root:/modules/common/widgets"
import "root:/services"

Item {
    id: root

    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: 32

    RowLayout {
        id: rowLayout

        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: "#cad3f5"
            text: DateTime.timeWithSeconds
            
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: "#cad3f5"
            text: DateTime.date
        }

    }

}
