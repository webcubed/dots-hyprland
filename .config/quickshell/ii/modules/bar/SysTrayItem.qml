import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../services" as Services
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root

    property var bar: root.QsWindow.window
    required property SystemTrayItem item
    property bool targetMenuOpen: false
    hoverEnabled: true

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: 20
    implicitHeight: 20
    onClicked: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) menu.open();
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.content = item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0) tooltip.content += " • " + item.tooltipDescription;
        if (Config.options.bar.tray.showItemId) tooltip.content += "\n[" + item.id + "]";
    }

    QsMenuAnchor {
        id: menu

        menu: root.item.menu
        anchor.window: bar
        anchor.rect.x: root.x + (Config.options.bar.vertical ? 0 : bar?.width)
        anchor.rect.y: root.y + (Config.options.bar.vertical ? bar?.height : 0)
        anchor.rect.height: root.height
        anchor.rect.width: root.width
        anchor.edges: Config.options.bar.bottom ? (Edges.Top | Edges.Left) : (Edges.Bottom | Edges.Right)
    }

    Item {
        id: trayIcon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        visible: !Config.options.bar.tray.monochromeIcons

    // Raw icon string from tray (plain name, image://icon/<name>, spotify-linux-32?path=...)
    property string rawIcon: root.item.icon
    // Extract provider name if image scheme used
    property string schemeName: rawIcon && rawIcon.startsWith('image://icon/') ? rawIcon.substring('image://icon/'.length) : ''
    // Only normalize (strip scheme) for spotify pattern; for others keep full URI so Quickshell can fetch it
    property bool treatAsSpotify: schemeName.length > 0 && schemeName.toLowerCase().startsWith('spotify')
    property string normalizedIcon: treatAsSpotify ? schemeName : rawIcon
    property string initialResolved: Services.IconHelper.resolve(normalizedIcon)
        property bool useFileFallback: initialResolved === '__SPOTIFY_FILE_FALLBACK__'
        property var fileCandidates: useFileFallback ? Services.IconHelper.getSpotifyFileCandidates(root.item.icon) : []
        property int candidateIndex: 0
        property string currentSource: !useFileFallback ? initialResolved : (fileCandidates.length > 0 ? fileCandidates[0] : '')

        function tryNextCandidate() {
            if (!useFileFallback) return;
            candidateIndex++;
            if (candidateIndex < fileCandidates.length) {
                currentSource = fileCandidates[candidateIndex];
                console.log('[SysTrayItem] spotify trying candidate', currentSource);
            } else {
                // Final fallback to themed generic name to surface something (will likely be missing icon)
                currentSource = 'spotify';
                console.log('[SysTrayItem] spotify exhausted file candidates; fallback to themed name "spotify"');
            }
        }

        IconImage {
            id: themedIcon
            anchors.fill: parent
            visible: !trayIcon.useFileFallback
            // If not treating as spotify and original was an image provider, keep original rawIcon
            source: (!trayIcon.treatAsSpotify && trayIcon.rawIcon && trayIcon.rawIcon.startsWith('image://icon/')) ? trayIcon.rawIcon : trayIcon.currentSource
            Component.onCompleted: if (source && typeof source === 'string' && source.toLowerCase().indexOf('spotify') !== -1) console.log('[SysTrayItem] spotify themed source =', source)
        }
        Image {
            id: fileIcon
            anchors.fill: parent
            visible: trayIcon.useFileFallback
            source: trayIcon.currentSource.startsWith('file://') ? trayIcon.currentSource : (trayIcon.currentSource ? 'file://' + trayIcon.currentSource : '')
            fillMode: Image.PreserveAspectFit
            smooth: true
            onStatusChanged: {
                if (status === Image.Error) trayIcon.tryNextCandidate();
                if (status === Image.Ready) console.log('[SysTrayItem] spotify loaded', source)
            }
        }
    }

    Loader {
        active: Config.options.bar.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    StyledToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
    }

}
