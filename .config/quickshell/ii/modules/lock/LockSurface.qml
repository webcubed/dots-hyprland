import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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

    Keys.onPressed: (event) => { // Esc to clear
        // console.log("KEY!!")
        if (event.key === Qt.Key_Escape) {
            root.context.currentText = ""
        }
        forceFieldFocus();
    }

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: (mouse) => {
        forceFieldFocus();
        // console.log("Pressed")
    }
    onPositionChanged: (mouse) => {
        forceFieldFocus();
        // console.log(JSON.stringify(mouse))
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

    // Password entry
    Rectangle {
        id: passwordBoxContainer
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: root.showInputField ? 20 : -height
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        radius: Appearance.rounding.full
        color: "#24273a"
        implicitWidth: 160
        implicitHeight: 44

        StyledTextInput {
            id: passwordBox

            anchors {
                fill: parent
                margins: 10
            }
            clip: true
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            focus: true
            onFocusChanged: root.forceFieldFocus();
            color: Appearance.colors.colOnLayer2
            font {
                pixelSize: 10
            }

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
    }

    RippleButton {
        anchors {
            verticalCenter: passwordBoxContainer.verticalCenter
            left: passwordBoxContainer.right
            leftMargin: 5
        }

        visible: opacity > 0
        implicitHeight: passwordBoxContainer.implicitHeight - 12
        implicitWidth: implicitHeight
        toggled: true
        buttonRadius: passwordBoxContainer.radius
        colBackground: Appearance.colors.colLayer2
        onClicked: root.context.tryUnlock()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: 24
            text: "arrow_right_alt"
            color: Appearance.colors.colOnPrimary
        }
    }
}
