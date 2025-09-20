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
            readonly property bool usePlumpy: true
            function plumpyFromWx(name) {
                switch(name) {
                // Clear
                case 'clear_day': return 'sun';
                case 'clear_night': return 'moon';
                // Clouds
                case 'partly_cloudy_day': return 'cloudy'; // sun + cloud
                case 'partly_cloudy_night': return 'cloud'; // no moon+cloud asset yet
                case 'cloudy': return 'cloud';
                case 'overcast': return 'cloud';
                case 'cloud': return 'cloud';
                // Fog / mist / haze / smoke (day/night variants if provided)
                case 'foggy_day': return 'sun-fog';
                case 'foggy_night': return 'night-fog';
                case 'day_fog': return 'sun-fog';
                case 'night_fog': return 'night-fog';
                case 'sun_fog': return 'sun-fog';
                case 'night-fog': return 'night-fog';
                case 'foggy': return 'fog';
                case 'mist': return 'fog';
                case 'haze': return 'fog';
                case 'smoke': return 'fog';
                // Rain / storms
                case 'rainy': return 'rain';
                case 'rainy_light': return 'rain';
                case 'rainy_heavy': return 'rain';
                case 'drizzle': return 'rain';
                case 'weather_hail': return 'rain'; // approximate until hail asset
                case 'thunderstorm': return 'rain';
                case 'lightning': return 'rain';
                // Snow variants: prefer explicit assets if present
                case 'cloudy_snowing': return 'snow-many';
                case 'snowing_heavy': return 'snow-many';
                case 'snowing': return 'flake';
                case 'snow': return 'flake';
                case 'sleet': return 'snow-1flake';
                // Wind
                case 'windy': return 'wind';
                default: return '';
                }
            }
            PlumpyIcon { id: wxPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: parent.implicitWidth; name: (plumpyFromWx(WeatherIcons.codeToName[Weather.data.wCode] ?? "") || 'cloud'); primaryColor: Appearance.colors.colOnLayer1 }
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
