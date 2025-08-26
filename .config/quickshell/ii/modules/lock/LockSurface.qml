import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../bar"

MouseArea {
    id: root

    Item {
        id: dynamicIslandContainer
        // Only show when the setting is explicitly true
        visible: Config.options && Config.options.bar && Config.options.bar.showDynamicIslandOnLockScreen === true
        anchors.top: parent.top
        anchors.topMargin: (Appearance.sizes.hyprlandGapsOut || 12)
        anchors.horizontalCenter: parent.horizontalCenter
        z: 100

        // Horizontal padding around the island
        property int hPadding: 10
        // Size background to island plus padding
        width: dynamicIslandLoader.active && dynamicIslandLoader.item ? (dynamicIslandLoader.item.implicitWidth + hPadding * 2) : 0
        height: dynamicIslandLoader.active && dynamicIslandLoader.item ? dynamicIslandLoader.item.height : 0

        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

        // Explicit pill background to guarantee visibility on lockscreen
        Rectangle {
            id: dynamicIslandBackground
            anchors.fill: parent
            // Use BarGroup's background color to ensure visibility on lockscreen
            color: "#24273a"
            radius: Appearance.rounding.full
        }

        Loader {
            id: dynamicIslandLoader
            anchors.centerIn: parent
            // Only load when explicitly enabled
            active: Config.options && Config.options.bar && Config.options.bar.showDynamicIslandOnLockScreen === true
            sourceComponent: DynamicIsland {}
        }
    }

    required property LockContext context
    property bool active: false
    property bool showInputField: true

    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }

    Component.onCompleted: {
        forceFieldFocus();
    }

    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus();
        }
    }

    Keys.onPressed: event => { // Esc to clear
        if (event.key === Qt.Key_Escape) {
            root.context.currentText = "";
        }
        forceFieldFocus();
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: mouse => {
        forceFieldFocus();
    }
    onPositionChanged: mouse => {
        forceFieldFocus();
    }

    anchors.fill: parent

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

    // Controls
    Toolbar {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 20
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        scale: 0.9
        opacity: 0
        Component.onCompleted: {
            scale = 1
            opacity = 1
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        ToolbarButton {
            id: sleepButton
            implicitWidth: height

            onClicked: Session.suspend()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: "dark_mode"
                color: Appearance.colors.colOnPrimaryContainer
            }
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
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }
        }

        ToolbarButton {
            id: confirmButton
            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress && root.context.currentText.length > 0
            colBackgroundToggled: Appearance.colors.colPrimary

            onClicked: root.context.tryUnlock()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: "arrow_right_alt"
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
        }
    }
}
