import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property alias text: baseText.text
    // segments: [{ t: ms, d: ms, text: string }]
    property var segments: []
    property int currentMs: 0
    property color baseColor: Appearance.colors.colOnLayer1
    property color highlightColor: Appearance.colors.colPrimary
    property int pixelSize: Appearance.font.pixelSize.small

    // Let containers query our implicit size like a normal Text
    implicitWidth: baseText.implicitWidth
    implicitHeight: baseText.implicitHeight
    width: parent ? parent.width : implicitWidth
    height: Math.max(implicitHeight, 1)

    function _lineStart() {
        if (!segments || segments.length === 0) return 0
        return segments[0].t
    }
    function _lineEnd() {
        if (!segments || segments.length === 0) return 0
        const last = segments[segments.length - 1]
        return (last.t + (last.d || 0))
    }
    function _progressFrac() {
        const s = _lineStart()
        const e = _lineEnd()
        if (e <= s) return 0.0
        const clamped = Math.max(s, Math.min(currentMs, e))
        return (clamped - s) / (e - s)
    }

    // Base dim text
    StyledText {
        id: baseText
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        width: parent ? parent.width : implicitWidth
        font.pixelSize: root.pixelSize
        color: root.baseColor
        elide: Text.ElideNone
        horizontalAlignment: Text.AlignHCenter
        visible: true
    }

    // Highlight overlay clipped by progress width
    Item {
        id: clipper
        anchors.fill: baseText
        clip: true
        width: Math.floor(baseText.width * _progressFrac())
        StyledText {
            anchors.fill: parent
            text: baseText.text
            font.pixelSize: root.pixelSize
            color: root.highlightColor
            elide: Text.ElideNone
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
