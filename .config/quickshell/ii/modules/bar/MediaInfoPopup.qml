import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: root

    // Utility formatters
    function updateTimes() {
        const pair = root.normalizePair(MprisController.activePlayer?.length || 0,
                                        MprisController.activePlayer?.position || 0)
        root.lengthMs = pair.lenMs
        root.positionMs = pair.posMs
    }

    function normalizePair(lenRaw, posRaw) {
        // Robustly convert to milliseconds based on magnitude
        const tenHoursMs = 10 * 60 * 60 * 1000
        let len = Number(lenRaw) || 0
        let pos = Number(posRaw) || 0
        if (len <= 0 && pos <= 0) return { lenMs: 0, posMs: 0 }
        // If values look like microseconds (very large), convert to ms
        if (len > tenHoursMs || pos > tenHoursMs) {
            return { lenMs: Math.floor(len / 1000), posMs: Math.floor(pos / 1000) }
        }
        // If both look like seconds (small integers under 1000), treat as seconds
        if (len > 0 && len < 1000 && pos >= 0 && pos < 1000) {
            return { lenMs: Math.floor(len * 1000), posMs: Math.floor(pos * 1000) }
        }
        // Otherwise assume milliseconds already
        return { lenMs: Math.floor(len), posMs: Math.floor(pos) }
    }

    function formatTime(ms) {
        if (!isFinite(ms) || ms < 0) return "0:00"
        var total = Math.floor(ms / 1000)
        var m = Math.floor(total / 60)
        var s = total % 60
        return m + ":" + (s < 10 ? ("0" + s) : s)
    }

    function pct(pos, len) {
        if (!isFinite(pos) || !isFinite(len) || len <= 0) return "0%"
        return Math.round((pos/len) * 100) + "%"
    }

    // Derived values from MPRIS
    readonly property string title: MprisController.activePlayer?.trackTitle || ""
    readonly property string artist: MprisController.activePlayer?.trackArtist || ""
    readonly property string album: MprisController.activePlayer?.trackAlbum || ""
    readonly property url artUrl: MprisController.activePlayer?.artUrl || MprisController.activePlayer?.trackArtUrl || ""
    // Normalize to milliseconds for display and progress
    property int lengthMs: 0
    property int positionMs: 0

    // Keep progress responsive even if bindings are lazy
    // Host Timer in a hidden visual Item to avoid assigning non-visuals directly to StyledPopup
    Item {
        id: timerHost
        visible: false
        Timer {
            interval: 500
            running: !!MprisController.activePlayer && (MprisController.activePlayer?.isPlaying || false)
            repeat: true
            onTriggered: {
                root.updateTimes()
            }
        }
    }

    //padding: 10

    RowLayout {
        anchors.centerIn: parent
        spacing: 10

        // Album art at left
        Rectangle {
            visible: !!root.artUrl
            // Match the info column height with a safe fallback so it doesn't collapse
            height: Math.max(48, infoCol.implicitHeight || 0)
            width: height
            radius: 6
            color: "transparent"
            border.color: "transparent"
            clip: true
            Image {
                anchors.fill: parent
                source: root.artUrl
                visible: !!root.artUrl
                fillMode: Image.PreserveAspectFit
                smooth: true
                Component.onCompleted: root.updateTimes()
            }
            Connections {
                target: MprisController
                function onActivePlayerChanged() {
                    root.updateTimes()
                    // Refresh BPM/Key for new track
                    console.log("MediaInfoPopup: onActivePlayerChanged -> fetch")
                    BpmKey.fetch(root.artist, root.title, root.album)
                }
                function onTrackChanged() {
                    // Track changed within the same player
                    root.updateTimes()
                    console.log("MediaInfoPopup: onTrackChanged -> fetch")
                    BpmKey.fetch(root.artist, root.title, root.album)
                }
            }
            // Initial fetch for BPM/Key once content is ready
            Component.onCompleted: {
                console.log("MediaInfoPopup: Component.onCompleted -> fetch")
                BpmKey.fetch(root.artist, root.title, root.album)
            }
        }

        // Info on the right
        ColumnLayout {
            id: infoCol
            spacing: 8
            RowLayout {
                spacing: 6
                Item {
                    implicitWidth: Appearance.font.pixelSize.large
                    implicitHeight: Appearance.font.pixelSize.large
                    PlumpyIcon {
                        id: mediaNotePlumpy
                        anchors.centerIn: parent
                        visible: true
                        iconSize: parent.implicitWidth
                        name: 'icons8-music-note'
                        primaryColor: Appearance.colors.colOnSurfaceVariant
                    }
                    MaterialSymbol { anchors.centerIn: parent; visible: mediaNotePlumpy.name === ''; text: "music_note"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant }
                }
                StyledText {
                    text: title || Translation.tr("Unknown Title")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            // Two-column details: left (Artist/Album), right (BPM/Key)
            RowLayout {
                spacing: 16
                // Left column
                ColumnLayout {
                    spacing: 4
                    RowLayout {
                        spacing: 6
                        Item { implicitWidth: Appearance.font.pixelSize.normal; implicitHeight: Appearance.font.pixelSize.normal; PlumpyIcon { id: mediaArtistPlumpy; anchors.centerIn: parent; visible: true; iconSize: parent.implicitWidth; name: 'user'; primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: mediaArtistPlumpy.name === ''; text: "person"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } }
                        StyledText { text: artist || Translation.tr("Unknown Artist"); color: Appearance.colors.colOnSurfaceVariant }
                    }
                    RowLayout { spacing: 6; Item { implicitWidth: Appearance.font.pixelSize.normal; implicitHeight: Appearance.font.pixelSize.normal; PlumpyIcon { id: mediaAlbumPlumpy; anchors.centerIn: parent; visible: true; iconSize: parent.implicitWidth; name: 'album'; primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: mediaAlbumPlumpy.name === ''; text: "album"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } } StyledText { text: album || Translation.tr("Unknown Album"); color: Appearance.colors.colOnSurfaceVariant } }
                }
                // Right column
                ColumnLayout {
                    spacing: 4
                    RowLayout { spacing: 6; Item { implicitWidth: Appearance.font.pixelSize.normal; implicitHeight: Appearance.font.pixelSize.normal; PlumpyIcon { id: mediaSpeedPlumpy; anchors.centerIn: parent; visible: true; iconSize: parent.implicitWidth; name: 'speed-science'; primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: mediaSpeedPlumpy.name === ''; text: "speed"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } } StyledText { text: (BpmKey.bpm > 0 ? (BpmKey.bpm + " BPM") : "—"); color: Appearance.colors.colOnSurfaceVariant } }
                    RowLayout { spacing: 6; Item { implicitWidth: Appearance.font.pixelSize.normal; implicitHeight: Appearance.font.pixelSize.normal; PlumpyIcon { id: mediaTunePlumpy; anchors.centerIn: parent; visible: true; iconSize: parent.implicitWidth; name: 'tune'; primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: mediaTunePlumpy.name === ''; text: "tune"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } } StyledText { id: keyLabel; text: (BpmKey.key && BpmKey.key.length > 0 ? BpmKey.key : "—"); color: Appearance.colors.colOnSurfaceVariant } }
                    Connections {
                        target: BpmKey
                        function onBpmChanged() { console.log("MediaInfoPopup: UI sees bpm ->", BpmKey.bpm) }
                        function onKeyChanged() { console.log("MediaInfoPopup: UI sees key ->", BpmKey.key, " label=", keyLabel.text) }
                        function onLoadingChanged() { console.log("MediaInfoPopup: UI sees loading ->", BpmKey.loading) }
                        function onErrorChanged() { if (BpmKey.error && BpmKey.error.length) console.error("MediaInfoPopup: UI sees error ->", BpmKey.error) }
                    }
                }
            }
            RowLayout { spacing: 6; Item { implicitWidth: Appearance.font.pixelSize.normal; implicitHeight: Appearance.font.pixelSize.normal; PlumpyIcon { id: mediaSchedulePlumpy; anchors.centerIn: parent; visible: true; iconSize: parent.implicitWidth; name: 'clock'; primaryColor: Appearance.colors.colOnSurfaceVariant } MaterialSymbol { anchors.centerIn: parent; visible: mediaSchedulePlumpy.name === ''; text: "schedule"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnSurfaceVariant } } StyledText { text: `${formatTime(positionMs)} / ${formatTime(lengthMs)}`; color: Appearance.colors.colOnSurfaceVariant } Item { Layout.fillWidth: true } StyledText { text: pct(positionMs, lengthMs); color: Appearance.colors.colOnSurfaceVariant } }
            // Simple progress bar
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Appearance.colors.colLayer1
                Rectangle {
                    width: parent.width * (lengthMs > 0 ? Math.max(0, Math.min(1, positionMs / lengthMs)) : 0)
                    height: parent.height
                    radius: parent.radius
                    color: Appearance.colors.colPrimary
                }
            }
        }
    }
}
