import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

TabButton {
    id: root

    property bool toggled: TabBar.tabBar.currentIndex === TabBar.index
    property string buttonIcon
    property real buttonIconRotation: 0
    property string buttonText
    property bool expanded: false
    property bool showToggledHighlight: true
    readonly property real visualWidth: root.expanded ? root.baseSize + 20 + itemText.implicitWidth : root.baseSize
    property real baseSize: 56
    property real baseHighlightHeight: 32
    property real highlightCollapsedTopMargin: 8

    // Map Material icons to Plumpy in root scope so children can call root.plumpyFromMaterial
    function plumpyFromMaterial(name) {
        switch (name) {
        case 'calendar_month':
            return 'calendar';
        case 'done_outline':
            return 'check';
        case 'schedule':
            return 'clock';
        default:
            return '';
        }
    }

    padding: 0
    // The navigation item’s target area always spans the full width of the
    // nav rail, even if the item container hugs its contents.
    Layout.fillWidth: true
    // implicitWidth: contentItem.implicitWidth
    implicitHeight: baseSize
    background: null

    PointingHandInteraction {
    }

    // Real stuff
    contentItem: Item {
        id: buttonContent

        implicitWidth: root.visualWidth
        implicitHeight: root.expanded ? itemIconBackground.implicitHeight : itemIconBackground.implicitHeight + itemText.implicitHeight

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: undefined
        }

        Rectangle {
            id: itemBackground

            anchors.top: itemIconBackground.top
            anchors.left: itemIconBackground.left
            anchors.bottom: itemIconBackground.bottom
            implicitWidth: root.visualWidth
            radius: Appearance.rounding.full
            color: toggled ? root.showToggledHighlight ? (root.down ? Appearance.colors.colSecondaryContainerActive : root.hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer) : ColorUtils.transparentize(Appearance.colors.colSecondaryContainer) : (root.down ? Appearance.colors.colLayer1Active : root.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1))

            states: State {
                name: "expanded"
                when: root.expanded

                AnchorChanges {
                    target: itemBackground
                    anchors.top: buttonContent.top
                    anchors.left: buttonContent.left
                    anchors.bottom: buttonContent.bottom
                }

                PropertyChanges {
                    target: itemBackground
                    implicitWidth: root.visualWidth
                }

            }

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }

                PropertyAnimation {
                    target: itemBackground
                    property: "implicitWidth"
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }

            }

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

        }

        Item {
            id: itemIconBackground

            readonly property bool usePlumpy: true

            implicitWidth: root.baseSize
            implicitHeight: root.baseHighlightHeight

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            // Prefer Plumpy icons when available; fallback to Material symbols

            PlumpyIcon {
                id: navRailPlumpy

                anchors.centerIn: parent
                visible: itemIconBackground.usePlumpy && name !== ''
                iconSize: 24
                name: root.plumpyFromMaterial(root.buttonIcon)
                primaryColor: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
            }

            MaterialSymbol {
                id: navRailButtonIcon

                rotation: root.buttonIconRotation
                anchors.centerIn: parent
                // Fallback to Material only if we don't have a Plumpy mapping or asset unavailable
                visible: navRailPlumpy.name === '' || !navRailPlumpy.available
                iconSize: 24
                fill: toggled ? 1 : 0
                font.weight: (toggled || root.hovered) ? Font.DemiBold : Font.Normal
                text: buttonIcon
                color: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

            }

        }

        StyledText {
            id: itemText

            text: buttonText
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1

            anchors {
                top: itemIconBackground.bottom
                topMargin: 2
                horizontalCenter: itemIconBackground.horizontalCenter
            }

            states: State {
                name: "expanded"
                when: root.expanded

                AnchorChanges {
                    target: itemText

                    anchors {
                        top: undefined
                        horizontalCenter: undefined
                        left: itemIconBackground.right
                        verticalCenter: itemIconBackground.verticalCenter
                    }

                }

            }

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }

            }

        }

    }

}
