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
    //     onClicked: {
    //         context.unlocked(LockContext.ActionEnum.Unlock);
    //         GlobalStates.screenLocked = false;
    //     }
    //     contentItem: StyledText {
    //         text: "[[ DEBUG BYPASS ]]"
    //     }
    // }

    id: root

    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
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

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: {
                    if (root.context.targetAction === LockContext.ActionEnum.Unlock)
                        return "arrow_right_alt";
                    else if (root.context.targetAction === LockContext.ActionEnum.Poweroff)
                        return "power_settings_new";
                    else if (root.context.targetAction === LockContext.ActionEnum.Reboot)
                        return "restart_alt";
                }
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
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
        IconAndTextPair {
            Layout.leftMargin: 8
            icon: "account_circle"
            text: SystemInfo.username
        }

        // Keyboard layout (Xkb)
        Loader {
            Layout.rightMargin: 8
            Layout.fillHeight: true
            active: true
            visible: active

            sourceComponent: Row {
                spacing: 8

                MaterialSymbol {
                    id: keyboardIcon

                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: "keyboard_alt"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                }

                Loader {
                    anchors.verticalCenter: parent.verticalCenter

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

        IconAndTextPair {
            visible: UPower.displayDevice.isLaptopBattery
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            text: Math.round(Battery.percentage * 100)
            color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        ActionToolbarIconButton {
            id: sleepButton

            onClicked: Session.suspend()
            text: "dark_mode"
        }

        PasswordGuardedActionToolbarIconButton {
            id: powerButton

            text: "power_settings_new"
            targetAction: LockContext.ActionEnum.Poweroff
        }

        PasswordGuardedActionToolbarIconButton {
            id: rebootButton

            text: "restart_alt"
            targetAction: LockContext.ActionEnum.Reboot
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

    component PasswordGuardedActionToolbarIconButton: ActionToolbarIconButton {
        id: guardedBtn

        required property var targetAction

        toggled: root.context.targetAction === guardedBtn.targetAction
        onClicked: {
            if (!root.requirePasswordToPower) {
                root.context.unlocked(guardedBtn.targetAction);
                return ;
            }
            if (root.context.targetAction === guardedBtn.targetAction) {
                root.context.resetTargetAction();
            } else {
                root.context.targetAction = guardedBtn.targetAction;
                root.context.shouldReFocus();
            }
        }
    }

    component ActionToolbarIconButton: ToolbarButton {
        id: iconBtn

        implicitWidth: height
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        colRippleToggled: Appearance.colors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: 24
            text: iconBtn.text
            color: iconBtn.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
        }

    }

    component IconAndTextPair: Row {
        id: pair

        required property string icon
        required property string text
        property color color: Appearance.colors.colOnSurfaceVariant

        spacing: 4
        Layout.fillHeight: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: pair.icon
            iconSize: Appearance.font.pixelSize.huge
            animateChange: true
            color: pair.color
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pair.text
            color: pair.color
        }

    }

}
