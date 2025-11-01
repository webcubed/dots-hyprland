import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common

/*
 PlumpyIcon
 - Loads an SVG from assets/icons8/plumpy
 - Expects 24x24 viewBox; scales to iconSize
 - Optional primary/secondary tint using ColorOverlay twice (requires SVG with two distinct tones or groups)
 - If file not found, 'available' becomes false
*/
Item {
    id: root

    property string name: "" // filename without extension, e.g., "wifi-3"
    property int iconSize: 20
    property color primaryColor: Appearance.colors.colOnLayer1
    property color secondaryColor: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.45)
    // When true, paint a flat monochrome glyph using the icon alpha as mask
    property bool monochrome: true
    // IconImage exposes 'status' like Image; use it to detect availability
    readonly property bool available: svgImage.status === Image.Ready
    // Debug toggle (opt-in per instance)
    property bool debug: false

    // Build a robust file URL for the SVG so loading works regardless of path format
    function buildSource() {
        const base = Quickshell.shellPath("assets/icons8/plumpy");
        const p = `${base}/${root.name}.svg`;
        if (p.startsWith("file:"))
            return p;

        if (p.startsWith("/"))
            return `file://${p}`;

        return Qt.resolvedUrl(p);
    }

    width: iconSize
    height: iconSize

    // Source icon (kept visible for reliable load status); hidden visually via opacity
    IconImage {
        id: svgImage

        anchors.fill: parent
        source: (root.name && root.name.length > 0) ? root.buildSource() : ""
        opacity: root.monochrome ? 0 : 1
        onStatusChanged: {
            if (root.debug)
                console.log(`[PlumpyIcon] name=`, root.name, ' source=', source, ' status=', status, ' ready=', (status === Image.Ready));

        }
    }

    // Monochrome silhouette mode (default): paint a solid rectangle, mask with SVG alpha
    Rectangle {
        anchors.fill: parent
        visible: root.monochrome
        color: root.primaryColor
        layer.enabled: true

        layer.effect: OpacityMask {
            maskSource: svgImage
        }

    }

    // Single-tone overlay mode (when monochrome=false): tint entire icon to primaryColor
    ColorOverlay {
        anchors.fill: svgImage
        visible: !root.monochrome
        source: svgImage
        color: root.primaryColor
    }

}
