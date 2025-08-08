import QtQuick
import Quickshell
import qs.modules.common.functions
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    // Extremely conservative transparency values for consistency and readability
    property real transparency: Config.options?.appearance.transparency ? (m3colors.darkmode ? 0.1 : 0.07) : 0
    property real contentTransparency: Config.options?.appearance.transparency ? (m3colors.darkmode ? 0.55 : 0.55) : 0

    m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: false
        property color m3primary_paletteKeyColor: "#8aadf4"
        property color m3secondary_paletteKeyColor: "#837186"
        property color m3tertiary_paletteKeyColor: "#9D6A67"
        property color m3neutral_paletteKeyColor: "#7C757B"
        property color m3neutral_variant_paletteKeyColor: "#7D747D"
        property color m3background: "#24273a"
        property color m3onBackground: "#CAD3F5"
        property color m3surface: "#24273a"
        property color m3surfaceDim: "#24273a"
        property color m3surfaceBright: "#24273a"
        property color m3surfaceContainerLowest: "#24273A"
        property color m3surfaceContainerLow: "#24273A"
        property color m3surfaceContainer: "#24273A"
        property color m3surfaceContainerHigh: "#24273A"
        property color m3surfaceContainerHighest: "#24273A"
        property color m3onSurface: "#CAD3F5"
        property color m3surfaceVariant: "#4C444D"
        property color m3onSurfaceVariant: "#8aadf4"
        property color m3inverseSurface: "#CAD3F5"
        property color m3inverseOnSurface: "#342F34"
        property color m3outline: "#cad3f5"
        property color m3outlineVariant: "#a5adcb"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#8aadf4"
        property color m3primary: "#8aadf4"
        property color m3onPrimary: "#1e2030"
        property color m3primaryContainer: "#c6a0f6"
        property color m3onPrimaryContainer: "#c6a0f6"
        property color m3inversePrimary: "#c6a0f6"
        property color m3secondary: "#D5C0D7"
        property color m3onSecondary: "#b8c0e0"
        property color m3secondaryContainer: "#534457"
        property color m3onSecondaryContainer: "#b8c0e0"
        property color m3tertiary: "#F5B7B3"
        property color m3onTertiary: "#4C2523"
        property color m3tertiaryContainer: "#BA837F"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#FFB4AB"
        property color m3onError: "#ed8796"
        property color m3errorContainer: "#6e738d"
        property color m3onErrorContainer: "#FFDAD6"
        property color m3primaryFixed: "#F9D8FF"
        property color m3primaryFixedDim: "#c6a0f6"
        property color m3onPrimaryFixed: "#24273A"
        property color m3onPrimaryFixedVariant: "#c6a0f6"
        property color m3secondaryFixed: "#F2DCF3"
        property color m3secondaryFixedDim: "#D5C0D7"
        property color m3onSecondaryFixed: "#24273A"
        property color m3onSecondaryFixedVariant: "#514254"
        property color m3tertiaryFixed: "#FFDAD7"
        property color m3tertiaryFixedDim: "#F5B7B3"
        property color m3onTertiaryFixed: "#331110"
        property color m3onTertiaryFixedVariant: "#663B39"
        property color m3success: "#a6da95"
        property color m3onSuccess: "#a6da95"
        property color m3successContainer: "#6e738d"
        property color m3onSuccessContainer: "#6e738d"
        property color term0: "#faf4ed"
        property color term1: "#edd0c4"
        property color term2: "#ffc9c9"
        property color term3: "#ED8796"
        property color term4: "#A67F7C"
        property color term5: "#edd0c4"
        property color term6: "#c6a0f6"
        property color term7: "#1e2030"
        property color term8: "#181926"
        property color term9: "#edd0c4"
        property color term10: "#ffc9c9"
        property color term11: "#edd0c4"
        property color term12: "#ffc9c9"
        property color term13: "#edd0c4"
        property color term14: "#c6a0f6"
        property color term15: "#24273a"
    }

    colors: QtObject {
        property color colSubtext: "#b8c0e0"
        property color colLayer0: "#24273a"
        property color colOnLayer0: "#cad3f5"
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        property color colLayer1: "#1e2030"
        property color colOnLayer1: "#cad3f5"
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45);
        property color colLayer2: "#24273a"
        property color colOnLayer2: m3colors.m3onSurface;
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4);
        property color colLayer3: "#363a4f"
        property color colOnLayer3: m3colors.m3onSurface;
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency);
        property color colLayer2Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer2, colOnLayer2, 0.90), root.contentTransparency)
        property color colLayer2Active: ColorUtils.transparentize(ColorUtils.mix(colLayer2, colOnLayer2, 0.80), root.contentTransparency);
        property color colLayer2Disabled: ColorUtils.transparentize(ColorUtils.mix(colLayer2, m3colors.m3background, 0.8), root.contentTransparency);
        property color colLayer3Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer3, colOnLayer3, 0.90), root.contentTransparency)
        property color colLayer3Active: ColorUtils.transparentize(ColorUtils.mix(colLayer3, colOnLayer3, 0.80), root.contentTransparency);
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colLayer1Hover, 0.7)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colLayer1Active, 0.6)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, colLayer1Active, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colSurfaceContainerLow: ColorUtils.transparentize(m3colors.m3surfaceContainerLow, root.contentTransparency)
        property color colSurfaceContainer: "#1e2030"
        property color colSurfaceContainerHigh: ColorUtils.transparentize(m3colors.m3surfaceContainerHigh, root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.transparentize(m3colors.m3surfaceContainerHighest, root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        property color colTooltip: m3colors.darkmode ? ColorUtils.mix(m3colors.m3background, "#3C4043", 0.5) : "#3C4043" // m3colors.m3inverseSurface in the specs, but the m3 website actually uses #3C4043
        property color colOnTooltip: "#cad3f5" // m3colors.m3inverseOnSurface in the specs, but the m3 website actually uses this color
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutlineVariant: m3colors.m3outlineVariant
    }

    rounding: QtObject {
        property int unsharpen: 2
        property int unsharpenmore: 4
        property int verysmall: 4
        property int small: 4
        property int normal: 4
        property int large: 4
        property int verylarge: 4
        property int full: 4
        property int screenRounding: 4
        property int windowRounding: 4
    }

    font: QtObject {
        property QtObject family: QtObject {
            property string main: "Lexend"
            property string title: "Lexend"
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: "SpaceMono NF"
			property string iconFA: "Font Awesome 6 Pro"
            property string monospace: "JetBrains Mono NF"
            property string reading: "Readex Pro"
            property string expressive: "Google Sans"
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }
        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }
        property QtObject elementMoveExit: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }
        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }
        property QtObject clickBounce: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                    duration: root.animation.clickBounce.duration
                    easing.type: root.animation.clickBounce.type
                    easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standardDecel
        }
        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        property real baseBarHeight: 40
        property real barHeight: Config.options.bar.cornerStyle === 1 ? 
            (baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real osdWidth: 200
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real searchWidthCollapsed: 260
        property real searchWidth: 450
        property real hyprlandGapsOut: 5
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
    }

    syntaxHighlightingTheme: Appearance.m3colors.darkmode ? "Monokai" : "ayu Light"
}
