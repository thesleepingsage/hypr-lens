pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import "./functions"

// Appearance service with matugen integration
// Watches matugen.json for dynamic theming (path configurable via config.json)
// Falls back to blue Material You defaults when matugen.json is missing
Singleton {
    id: root

    // Default matugen path (used if config path is empty)
    readonly property string defaultMatugenPath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.config/quickshell/matugen.json"

    // Effective path: config setting takes priority, falls back to default
    readonly property string matugenPath: {
        const configPath = Config.options.appearance?.matugenPath ?? ""
        return configPath !== "" ? configPath : defaultMatugenPath
    }

    // Watch matugen.json for dynamic theming
    FileView {
        id: matugenFile
        path: root.matugenPath
        watchChanges: true
        onFileChanged: reload()
    }

    // Parse matugen colors, null if file missing/invalid
    readonly property var matugenColors: {
        const content = matugenFile.text()
        if (!content) return null
        try {
            return JSON.parse(content) ?? null
        } catch (e) {
            console.warn("[Appearance] Failed to parse matugen.json:", e)
            return null
        }
    }

    // Helper to get matugen color with fallback
    function mc(key, fallback) {
        return matugenColors?.[key] ?? fallback
    }

    property QtObject m3colors: QtObject {
        property bool darkmode: true
        // Blue Material You dark theme fallbacks
        property color m3background: mc("background", "#111318")
        property color m3onBackground: mc("on_background", "#e2e2e9")
        property color m3surface: mc("surface", "#111318")
        property color m3surfaceContainer: mc("surface_container", "#1d2024")
        property color m3surfaceContainerLow: mc("surface_container_low", "#191c20")
        property color m3surfaceContainerHigh: mc("surface_container_high", "#282a2f")
        property color m3onSurface: mc("on_surface", "#e2e2e9")
        property color m3onSurfaceVariant: mc("on_surface_variant", "#c4c6d0")
        property color m3outline: mc("outline", "#8e9099")
        property color m3outlineVariant: mc("outline_variant", "#44474f")
        property color m3primary: mc("primary", "#a8c7fa")
        property color m3onPrimary: mc("on_primary", "#062e6f")
        property color m3primaryContainer: mc("primary_container", "#284777")
        property color m3onPrimaryContainer: mc("on_primary_container", "#d3e3fd")
        property color m3secondary: mc("secondary", "#bec6dc")
        property color m3onSecondary: mc("on_secondary", "#283041")
        property color m3secondaryContainer: mc("secondary_container", "#3e4759")
        property color m3onSecondaryContainer: mc("on_secondary_container", "#dae2f9")
        property color m3tertiary: mc("tertiary", "#ddbce0")
        property color m3onTertiary: mc("on_tertiary", "#3f2844")
        property color m3tertiaryContainer: mc("tertiary_container", "#573e5c")
        property color m3onTertiaryContainer: mc("on_tertiary_container", "#fad8fd")
        property color m3inverseSurface: mc("inverse_surface", "#e2e2e9")
        property color m3inverseOnSurface: mc("inverse_on_surface", "#2e3036")
        property color m3shadow: mc("shadow", "#000000")
    }

    property QtObject colors: QtObject {
        property color colLayer0: m3colors.m3background
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer1: m3colors.m3surfaceContainerLow
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colLayer1Hover: ColorUtils.mix(colLayer1, colOnLayer1, 0.92)
        // colorMixRatio from config (lower = more contrast). Default 0.65, original was 0.85
        property color colLayer1Active: ColorUtils.mix(colLayer1, colOnLayer1, Config.options.appearance?.ripple?.colorMixRatio ?? 0.65)
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colPrimaryContainer, colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colPrimaryContainer, colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        property color colSecondary: m3colors.m3secondary
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        property color colTertiary: m3colors.m3tertiary
        property color colOnTertiary: m3colors.m3onTertiary
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
        // Surface colors used by ToolbarTabButton
        property color colSurfaceContainer: m3colors.m3surfaceContainer
        property color colOnSurface: m3colors.m3onSurface
        property color colShadow: m3colors.m3shadow
    }

    property QtObject rounding: QtObject {
        property int small: 12
        property int normal: 17
        property int large: 23
        property int windowRounding: 18
    }

    property QtObject font: QtObject {
        property QtObject family: QtObject {
            property string main: "sans-serif"
            property string iconMaterial: "Material Symbols Rounded"
        }
        property QtObject pixelSize: QtObject {
            property int smaller: 12
            property int small: 15
            property int normal: 16
            property int larger: 19
        }
    }

    readonly property QtObject animationCurves: QtObject {
        // Material 3 Expressive curves
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1]
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1]
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveEffectsDuration: 200

        // Standard Material curves (used by ripple)
        readonly property list<real> standardDecel: [0.00, 0.00, 0.20, 1.00, 1, 1]  // Decelerate
        readonly property list<real> standardAccel: [0.40, 0.00, 1.00, 1.00, 1, 1]  // Accelerate
        readonly property list<real> standard: [0.40, 0.00, 0.20, 1.00, 1, 1]       // Standard ease

        // Smooth/Elegant curves (Option 3 - premium feel)
        readonly property list<real> smoothElegant: [0.25, 0.10, 0.25, 1.00, 1, 1]  // Gentle, refined
        readonly property list<real> smoothEnter: [0.00, 0.00, 0.30, 1.00, 1, 1]    // Soft entrance
        readonly property real smoothDuration: 350  // Slightly slower for elegance
    }

    property QtObject animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: animationCurves.expressiveDefaultSpatialDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
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

        // Used by ripple and enter animations
        property QtObject elementMoveEnter: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standardDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }

        // Smooth/Elegant variant (Option 3) - swap with elementMoveFast to test
        property QtObject elementMoveSmooth: QtObject {
            property int duration: animationCurves.smoothDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.smoothElegant
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmooth.duration
                    easing.type: root.animation.elementMoveSmooth.type
                    easing.bezierCurve: root.animation.elementMoveSmooth.bezierCurve
                }
            }
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveSmooth.duration
                    easing.type: root.animation.elementMoveSmooth.type
                    easing.bezierCurve: root.animation.elementMoveSmooth.bezierCurve
                }
            }
        }
    }
}
