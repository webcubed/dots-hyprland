import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    enabled: !(Network.wifiConnectTarget === root.wifiNetwork && !wifiNetwork?.active)

    active: (wifiNetwork?.askingPassword || wifiNetwork?.active) ?? false
    onClicked: {
        Network.connectToWifiNetwork(wifiNetwork);
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            // Name / Strength indicator
            spacing: 10
            Item {
                id: wifiStrengthIcon
                implicitWidth: Appearance.font.pixelSize.larger
                implicitHeight: Appearance.font.pixelSize.larger
                readonly property int strength: root.wifiNetwork?.strength ?? 0
                // Map signal strength to plumpy icon names (expected svg names: wifi-0..wifi-4)
                // Fallback MaterialSymbols kept for when plumpy svg assets are missing.
                readonly property string plumpyName: strength > 80 ? "wifi-4" : strength > 60 ? "wifi-3" : strength > 40 ? "wifi-2" : strength > 20 ? "wifi-1" : "wifi-0"
                readonly property string materialName: strength > 80 ? "signal_wifi_4_bar" : strength > 60 ? "network_wifi_3_bar" : strength > 40 ? "network_wifi_2_bar" : strength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"

                PlumpyIcon {
                    id: plumpySignal
                    anchors.centerIn: parent
                    iconSize: parent.implicitWidth
                    name: wifiStrengthIcon.plumpyName
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }
                MaterialSymbol { // Fallback if plumpy asset missing
                    anchors.centerIn: parent
                    visible: !plumpySignal.available
                    iconSize: parent.implicitWidth
                    text: wifiStrengthIcon.materialName
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
                text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
            }
            Item {
                visible: (root.wifiNetwork?.isSecure || root.wifiNetwork?.active) ?? false
                implicitWidth: Appearance.font.pixelSize.larger
                implicitHeight: Appearance.font.pixelSize.larger
                readonly property bool usePlumpy: true
                PlumpyIcon {
                    id: wifiRowPlumpy
                    anchors.centerIn: parent
                    visible: parent.usePlumpy && (root.wifiNetwork?.active || root.wifiNetwork?.isSecure)
                    iconSize: parent.implicitWidth
                    name: root.wifiNetwork?.active ? 'check' : 'lock'
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !wifiRowPlumpy.available
                    text: root.wifiNetwork?.active ? 'check' : Network.wifiConnectTarget === root.wifiNetwork ? 'settings_ethernet' : 'lock'
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        ColumnLayout { // Password
            id: passwordPrompt
            Layout.topMargin: 8
            visible: root.wifiNetwork?.askingPassword ?? false

            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password")

                // Password
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onAccepted: {
                    Network.changePassword(root.wifiNetwork, passwordField.text);
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: {
                        root.wifiNetwork.askingPassword = false;
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Connect")
                    onClicked: {
                        Network.changePassword(root.wifiNetwork, passwordField.text);
                    }
                }
            }
        }

        ColumnLayout { // Public wifi login page
            id: publicWifiPortal
            Layout.topMargin: 8
            visible: (root.wifiNetwork?.active && (root.wifiNetwork?.security ?? "").trim().length === 0) ?? false

            RowLayout {
                DialogButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Open network portal")
                    colBackground: Appearance.colors.colLayer4
                    colBackgroundHover: Appearance.colors.colLayer4Hover
                    colRipple: Appearance.colors.colLayer4Active
                    onClicked: {
                        Network.openPublicWifiPortal()
                        GlobalStates.sidebarRightOpen = false
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
