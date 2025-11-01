import qs.modules.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

    // Background shadow
    Loader {
        active: Config.options.bar.showBackground && Config.options.bar.cornerStyle === 1 && Config.options.bar.floatStyleShadow
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: Config.options.bar.showBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    // Detect drags in the top-middle region to highlight Dynamic Island
    // Middle 40% horizontally, full bar height (top region of screen)
    DropArea {
        id: islandHighlightDropArea
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: undefined
        anchors.right: undefined
        x: Math.round((parent.width - width) / 2)
        width: Math.round(parent.width * 0.4)
        height: parent.height
        z: 50
        onEntered: { GlobalStates.islandDropHighlight = true }
        onExited: { GlobalStates.islandDropHighlight = false }
        onDropped: (event) => {
            try {
                // Store here as a fallback in case this DropArea captures the event
                ClipboardService.storeFromDrop(event)
                GlobalStates.islandDropHighlight = false
                event.acceptProposedAction()
            } catch (e) {
                console.log("BarContent highlight drop error:", e)
            }
        }
    }


    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: middleSection.left
        }
        implicitWidth: leftSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        onScrollUp: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        // Visual content
        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: "light_mode"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: leftSectionRowLayout
            anchors.fill: parent
            spacing: 0

            LeftSidebarButton { // Left sidebar button
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Appearance.rounding.screenRounding
                colBackground: barLeftSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }
			// Workspace
			BarGroup {
            id: workspacegroup
            padding: workspacesWidget.widgetPadding
            Layout.fillHeight: true
			Layout.leftMargin: 28
			

            Workspaces {
                id: workspacesWidget
                Layout.fillHeight: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                        }
                    }
                }
            }
			}
        }
    }



    RowLayout { // Middle section
        id: middleSection
        anchors.centerIn: parent
        spacing: Config.options?.bar.borderless ? 4 : 8

        BarGroup {
            id: leftCenterGroup2
            // Size to content: use BarGroup's implicitWidth (row contents + padding)
            Layout.fillWidth: false
            Layout.fillHeight: true

            Resources {
                id: resources
                alwaysShowAllResources: root.useShortenedForm === 2
                // Only consume needed width; do not stretch
                Layout.fillWidth: false
            }
			    

            
        }
		BarGroup {
            /* Media {
                visible: root.useShortenedForm < 2
                Layout.fillWidth: true
            } */
			Loader {
            id: dynamicIslandLoader
            // anchors.centerIn: parent
            // Do not show on lock screen (lock surface is transparent)
            active: !GlobalStates.screenLocked
            sourceComponent: DynamicIsland {}
            // Keep GlobalStates.dynamicIslandCenterX in sync with the loader's center in screen coords
            function updateIslandCenter() {
                try {
                    const di = dynamicIslandLoader.item;
                    if (!di) return;
                    const pos = root.QsWindow?.mapFromItem(di, di.width / 2, 0);
                    if (pos && typeof pos.x === 'number') {
                        const winX = root.QsWindow?.window?.x ?? 0;
                        GlobalStates.dynamicIslandCenterX = winX + pos.x;
                    }
                } catch (e) { /* ignore */ }
            }
            onActiveChanged: updateIslandCenter()
            onItemChanged: updateIslandCenter()
            onWidthChanged: updateIslandCenter()
            onXChanged: updateIslandCenter()
            Component.onCompleted: updateIslandCenter()
            Connections {
                target: dynamicIslandLoader.item
                function onWidthChanged() { dynamicIslandLoader.updateIslandCenter() }
                function onXChanged() { dynamicIslandLoader.updateIslandCenter() }
                function onYChanged() { dynamicIslandLoader.updateIslandCenter() }
            }
        }}


        MouseArea {
            id: rightCenterGroup
            // Constrain to clock content + BarGroup edge paddings
            implicitWidth: clock.implicitWidth + (rightCenterGroupContent.padding * 2)
            implicitHeight: rightCenterGroupContent.implicitHeight
            onPressed: {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }

            BarGroup {
                id: rightCenterGroupContent
                //anchors.fill: parent
                padding: 10
                ClockWidget {
                    id: clock
                    showDate: (Config.options.bar.verbose && root.useShortenedForm < 2)
                    // Center the clock via Layout to avoid off-center padding in BarGroup
                    Layout.alignment: Qt.AlignHCenter
                    // Let the widget size to its implicitWidth computed via TextMetrics
                    Layout.fillWidth: false
                }


                UtilButtons {
                    visible: (Config.options.bar.verbose && root.useShortenedForm === 0)
                    Layout.alignment: Qt.AlignVCenter
                }

                

                // Prevent the network indicator from contributing width inside this BarGroup
                Loader {
                    active: false
                    visible: false
                    width: 0
                    height: 0
                    sourceComponent: NetworkIndicator {}
                }
            }
            
        }
        BarGroup {
            Layout.leftMargin: 12
            visible: Config.options.bar.weather.enable
            WeatherBar {}
        }
        
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: middleSection.right
            right: parent.right
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: {
            const currentVolume = Audio.value;
            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
            Audio.sink.audio.volume -= step;
        }
        onScrollUp: {
            const currentVolume = Audio.value;
            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
            Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
        }
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        // Visual content
        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            spacing: 5
            layoutDirection: Qt.RightToLeft

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.rightMargin: Appearance.rounding.screenRounding
                Layout.fillWidth: false

                // Add extra width to account for the bolt indicator
                implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2 + 20
                implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

                buttonRadius: Appearance.rounding.howthingsshouldbe
                colBackground: barRightSideMouseArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: "#24273a"
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: true
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                RowLayout {
                    id: indicatorsRowLayout
                    anchors.centerIn: parent
                    property real realSpacing: 15
                    spacing: 0

                    

                    Revealer {
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Item {
                            width: Appearance.font.pixelSize.larger; height: width
                            readonly property bool usePlumpy: true
                            PlumpyIcon {
                                id: barVolMutePlumpy
                                anchors.centerIn: parent
                                visible: parent.usePlumpy
                                iconSize: parent.width
                                name: "speaker-mute"
                                primaryColor: rightSidebarButton.colText
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !parent.usePlumpy || !barVolMutePlumpy.available
                                text: "volume_off"
                                iconSize: parent.width
                                color: rightSidebarButton.colText
                            }
                        }
                    }
                    Revealer {
                        reveal: Audio.source?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Item {
                            width: Appearance.font.pixelSize.larger; height: width
                            readonly property bool usePlumpy: true
                            PlumpyIcon {
                                id: barMicMutePlumpy
                                anchors.centerIn: parent
                                visible: parent.usePlumpy
                                iconSize: parent.width
                                name: "mic-mute"
                                primaryColor: rightSidebarButton.colText
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !parent.usePlumpy || !barMicMutePlumpy.available
                                text: "mic_off"
                                iconSize: parent.width
                                color: rightSidebarButton.colText
                            }
                        }
                    }
                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                    }
                    Revealer {
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        width: Appearance.font.pixelSize.larger; height: width
                        readonly property bool usePlumpy: true
                        PlumpyIcon {
                            id: barWifiPlumpy
                            anchors.centerIn: parent
                            visible: parent.usePlumpy
                            iconSize: parent.width
                            name: {
                                if (Network.ethernet) return "lan"; // optional if provided later
                                if (!Network.wifiEnabled) return "wifi-off";
                                const s = Network.networkStrength;
                                return s > 80 ? "wifi-4" : s > 60 ? "wifi-3" : s > 40 ? "wifi-2" : s > 20 ? "wifi-1" : "wifi-0";
                            }
                            primaryColor: rightSidebarButton.colText
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: !parent.usePlumpy || !barWifiPlumpy.available
                            text: Network.materialSymbol
                            iconSize: parent.width
                            color: rightSidebarButton.colText
                        }
                    }
                    MaterialSymbol {
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }

            SysTray {
                visible: root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config?.options.bar.bottom
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

        }
    }
}
