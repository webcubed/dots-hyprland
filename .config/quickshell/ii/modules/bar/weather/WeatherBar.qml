pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool hovered: false
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true

    onClicked: {
        Weather.getData();
        Quickshell.execDetached(["notify-send", 
            Translation.tr("Weather"), 
            Translation.tr("Refreshing (manually triggered)")
            , "-a", "Shell"
        ])
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Appearance.font.pixelSize.large
            implicitHeight: Appearance.font.pixelSize.large
            readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
            function plumpyFromWx(name) {
                switch(name) {
                case 'clear_day': return 'sun';
                case 'partly_cloudy_day': return 'sun'; // no cloud asset yet; sun is closest
                case 'cloud': return 'sun'; // placeholder until cloud asset exists
                case 'foggy': return 'sun'; // placeholder
                case 'rainy': return 'rain';
                case 'weather_hail': return 'rain';
                case 'cloudy_snowing': return 'snow'; // no asset; fallback via Material
                case 'snowing_heavy': return 'snow';
                case 'snowing': return 'snow';
                case 'thunderstorm': return 'rain';
                default: return '';
                }
            }
            PlumpyIcon { id: wxPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.implicitWidth; name: plumpyFromWx(WeatherIcons.codeToName[Weather.data.wCode] ?? ""); primaryColor: Appearance.colors.colOnLayer1 }
            MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !wxPlumpy.available || wxPlumpy.name === ''; fill: 0; text: WeatherIcons.codeToName[Weather.data.wCode] ?? "cloud"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnLayer1 }
        }

        StyledText {
            visible: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}
