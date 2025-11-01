import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "icons/AsusBoltPath.js" as AsusBolt
import qs.modules.common
import qs.modules.common.widgets
import qs.services

MouseArea {
    // (duplicate compact bolt removed; defined within `compactOverlay` above)
    // (removed) duplicate compact bolt implementation

    id: root

    // Compact mode: used inside tight layouts (e.g., right sidebar button)
    property bool compact: false
    // Catppuccin Macchiato colors
    // Blue (neutral): #8AADF4, Green (charging): #A6DA95, Red (low): #ED8796, Text: #CAD3F5
    property color accentColor: "#8AADF4"
    // neutral
    property color chargingColor: "#A6DA95"
    property color lowColor: "#ED8796"
    property color textColor: "#CAD3F5"
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    // In compact mode, keep indicator compact but clearly visible
    // Use a short pill to avoid stretching the parent Row/Button vertically
    implicitWidth: compact ? 28 : batteryProgress.implicitWidth
    implicitHeight: compact ? 18 : Appearance.sizes.barHeight
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    clip: true
    hoverEnabled: true

    ClippedProgressBar {
        // No layout margins needed when anchored
        // Layout.leftMargin: 0
        // Layout.rightMargin: 0

        id: batteryProgress

        anchors.centerIn: parent
        // In compact mode, make the visual bar thicker and wider for visibility
        implicitWidth: root.compact ? root.implicitWidth : implicitWidth
        implicitHeight: root.compact ? 14 : implicitHeight
        value: percentage
        highlightColor: (root.isLow && !root.isCharging) ? root.lowColor : (root.compact ? Appearance.colors.colPrimary : Appearance.colors.colOnSecondaryContainer)
        // Do not paint CPB in compact; we draw an external overlay but keep CPB for sizing
        opacity: root.compact ? 0 : 1

        Item {
            // No custom fill here; handled by external overlay in compact mode

            anchors.centerIn: parent
            // Disable this internal overlay in compact mode; we use an external overlay instead
            visible: !root.compact
            z: 0
            // In compact mode, do not depend on CPB internals for sizing; use the root's implicit width
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            // Background track for contrast under the progress fill (non-compact only here)
            Rectangle {
                visible: !root.compact
                anchors.fill: parent
                radius: height / 2
                color: Appearance.colors.colOnLayer1
                opacity: 0.25
            }

            // Outline to avoid the bar looking like a plain white line on light backgrounds (non-compact only here)
            Rectangle {
                visible: !root.compact
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOnLayer1
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 0

                Item {
                    readonly property bool usePlumpy: true

                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    implicitWidth: Appearance.font.pixelSize.smaller
                    implicitHeight: Appearance.font.pixelSize.smaller
                    visible: !root.compact && isCharging && percentage < 1

                    PlumpyIcon {
                        id: batBoltInlinePlumpy

                        anchors.centerIn: parent
                        visible: parent.usePlumpy
                        iconSize: parent.implicitWidth
                        name: 'bolt'
                        primaryColor: Appearance.colors.colOnSecondaryContainer
                    }

                    MaterialSymbol {
                        id: boltIcon

                        anchors.centerIn: parent
                        visible: !parent.usePlumpy || !batBoltInlinePlumpy.available
                        fill: 1
                        text: "bolt"
                        iconSize: parent.implicitWidth
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    font: batteryProgress.font
                    text: batteryProgress.text
                    visible: !root.compact
                }

            }

        }

    }

    // External overlay for compact mode to avoid CPB clipping and ensure visibility
    Item {
        id: compactOverlay

        // Bolt is drawn OUTSIDE the pill, so no internal reserve is needed
        readonly property int boltReserve: 0
        readonly property real progress: Math.max(0, Math.min(1, root.percentage))
        // Pixel-accurate segment width. Entire pill width is available (bolt is outside)
        readonly property int progressPx: Math.round(Math.max(0, width) * progress)
        readonly property int basePx: Math.max(0, width - progressPx)
        readonly property color activeColor: (root.isLow && !root.isCharging) ? root.lowColor : ((root.isCharging || root.isPluggedIn) ? root.chargingColor : root.accentColor)
        // Desaturated/low-opacity variants
        // Darker outline for the unfilled portion so contrast is clear while staying on-palette
        // Use a stronger factor so it is clearly different from the progress outline
        readonly property color baseOutlineColor: (root.isLow && !root.isCharging) ? Qt.darker(root.lowColor, 1.25) : Qt.darker(Appearance.colors.colPrimary, 1.35)
        readonly property color baseFillColor: (root.isLow && !root.isCharging) ? Qt.rgba(237 / 255, 135 / 255, 150 / 255, 0.15) : ((root.isCharging || root.isPluggedIn) ? Qt.rgba(166 / 255, 218 / 255, 149 / 255, 0.15) : Qt.rgba(138 / 255, 173 / 255, 244 / 255, 0.15))

        // Center overlay on CPB to match its position precisely
        anchors.centerIn: batteryProgress
        visible: root.compact
        z: 10
        // Self-size in compact mode: fixed height, width from text + padding
        height: 14
        width: Math.max((textLabel ? textLabel.implicitWidth + 12 : 28), height * 2)

        // Subtle background track to define the pill silhouette
        // No background fill; outline-only look
        Rectangle {
            anchors.fill: parent
            radius: Math.max(0, Math.round(height / 2) - 2)
            color: "transparent"
            opacity: 0
            z: 10
        }

        // BASE OUTLINE via mask: outer fill + inner cutout to leave a crisp 2px outline
        Item {
            anchors.fill: parent
            z: 11

            // Outer body in baseOutlineColor
            Rectangle {
                anchors.fill: parent
                color: compactOverlay.baseOutlineColor
                radius: Math.max(0, Math.round(parent.height / 2) - 2)
            }

            // Inner cutout matches background, leaving ~2px outline
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: "#1E2030"
                radius: Math.max(0, Math.round(parent.height / 2) - 4)
            }

        }

        // PROGRESS OUTLINE via mask: clip width to progress and carve interior
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true
            // Progress clip strictly to computed progress width
            width: Math.max(0, Math.min(parent.progressPx, parent.width))
            visible: width > 0
            z: 12

            // Outer body in activeColor
            Rectangle {
                anchors.fill: parent
                color: compactOverlay.activeColor
                radius: Math.max(0, Math.round(parent.height / 2) - 2)
            }

            // Inner cutout to create outline-only look
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                color: "#1E2030"
                radius: Math.max(0, Math.round(parent.height / 2) - 4)
            }

            // Inner-edge trim: removes tiny green crescent at the left when width is small
            // Drawn over the inner area only (starting at x=2) so the 2px outer outline remains intact
            Rectangle {
                x: 2
                y: 2
                width: 2
                height: Math.max(0, parent.height - 4)
                color: "#1E2030"
                radius: 0
                visible: parent.width > 0 && parent.width < parent.height
            }

            // Right seam eraser: flatten the rounded end so the join is a clean vertical cut
            // Use pill radius to fully cover the curvature; affect only inner area to preserve 2px outer outline
            Rectangle {
                readonly property int r: Math.max(2, Math.round(parent.height / 2) - 2)

                x: Math.max(2, parent.width - r)
                y: 2
                width: Math.max(2, r)
                height: Math.max(0, parent.height - 4)
                color: "#1E2030"
                radius: 0
                visible: parent.width > 0 && parent.width < compactOverlay.width
            }

        }

        // Compact-mode bolt: outside the pill on the right
        Shape {
            id: compactBolt

            visible: root.compact && (root.isCharging || root.isPluggedIn)
            anchors.verticalCenter: compactOverlay.verticalCenter
            anchors.left: compactOverlay.right
            anchors.leftMargin: 4
            width: Math.round(compactOverlay.height * 0.6)
            height: width
            z: 13

            ShapePath {
                fillColor: "#8aadf4"
                strokeWidth: 0
                startX: 0
                startY: 0

                PathSvg {
                    path: AsusBolt.pathData
                }

            }

        }

    }

    // Mask behind compact text to hide outline seam near digits (drawn under the text)
    Rectangle {
        visible: root.compact
        anchors.centerIn: compactOverlay
        // Keep mask below overlay outlines so they remain visible
        z: 9
        // Use a generous rounded pill to fully cover inner borders under text
        radius: Math.round(height / 2)
        // Slightly smaller than text so it doesn't cover top/bottom strokes
        width: Math.max(0, textLabel.implicitWidth - 4)
        height: Math.max(0, textLabel.implicitHeight - 5)
        layer.enabled: true
        layer.samples: 4
        // Match the bar background for seamless cover
        color: "#1E2030"
    }

    // Compact-mode percentage label overlay (crisp text)
    Text {
        id: textLabel

        visible: root.compact
        anchors.centerIn: compactOverlay
        z: 12
        // Explicit size for compact clarity
        font.pixelSize: 8
        font.bold: true
        font.kerning: false
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
        // Improve edge contrast while keeping fill color
        style: Text.Outline
        styleColor: "#141724"
        text: batteryProgress.text
        color: "#8aadf4"
    }

    BatteryPopup {
        id: batteryPopup

        hoverTarget: root
    }

}
