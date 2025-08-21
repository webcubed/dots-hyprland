import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    // Compact mode: used inside tight layouts (e.g., right sidebar button)
    property bool compact: false
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    // In compact mode, keep indicator compact but clearly visible
    implicitWidth: compact ? 40 : batteryProgress.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    clip: true

    hoverEnabled: true

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        // In compact mode, make the visual bar thicker and wider for visibility
        implicitWidth: root.compact ? 40 : implicitWidth
        implicitHeight: root.compact ? 12 : implicitHeight
        value: percentage
        highlightColor: (isLow && !isCharging)
                         ? Appearance.m3colors.m3error
                         : (root.compact ? Appearance.colors.colPrimary : Appearance.colors.colOnSecondaryContainer)
        // Do not paint CPB in compact; we draw an external overlay but keep CPB for sizing
        opacity: root.compact ? 0 : 1
        // No layout margins needed when anchored
        // Layout.leftMargin: 0
        // Layout.rightMargin: 0

        Item {
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

            // No custom fill here; handled by external overlay in compact mode

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

                MaterialSymbol {
                    id: boltIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Appearance.font.pixelSize.smaller
                    visible: !root.compact && isCharging && percentage < 1 // TODO: animation
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
        // Center overlay on CPB to match its position precisely
        anchors.centerIn: batteryProgress
        visible: root.compact
        z: 10
        // Drive size from CPB implicit size in compact mode
        width: batteryProgress.implicitWidth
        height: batteryProgress.implicitHeight

        // Background track
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Appearance.colors.colOnLayer1
            opacity: 0.35
        }

        // Fill proportional to battery percentage
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: Math.max(2, Math.round(root.percentage * parent.width))
            height: parent.height
            radius: height / 2
            color: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colPrimary
        }

        // Outline for contrast on light backgrounds
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1.25
            border.color: Appearance.colors.colOnLayer1
        }
    }

    // Compact-mode percentage label overlay
    StyledText {
        visible: root.compact
        anchors.centerIn: batteryProgress
        z: 11
        font.pixelSize: Appearance.font.pixelSize.small
        text: batteryProgress.text
        color: Appearance.colors.colOnSecondaryContainer
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
