import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

MouseArea {
    // RippleButton {
    //     anchors {
    //         top: parent.top
    //         left: parent.left
    //         leftMargin: 10
    //         topMargin: 10
    //     }
    //     implicitHeight: 40
    //     colBackground: Appearance.colors.colLayer2
    //     onClicked: context.unlocked()
    //     contentItem: StyledText {
    //         text: "[[ DEBUG BYPASS ]]"
    //     }
    // }

    id: root

    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    // Toolbar appearing animation
    property real toolbarScale: 0.9
    property real toolbarOpacity: 0

    // Force focus on entry
    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: (mouse) => {
        forceFieldFocus();
    }
    onPositionChanged: (mouse) => {
        forceFieldFocus();
    }
    // Init
    Component.onCompleted: {
        forceFieldFocus();
        toolbarScale = 1;
        toolbarOpacity = 1;
    }
    // Key presses
    Keys.onPressed: (event) => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Escape)
            // Esc to clear
            root.context.currentText = "";

        forceFieldFocus();
    }

    Connections {
        function onShouldReFocus() {
            forceFieldFocus();
        }

        target: context
    }

    // Main toolbar: password box
    Toolbar {
        id: mainIsland

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 20
        }

        ToolbarTextField {
            id: passwordBox

            placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")
            // Style
            clip: true
            font.pixelSize: Appearance.font.pixelSize.small
            // Password
            enabled: !root.context.unlockInProgress
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData
            // Synchronizing (across monitors) and unlocking
            onTextChanged: root.context.currentText = this.text
            onAccepted: root.context.tryUnlock()
            Keys.onPressed: (event) => {
                root.context.resetClearTimer();
            }

            Connections {
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }

                target: root.context
            }

        }

        ToolbarButton {
            id: confirmButton

            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress
            colBackgroundToggled: Appearance.colors.colPrimary
            onClicked: root.context.tryUnlock()

            contentItem: Item {
                readonly property bool usePlumpy: true

                anchors.centerIn: parent
                implicitWidth: 24
                implicitHeight: 24

                PlumpyIcon {
                    id: lockConfirmPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'check'
                    primaryColor: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !lockConfirmPlumpy.available
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    iconSize: parent.implicitWidth
                    text: 'arrow_right_alt'
                    color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                }

            }

        }

        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

    }

    // Left toolbar
    Toolbar {
        id: leftIsland

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        anchors {
            right: mainIsland.left
            top: mainIsland.top
            bottom: mainIsland.bottom
            rightMargin: 10
        }

        // Username
        RowLayout {
            spacing: 6
            Layout.leftMargin: 8
            Layout.fillHeight: true

            Item {
                readonly property bool usePlumpy: true

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Appearance.font.pixelSize.huge
                implicitHeight: Appearance.font.pixelSize.huge

                PlumpyIcon {
                    id: lockUserPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'person'
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !lockUserPlumpy.available
                    fill: 1
                    text: 'account_circle'
                    iconSize: parent.implicitWidth
                    color: Appearance.colors.colOnSurfaceVariant
                }

            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: SystemInfo.username
                color: Appearance.colors.colOnSurfaceVariant
            }

        }

        // Keyboard layout (Xkb)
        Loader {
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.fillHeight: true
            active: true
            visible: active

            sourceComponent: RowLayout {
                spacing: 8

                Item {
                    readonly property bool usePlumpy: true

                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Appearance.font.pixelSize.huge
                    implicitHeight: Appearance.font.pixelSize.huge

                    PlumpyIcon {
                        id: lockKbPlumpy

                        anchors.centerIn: parent
                        visible: parent.usePlumpy
                        iconSize: parent.implicitWidth
                        name: 'keyboard'
                        primaryColor: Appearance.colors.colOnSurfaceVariant
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !parent.usePlumpy || !lockKbPlumpy.available
                        fill: 1
                        text: 'keyboard_alt'
                        iconSize: parent.implicitWidth
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                }

                Loader {

                    sourceComponent: StyledText {
                        text: HyprlandXkb.currentLayoutCode
                        color: Appearance.colors.colOnSurfaceVariant
                        animateChange: true
                    }

                }

            }

        }

        // Keyboard layout (Fcitx)
        Bar.SysTray {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            showSeparator: false
            showOverflowMenu: false
            pinnedItems: SystemTray.items.values.filter((i) => {
                return i.id == "Fcitx";
            })
            visible: pinnedItems.length > 0
        }

    }

    // Right toolbar
    Toolbar {
        id: rightIsland

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        anchors {
            left: mainIsland.right
            top: mainIsland.top
            bottom: mainIsland.bottom
            leftMargin: 10
        }

        RowLayout {
            visible: UPower.displayDevice.isLaptopBattery
            spacing: 6
            Layout.fillHeight: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10

            Item {
                readonly property bool usePlumpy: true

                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -2
                Layout.rightMargin: -2
                implicitWidth: Appearance.font.pixelSize.huge
                implicitHeight: Appearance.font.pixelSize.huge

                PlumpyIcon {
                    id: lockBatteryPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy && Battery.isCharging
                    iconSize: parent.implicitWidth
                    name: 'power'
                    primaryColor: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !lockBatteryPlumpy.available || !Battery.isCharging
                    fill: 1
                    text: Battery.isCharging ? 'bolt' : 'battery_android_full'
                    iconSize: parent.implicitWidth
                    animateChange: true
                    color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
                }

            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Math.round(Battery.percentage * 100)
                color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
            }

        }

        ToolbarButton {
            id: sleepButton

            implicitWidth: height
            onClicked: Session.suspend()

            contentItem: Item {
                readonly property bool usePlumpy: true

                anchors.centerIn: parent
                implicitWidth: 24
                implicitHeight: 24

                PlumpyIcon {
                    id: sleepPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'moon'
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !sleepPlumpy.available
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    iconSize: parent.implicitWidth
                    text: 'dark_mode'
                    color: Appearance.colors.colOnSurfaceVariant
                }

            }

        }

        ToolbarButton {
            id: powerButton

            implicitWidth: height
            onClicked: Session.poweroff()

            contentItem: Item {
                readonly property bool usePlumpy: true

                anchors.centerIn: parent
                implicitWidth: 24
                implicitHeight: 24

                PlumpyIcon {
                    id: powerPlumpy

                    anchors.centerIn: parent
                    visible: parent.usePlumpy
                    iconSize: parent.implicitWidth
                    name: 'power'
                    primaryColor: Appearance.colors.colOnSurfaceVariant
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !parent.usePlumpy || !powerPlumpy.available
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    iconSize: parent.implicitWidth
                    text: 'power_settings_new'
                    color: Appearance.colors.colOnSurfaceVariant
                }

            }

        }

    }

    Behavior on toolbarScale {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }

    }

    Behavior on toolbarOpacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

}
