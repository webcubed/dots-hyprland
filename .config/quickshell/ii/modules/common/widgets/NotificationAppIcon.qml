import qs.modules.common
import "./notification_utils.js" as NotificationUtils
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle { // App icon
    id: root
    property var appIcon: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property var image: ""
    property real scale: 1
    property real size: 38 * scale
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    property real smallAppIconScale: 0.49
    property real materialIconSize: size * materialIconScale
    property real appIconSize: size * appIconScale
    property real smallAppIconSize: size * smallAppIconScale

    implicitWidth: size
    implicitHeight: size
    radius: Appearance.rounding.full
    color: Appearance.colors.colSecondaryContainer
    Loader {
        id: materialSymbolLoader
        active: root.appIcon == ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
            function plumpyFromGuess(name) {
                switch(name) {
                case 'calendar_month':
                case 'calendar_today': return 'calendar';
                case 'forum':
                case 'chat': return 'chat';
                case 'terminal': return 'terminal';
                case 'notifications': return 'bell';
                case 'notifications_active': return 'bell-ringing';
                case 'phone_android':
                case 'phone_iphone': return 'phone';
                case 'headphones': return 'headphones';
                case 'image': return 'image';
                case 'mic': return 'mic';
                case 'mic_off': return 'mic-mute';
                default: return '';
                }
            }
            readonly property string guessed: (function(){
                const def = NotificationUtils.findSuitableMaterialSymbol("")
                const g = NotificationUtils.findSuitableMaterialSymbol(root.summary)
                return (root.urgency == NotificationUrgency.Critical && g === def) ? 'release_alert' : g
            })()
            PlumpyIcon { id: notifPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && name !== ''; iconSize: root.materialIconSize; name: plumpyFromGuess(parent.guessed); primaryColor: (root.urgency == NotificationUrgency.Critical) ? ColorUtils.mix(Appearance.m3colors.m3onSecondary, Appearance.m3colors.m3onSecondaryContainer, 0.1) : Appearance.m3colors.m3onSecondaryContainer }
            MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !notifPlumpy.available || notifPlumpy.name === ''; text: parent.guessed; color: (root.urgency == NotificationUrgency.Critical) ? ColorUtils.mix(Appearance.m3colors.m3onSecondary, Appearance.m3colors.m3onSecondaryContainer, 0.1) : Appearance.m3colors.m3onSecondaryContainer; iconSize: root.materialIconSize; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
    Loader {
        id: appIconLoader
        active: root.image == "" && root.appIcon != ""
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: Quickshell.iconPath(root.appIcon, "image-missing")
        }
    }
    Loader {
        id: notifImageLoader
        active: root.image != ""
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            Image {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width

                source: root.image
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true

                width: size
                height: size
                sourceSize.width: size
                sourceSize.height: size

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.size
                        height: notifImage.size
                        radius: Appearance.rounding.full
                    }
                }
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.appIcon != ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: Quickshell.iconPath(root.appIcon, "image-missing")
                }
            }
        }
    }
}