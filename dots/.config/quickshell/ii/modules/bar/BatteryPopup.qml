import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    
    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 4

        // Header
        Row {
            id: header
            spacing: 5

            Item {
                readonly property bool usePlumpy: true

                implicitWidth: Appearance.font.pixelSize.large
                implicitHeight: Appearance.font.pixelSize.large

                PlumpyIcon {
                    id: batHdrPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'battery'
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Battery"
                    color: Appearance.colors.colOnSurfaceVariant

                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.normal
                    }

                }
            }

            // This row is hidden when the battery is full.
            RowLayout {
                property bool rowVisible: {
                    let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                    let power = Battery.energyRate;
                    return !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
                }

                spacing: 5
                Layout.fillWidth: true
                visible: rowVisible
                opacity: rowVisible ? 1 : 0

                Item {
                    readonly property bool usePlumpy: true

                    implicitWidth: Appearance.font.pixelSize.large
                    implicitHeight: Appearance.font.pixelSize.large

                    PlumpyIcon {
                        id: batSchPlumpy

                        anchors.centerIn: parent
                        visible: parent.usePlumpy
                        iconSize: parent.implicitWidth
                        name: 'clock'
                        primaryColor: Appearance.colors.colOnSurfaceVariant
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !parent.usePlumpy || !batSchPlumpy.available
                        text: "schedule"
                        iconSize: parent.implicitWidth
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

                StyledText {
                    text: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    function formatTime(seconds) {
                        var h = Math.floor(seconds / 3600);
                        var m = Math.floor((seconds % 3600) / 60);
                        if (h > 0)
                            return `${h}h, ${m}m`;
                        else
                            return `${m}m`;
                    }

                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                    text: {
                        if (Battery.isCharging)
                            return formatTime(Battery.timeToFull);
                        else
                            return formatTime(Battery.timeToEmpty);
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                    }

                }

            }

            RowLayout {
                property bool rowVisible: !(Battery.chargeState != 4 && Battery.energyRate == 0)

                spacing: 5
                Layout.fillWidth: true
                visible: rowVisible
                opacity: rowVisible ? 1 : 0

                Item {
                    readonly property bool usePlumpy: true

                    implicitWidth: Appearance.font.pixelSize.large
                    implicitHeight: Appearance.font.pixelSize.large

                    PlumpyIcon {
                        id: batBoltPlumpy

                        anchors.centerIn: parent
                        visible: parent.usePlumpy
                        iconSize: parent.implicitWidth
                        name: 'bolt'
                        primaryColor: Appearance.colors.colOnSurfaceVariant
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !parent.usePlumpy || !batBoltPlumpy.available
                        text: "bolt"
                        iconSize: parent.implicitWidth
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

                StyledText {
                    text: {
                        if (Battery.chargeState == 4)
                            return Translation.tr("Fully charged");
                        else if (Battery.chargeState == 1)
                            return Translation.tr("Charging:");
                        else
                            return Translation.tr("Discharging:");
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                    text: {
                        if (Battery.chargeState == 4)
                            return "";
                        else
                            return `${Battery.energyRate.toFixed(2)}W`;
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                    }

                }

            }

        }
    }
}
