import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TabButton {
    id: root
    property string buttonText
    property string buttonIcon
    property real minimumWidth: 110
    property bool selected: false
    property int tabContentWidth: contentItem.children[0].implicitWidth
    property int rippleDuration: 1200
    // Control whether to prefer Plumpy icons in this context
    property bool usePlumpyIcons: false
    height: buttonBackground.height
    implicitWidth: Math.max(tabContentWidth, buttonBackground.implicitWidth, minimumWidth)

    property color colBackground: ColorUtils.transparentize(Appearance?.colors.colLayer1Hover, 1) || "transparent"
    property color colBackgroundHover: Appearance?.colors.colLayer1Hover ?? "#E5DFED"
    property color colRipple: Appearance?.colors.colLayer1Active ?? "#D6CEE2"
    property color colActive: Appearance?.colors.colPrimary ?? "#65558F"
    property color colInactive: Appearance?.colors.colOnLayer1 ?? "#45464F"

    component RippleAnim: NumberAnimation {
        duration: rippleDuration
        easing.type: Appearance?.animation.elementMoveEnter.type
        easing.bezierCurve: Appearance?.animationCurves.standardDecel
    }

    // Global mapping function: map Material tab icons to Plumpy names
    function plumpyFromTabIcon(name) {
        const n = name || ''
        if (n === 'experiment') return 'chemistry'
        if (n === 'keyboard') return 'keyboard'
        // Right sidebar tabs
        if (n === 'notifications') return 'bell'
        if (n === 'volume_up') return 'volume'
        return ''
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: (event) => {
            button.click() // Because the MouseArea already consumed the event
            const {x,y} = event
            const stateY = buttonBackground.y;
            rippleAnim.x = x;
            rippleAnim.y = y - stateY;

            const dist = (ox,oy) => ox*ox + oy*oy
            const stateEndY = stateY + buttonBackground.height
            rippleAnim.radius = Math.sqrt(Math.max(dist(0, stateY), dist(0, stateEndY), dist(width, stateY), dist(width, stateEndY)))

            rippleFadeAnim.complete();
            rippleAnim.restart();
        }
        onReleased: (event) => {
            rippleFadeAnim.restart();
        }
    }

    RippleAnim {
        id: rippleFadeAnim
        duration: rippleDuration * 2
        target: ripple
        property: "opacity"
        to: 0
    }

    SequentialAnimation {
        id: rippleAnim

        property real x
        property real y
        property real radius

        PropertyAction {
            target: ripple
            property: "x"
            value: rippleAnim.x
        }
        PropertyAction {
            target: ripple
            property: "y"
            value: rippleAnim.y
        }
        PropertyAction {
            target: ripple
            property: "opacity"
            value: 1
        }
        ParallelAnimation {
            RippleAnim {
                target: ripple
                properties: "implicitWidth,implicitHeight"
                from: 0
                to: rippleAnim.radius * 2
            }
        }
    }

    background: Rectangle {
        id: buttonBackground
        radius: Appearance?.rounding.small
        implicitHeight: 50
        color: (root.hovered ? root.colBackgroundHover : root.colBackground)
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: buttonBackground.width
                height: buttonBackground.height
                radius: buttonBackground.radius
            }
        }
        
        Behavior on color {
            animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Item {
            id: ripple
            width: ripple.implicitWidth
            height: ripple.implicitHeight
            opacity: 0

            property real implicitWidth: 0
            property real implicitHeight: 0
            visible: width > 0 && height > 0

            Behavior on opacity {
                animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: button.colRipple }
                    GradientStop { position: 0.3; color: button.colRipple }
                    GradientStop { position: 0.5 ; color: Qt.rgba(button.colRipple.r, button.colRipple.g, button.colRipple.b, 0) }
                }
            }

            transform: Translate {
                x: -ripple.width / 2
                y: -ripple.height / 2
            }
        }
    }
    
    contentItem: Item {
        id: tabContent
        anchors.centerIn: buttonBackground
        // Prefer Plumpy when enabled by the parent and an asset exists; fallback to MaterialSymbol
        readonly property bool usePlumpy: root.usePlumpyIcons
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Appearance?.font.pixelSize.hugeass ?? 25
                implicitHeight: Appearance?.font.pixelSize.hugeass ?? 25
                visible: (buttonIcon?.length ?? 0) > 0
                PlumpyIcon {
                    id: tabPlumpy
                    anchors.centerIn: parent
                    visible: parent.visible && tabContent.usePlumpy && name !== ''
                    iconSize: parent.implicitWidth
                    name: root.plumpyFromTabIcon(buttonIcon)
                    primaryColor: selected ? root.colActive : root.colInactive
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: parent.visible && (!tabContent.usePlumpy || !tabPlumpy.available || tabPlumpy.name === '')
                    horizontalAlignment: Text.AlignHCenter
                    text: buttonIcon
                    iconSize: parent.implicitWidth
                    fill: selected ? 1 : 0
                    color: selected ? root.colActive : root.colInactive
                }
            }
            StyledText {
                id: buttonTextWidget
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance?.font.pixelSize.small
                color: selected ? root.colActive : root.colInactive
                text: buttonText
                Behavior on color {
                    animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }
}