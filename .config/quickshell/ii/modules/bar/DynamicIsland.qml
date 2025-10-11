import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions


Item {
	id: dynamicIsland

	// Temporary clipboard drop/preview state
	property bool dropActive: false
	property bool dropSuccessFlash: false
	// Overlay label shown during drag-over; set in onEntered/onExited
	property string dropOverlayText: Translation.tr("Store in Dynamic Island")

	// Helper function to format seconds into HH:MM:SS
	function formatSeconds(seconds) {
		var hours = Math.floor(seconds / 3600);
		var minutes = Math.floor((seconds % 3600) / 60);
		var secs = Math.floor(seconds % 60);
		
		if (hours > 0) {
			return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
		}
		return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
	}

	// State properties
	property bool mediaActive: MprisController.activePlayer?.isPlaying || MprisController.activePlayer?.playbackState === MprisPlaybackState.Paused
	// Timer state used to show a left-side indicator (icon + time)
	property bool timerActive: TimerService.pomodoroRunning || TimerService.stopwatchRunning
	// Do not hide active window when timers are running; timers now occupy a left slot
	property bool showActiveWindow: !mediaActive

	// Dynamic width properties
	property real baseWidth: 320  // Wider default to accommodate music icon + text
	// Base max width (no timers). Additional allowance dynamically added equal to timer indicator width.
	property real maxWidthNoTimer: 640
	readonly property real timerAllowance: timerActive ? (((timerIndicatorSlot && timerIndicatorSlot.implicitWidth) || 0) + rowSpacing) : 0
	readonly property real effectiveMaxWidth: maxWidthNoTimer + timerAllowance
	property real minWidth: 300   // Ensure controls never overflow
	property real targetWidth: baseWidth
	// Set true when current media title qualifies as "short" by character count
	property bool shortTitleActive: false

	// Keep animation timings consistent across width and content transitions
	readonly property int resizeDuration: 400
	// Duration for lyric switching animation (slide + fade)
	readonly property int lyricsTransitionDuration: 220

	// Shared layout metrics (keep in sync with RowLayout content)
	// Used both by calculateContentWidth() and UI sizing to avoid drift
	readonly property int outerPadding: 16                    // combined left+right
	readonly property int rowSpacing: 4                       // spacing inside RowLayout
	readonly property int controlButtons: 18 * 3 + rowSpacing * 2 // three 18px buttons with gaps
	readonly property int lyricsIconSlot: 20                  // slot for the music-note toggle
	readonly property int progressNormal: 120
	readonly property int progressHover: 80
	// Titles at or below this pixel width should display fully without overflow
	readonly property int shortTitlePxThreshold: 240

	    // Sticky hover latch + toggle semantics for clipboard preview
    property bool clipboardPreviewLatched: false
    property bool clipboardPreviewActiveOverride: false
    // Explicit toggle: first hover enables preview persistently; second hover disables it
    property bool clipboardPreviewToggled: false
    // Debounce successive hover toggles and allow immediate second hover
    property int clipboardToggleCooldownMs: resizeDuration
    property double _clipboardLastToggleMs: 0
    readonly property bool rawClipboardHover: (
        (typeof hoverArea !== 'undefined' && hoverArea.containsMouse) ||
        (typeof clipHover !== 'undefined' && clipHover.containsMouse) ||
        (typeof previewLoader !== 'undefined' && previewLoader.item && previewLoader.item.popupHover && previewLoader.item.popupHover.containsMouse)
    )
    // Hover active: either toggled ON, or explicitly allowed via override (toggled OFF suppresses raw hover)
    readonly property bool clipboardHoverActive: clipboardPreviewToggled || clipboardPreviewActiveOverride
    // Track drag state to avoid unlatching during drag
    readonly property bool clipboardDragActive: (
        (typeof clipboardIconRect !== 'undefined' && clipboardIconRect.Drag && clipboardIconRect.Drag.active) ||
        (typeof clipboardPreviewOverlay !== 'undefined' && clipboardPreviewOverlay.Drag && clipboardPreviewOverlay.Drag.active)
    )

    // Helper: toggle clipboard preview immediately with cooldown
    function triggerClipboardToggle() {
        const now = Date.now()
        if (now - _clipboardLastToggleMs < clipboardToggleCooldownMs)
            return
        _clipboardLastToggleMs = now
        clipboardPreviewToggled = !clipboardPreviewToggled
        if (clipboardPreviewToggled) {
            clipboardPreviewLatched = true
            clipboardPreviewActiveOverride = true
            // If the pointer stays put through the resize animation, auto-reset to avoid getting stuck
            clipboardStayReset.restart()
        } else {
            clipboardPreviewLatched = false
            clipboardPreviewActiveOverride = false
            clipboardStayReset.stop()
        }
        Qt.callLater(updateWidth)
    }

    Timer {
        id: clipboardHoverGrace
        interval: 220
        repeat: false
        onTriggered: {
            if (!dynamicIsland.rawClipboardHover && !dynamicIsland.clipboardDragActive && !dynamicIsland.clipboardPreviewToggled) {
                dynamicIsland.clipboardPreviewActiveOverride = false
                dynamicIsland.clipboardPreviewLatched = false
                Qt.callLater(dynamicIsland.updateWidth)
            }
        }
    }

    // Auto-reset if the pointer stays in place throughout the animation while toggled on
    Timer {
        id: clipboardStayReset
        interval: dynamicIsland.resizeDuration + 40
        repeat: false
        onTriggered: {
            if (dynamicIsland.clipboardPreviewToggled && dynamicIsland.rawClipboardHover) {
                dynamicIsland.clipboardPreviewToggled = false
                dynamicIsland.clipboardPreviewActiveOverride = false
                dynamicIsland.clipboardPreviewLatched = false
                Qt.callLater(dynamicIsland.updateWidth)
            }
        }
    }

	// Force recalculation when content changes
	onMediaActiveChanged: {
		updateWidth()
	}
	
	onShowActiveWindowChanged: {
		updateWidth()
	}
	
	// Function to update width using targetWidth property
	function updateWidth() {
		var newWidth = calculateContentWidth()
		targetWidth = newWidth
	}

	// Debounced width recalculation to avoid chattering and ensure measurement has settled
	function scheduleWidthRecalc() {
		widthRecalcTimer.restart()
	}

	Timer {
		id: widthRecalcTimer
		interval: 1
		repeat: false
		onTriggered: dynamicIsland.updateWidth()
	}
	
	// Initialize width on component creation
	Component.onCompleted: {
		updateWidth()
	}
	
	// Highlight overlay when bar-level detector says we're in top-middle region
	Connections {
		target: GlobalStates
		function onIslandDropHighlightChanged() {
			if (GlobalStates.islandDropHighlight) {
				dynamicIsland.dropOverlayText = Translation.tr("Store in Dynamic Island")
				dynamicIsland.dropActive = true
			} else if (!dynamicIsland.dropSuccessFlash) {
				dynamicIsland.dropActive = false
			}
		}
	}

	// Hidden measurer for clipboard inline text width
    Text {
        id: clipboardTextMeasure
        visible: false
        text: ClipboardService.kind === "text" ? ClipboardService.text : ""
        wrapMode: Text.NoWrap
        font.pixelSize: Appearance.fontSizes.small
        font.family: Appearance.fontFamily
    }

    // Inline Clipboard Text overrides other content when present
    Item {
        id: clipboardPreviewOverlay
        // Show inline clipboard text while hovering or when preview is latched/overridden
        visible: ClipboardService.kind === "text" && (dynamicIsland.clipboardHoverActive || dynamicIsland.clipboardPreviewLatched || dynamicIsland.clipboardPreviewActiveOverride)
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
        // Keep overlay above media but below the clipboard icon (icon z: 401)
        z: 350
        anchors.fill: parent // ensure overlay covers the whole island
        clip: true
		// Keep some space on the left for timer and clipboard icon area to avoid overlap
		// Compute dynamically: timerSlot + spacing + clipboardSlot + small padding
		property int leftReserve: (
			(dynamicIsland.timerActive ? ((timerIndicatorSlot?.implicitWidth || 0) + 6) : 0) +
			(ClipboardService.hasItem ? (22 + 6) : 0) + 8
		)
        anchors.leftMargin: leftReserve

        // Enable dragging out by dragging on the preview overlay
        Drag.supportedActions: Qt.CopyAction
        Drag.proposedAction: Qt.CopyAction
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.onActiveChanged: {
            console.log("clipboardPreviewOverlay Drag active:", Drag.active)
            if (Drag.active) {
                // Build drag data and force a drag image from the current overlay appearance
                ClipboardService.buildDragData(clipboardPreviewOverlay)
                clipboardPreviewOverlay.grabToImage(function(result) {
                    if (result && result.url && Drag.active) {
                        clipboardPreviewOverlay.Drag.imageSource = result.url
                    }
                })
            } else {
                ClipboardService.clear()
            }
        }

        // Reliable activation: prepare drag payload and image BEFORE turning Drag.active on
        DragHandler {
            id: overlayDragHandler
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: {
                if (active) {
                    // Prepare data and image first
                    ClipboardService.buildDragData(clipboardPreviewOverlay)
                    // If no image yet (e.g., text/urls), ensure we have some image before activation
                    if (clipboardPreviewOverlay.Drag.imageSource === undefined
                        || clipboardPreviewOverlay.Drag.imageSource === null) {
                        // Provide a tiny inline SVG as a guaranteed default; service also sets one for text/urls
                        clipboardPreviewOverlay.Drag.imageSource = "data:image/svg+xml;utf8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='8' height='8'%3E%3Crect width='8' height='8' rx='2' ry='2' fill='%23303446'/%3E%3C/svg%3E"
                    }
                    // Start the drag immediately (do not wait for snapshot callbacks)
                    clipboardPreviewOverlay.Drag.active = true
                    // Best-effort: update image to a snapshot of the overlay once available
                    clipboardPreviewOverlay.grabToImage(function(result) {
                        if (result && result.url && clipboardPreviewOverlay.Drag.active) {
                            clipboardPreviewOverlay.Drag.imageSource = result.url
                        }
                    })
                } else {
                    console.log("overlay DragHandler became inactive")
                }
            }
        }

        // Background that sits in front of original content
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer2
            opacity: 1.0
        }

        // Centered text row
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 6
            Item { Layout.fillWidth: true; Layout.fillHeight: true }
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: parent ? parent.width - 16 : 0
                StyledText {
                    id: clipboardInlineText
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: ClipboardService.text
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
            }
            Item { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        // Allow hover grace but do not steal drag/click from the clipboard icon
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            preventStealing: true
            propagateComposedEvents: true
            onEntered: { clipboardHoverGrace.stop() }
            onExited: { clipboardHoverGrace.start() }
        }

        // Drag handler to start drag when user drags on the preview
        DragHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            target: null
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: {
                if (active) {
                    // Latch preview so it doesn't disappear mid-gesture
                    dynamicIsland.clipboardPreviewLatched = true
                    ClipboardService.buildDragData(clipboardPreviewOverlay)
                    clipboardPreviewOverlay.Drag.active = true
                } else {
                    console.log("overlay DragHandler became inactive")
                }
            }
        }

        // Also support long-press to begin drag without movement
        TapHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
            // Optional: tweak threshold if needed
            // longPressThreshold: 350
            onLongPressed: {
                dynamicIsland.clipboardPreviewLatched = true
                ClipboardService.buildDragData(clipboardPreviewOverlay)
                clipboardPreviewOverlay.Drag.active = true
            }
        }
    }

	// Recalculate width when clipboard state changes
	Connections {
		target: ClipboardService
		        function onChanged() {
            Qt.callLater(function(){ dynamicIsland.updateWidth() })
            if (ClipboardService.hasItem && (dynamicIsland.dropActive || GlobalStates.islandDropHighlight)) {
                dynamicIsland.dropOverlayText = Translation.tr("Saved to Island")
                dynamicIsland.dropSuccessFlash = true
                dynamicIsland.dropActive = true
                successFlashTimer.restart()
                GlobalStates.islandDropHighlight = false
            }
        }
        function onCleared() {
            // Reset preview/toggle state and width when clipboard is emptied
            dynamicIsland.clipboardPreviewToggled = false
            dynamicIsland.clipboardPreviewActiveOverride = false
            dynamicIsland.clipboardPreviewLatched = false
            Qt.callLater(function(){ dynamicIsland.updateWidth() })
        }
    }
	
	// Watch for media title/artist changes
	Connections {
		target: MprisController.activePlayer
		function onTrackTitleChanged() {
			if (mediaActive) {
				updateWidth()
			}
		}
		function onTrackArtistChanged() {
			if (mediaActive) {
				updateWidth()
			}
		}
	}
	
	// Watch for window title changes
	Connections {
		target: root.activeWindow
		function onTitleChanged() {
			if (showActiveWindow) {
				updateWidth()
			}
		}
	}

	// Watch for timer changes to adjust width for left-side indicator
	Connections {
		target: TimerService
		function onPomodoroRunningChanged() { Qt.callLater(function(){ dynamicIsland.updateWidth() }) }
		function onStopwatchRunningChanged() { Qt.callLater(function(){ dynamicIsland.updateWidth() }) }
		function onPomodoroSecondsLeftChanged() { /* no width change unless digits grow; safe to update occasionally */ Qt.callLater(function(){ dynamicIsland.updateWidth() }) }
		function onStopwatchTimeChanged() { Qt.callLater(function(){ dynamicIsland.updateWidth() }) }
	}

	// Watch for active window switches
	Connections {
		target: ToplevelManager
		function onActiveToplevelChanged() {
			if (showActiveWindow) {
				updateWidth()
			}
		}
	}

	// Calculate required width based on content
	function calculateContentWidth() {
	// Use shared metrics so calc matches layout exactly
    const outerPadding = dynamicIsland.outerPadding
    const rowSpacing = dynamicIsland.rowSpacing
    const controlButtons = dynamicIsland.controlButtons
    // Only shrink progress on hover if the title is actually truncated
    const progressPreferred = (titleContainer?.titleHovered && titleContainer?.titleTruncated)
        ? dynamicIsland.progressHover
        : dynamicIsland.progressNormal
	// Pre-compute any left timer slot width addition
	const timerAdd = dynamicIsland.timerActive ? (((timerIndicatorSlot && timerIndicatorSlot.implicitWidth) || 0) + rowSpacing) : 0
	// If clipboard inline text is present AND we're hovering the clipboard icon/popup, override all other content
    const clipboardHover = dynamicIsland.clipboardHoverActive
	if (ClipboardService.kind === "text" && clipboardHover) {
		const minWidth = dynamicIsland.minWidth
		const maxWidth = dynamicIsland.effectiveMaxWidth
        const clipIconSlot = ClipboardService.hasItem ? 22 : 0
        // baseline measured clipboard text width
        let textWidth = clipboardTextMeasure?.contentWidth || 0
        // Desired: outer padding + icon slot + spacing + text width
		let desired = outerPadding + timerAdd + clipIconSlot + (clipIconSlot > 0 ? rowSpacing : 0) + Math.max(60, textWidth)
		let clamped = Math.max(minWidth, Math.min(maxWidth, desired))
        return clamped
    }


		if (mediaActive) {
			// Measure the media title's actual implicit width if available
			// let titleWidth = mediaTitle?.implicitWidth || 0
			// Fallback if not yet resolved
			// Prioritize baseline-measured title width (hidden measurer)
			let titleWidth = mediaTitleMeasure?.contentWidth || 0
			// When lyrics mode is active, base the dynamic width on the current lyric line
			let lyricWidth = GlobalStates.lyricsModeActive ? (lyricMeasure?.contentWidth || 0) : 0
			let textWidth = GlobalStates.lyricsModeActive ? lyricWidth : titleWidth

			// In lyrics mode, progress is hidden. Otherwise, shrink only when hover+truncated
			// Evaluate hover/truncation state up-front for consistent logic
			const hoveringTruncated = GlobalStates.lyricsModeActive ? false : !!(titleContainer?.titleHovered && (titleContainer?.titleTruncatedLatched || titleContainer?.titleTruncated))
			const hoveringNotTruncated = GlobalStates.lyricsModeActive ? false : !!(titleContainer?.titleHovered && !(titleContainer?.titleTruncatedLatched || titleContainer?.titleTruncated))
			// Compute desired widths for normal (non-hover) and hover states explicitly
			const normalProgress = GlobalStates.lyricsModeActive ? 0 : dynamicIsland.progressNormal
			const hoverProgress = GlobalStates.lyricsModeActive ? 0 : (hoveringTruncated ? dynamicIsland.progressHover : dynamicIsland.progressNormal)
			const controlsWidth = GlobalStates.lyricsModeActive ? 0 : controlButtons
			const widthBuffer = 12 // Add tolerance to prevent clipping
			// Always include the lyrics icon slot when media is active
			const iconSlot = dynamicIsland.lyricsIconSlot
			let textDesiredWidth = textWidth + widthBuffer
			let desiredNormal = outerPadding + iconSlot + rowSpacing + textDesiredWidth + (normalProgress > 0 ? rowSpacing + normalProgress : 0) + (controlsWidth > 0 ? rowSpacing + controlsWidth : 0)
			let desiredHover = outerPadding + iconSlot + rowSpacing + textWidth + (hoverProgress > 0 ? rowSpacing + hoverProgress : 0) + (controlsWidth > 0 ? rowSpacing + controlsWidth : 0) + widthBuffer

			// In lyrics mode, ignore title hover/truncation behavior entirely (handled above)

			// If the full title fits, use that width. Otherwise, evaluate hover width too.
			const fullWidthFits = desiredNormal < dynamicIsland.effectiveMaxWidth
			dynamicIsland.shortTitleActive = fullWidthFits // Reuse this flag to control layout

			// On hover, never shrink the island due to reduced progress - pick the larger width
			const isHover = (!GlobalStates.lyricsModeActive && !!titleContainer?.titleHovered)
			let desired = (isHover ? Math.max(desiredNormal, desiredHover) : desiredNormal) + timerAdd

			const clamped = Math.max(minWidth, Math.min(desired, dynamicIsland.effectiveMaxWidth))
			return clamped
		} else if (showActiveWindow) {
			// Prefer baseline-measured title width (hidden measurer), then fallback to implicitWidth
			dynamicIsland.shortTitleActive = false
			let measured = (activeWindowTitleMeasure?.contentWidth || 0)
			if (measured <= 0) measured = activeWindowTitle?.implicitWidth || 0
			let fallbackText = root.activeWindow?.title || ""
			let windowWidth = Math.max(60, measured > 0 ? measured : fallbackText.length * 7.5)
			// Active window needs less outer padding than media (controls/progress absent)
			let desired = windowWidth + 12 + timerAdd
			let clamped = Math.max(minWidth, Math.min(dynamicIsland.effectiveMaxWidth, desired))
			return clamped
		}
		dynamicIsland.shortTitleActive = false
		return baseWidth + timerAdd
	}

	// Visualizer data properties - connected to global state
	property list<var> visualizerPoints: GlobalStates.visualizerPoints || []
	property real maxVisualizerValue: 1000
	property int visualizerSmoothing: 1

	// Ensure visualizer data even if MediaControls isn't loaded
	Process {
		id: cavaProcIsland
		running: MprisController.activePlayer?.isPlaying || false
		onRunningChanged: {
			if (!running) {
				visualizerPoints = []
				if (typeof GlobalStates !== 'undefined') GlobalStates.visualizerPoints = []
			}
		}
		command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
		stdout: SplitParser {
			onRead: data => {
				let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
				visualizerPoints = points;
				if (typeof GlobalStates !== 'undefined') GlobalStates.visualizerPoints = points;
			}
		}
	}

	// Visualizer points updated; no verbose logging to avoid console noise
	onVisualizerPointsChanged: {}

	// Layout properties
	// Let parent layouts position/size us; also set explicit width to drive animations reliably
	implicitWidth: targetWidth
	Layout.preferredWidth: targetWidth
	Layout.minimumWidth: minWidth
	Layout.maximumWidth: effectiveMaxWidth
	width: targetWidth
	height: 32
	clip: true // keep children inside the island bounds
	property bool hovered: false

	// Smooth width animation (works for both explicit width and layouts)
	Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
	Behavior on Layout.preferredWidth { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
	// Also animate the driving property itself so bindings propagate smoothly
	Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }

	// Background with visualizer overlay - must be first to render behind content
	Rectangle {
		id: dynamicIslandBackground
		anchors.fill: parent
		color: "transparent" // Match the bar's transparent background approach
		radius: Appearance.rounding.full
		clip: true
		
		// Background only; WaveVisualizer moved to a sibling to control stacking order
	}

	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onEntered: dynamicIsland.hovered = true
		onExited: dynamicIsland.hovered = false
		onClicked: {
			GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
		}
	}

	// Accept drops for temporary clipboard
	DropArea {
		id: islandDropArea
		anchors.fill: parent
		z: 300
		// Disable DropArea while our own clipboard drag is active to avoid self-activation
		enabled: !dynamicIsland.clipboardDragActive || GlobalStates.islandDropHighlight
		onEntered: (drag) => {
			// Ignore drags originating from our own clipboard sources (icon or overlay)
			if (drag && (drag.source === clipboardPreviewOverlay || drag.source === clipboardIconRect)) {
				return
			}
			dynamicIsland.dropActive = true
			dynamicIsland.dropOverlayText = Translation.tr("Store in Dynamic Island")
		}
		onExited: {
			dynamicIsland.dropActive = false
		}
		onDropped: (event) => {
			try {
				ClipboardService.storeFromDrop(event)
				dynamicIsland.dropOverlayText = Translation.tr("Saved to Island")
				dynamicIsland.dropSuccessFlash = true
				dynamicIsland.dropActive = true
				successFlashTimer.restart()
				// Accept and clear global highlight
				event.acceptProposedAction()
				GlobalStates.islandDropHighlight = false
			} catch (e) {
				console.log("DynamicIsland drop error:", e)
			}
		}
	}

	Timer {
		id: successFlashTimer
		interval: 900
		repeat: false
		onTriggered: {
			dynamicIsland.dropSuccessFlash = false
			dynamicIsland.dropActive = false
		}
	}

	// Drag overlay: overrides content during drag-over or success flash
	Rectangle {
		anchors.fill: parent
		z: 350
		// Do not show drop overlay while we're dragging our own clipboard item
		visible: ((dynamicIsland.dropActive && !dynamicIsland.clipboardDragActive) || dynamicIsland.dropSuccessFlash)
		radius: Appearance.rounding.full
		color: Appearance.colors.colLayer1
		opacity: (dynamicIsland.dropActive || dynamicIsland.dropSuccessFlash) ? 0.92 : 0.0
		Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

		RowLayout {
			anchors.fill: parent
			anchors.margins: 8
			spacing: 6
			Item { Layout.fillWidth: true }
			Item {
				Layout.alignment: Qt.AlignVCenter
				implicitWidth: Appearance.font.pixelSize.larger
				implicitHeight: Appearance.font.pixelSize.larger
				readonly property bool usePlumpy: true
				PlumpyIcon { id: diDropPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy && dynamicIsland.dropSuccessFlash; iconSize: parent.implicitWidth; name: 'clipboard-approve'; primaryColor: Appearance.colors.colOnLayer1 }
				MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !diDropPlumpy.available; text: "inventory"; iconSize: parent.implicitWidth; color: Appearance.colors.colOnLayer1 }
			}
			StyledText {
				text: dynamicIsland.dropOverlayText
				font.pixelSize: Appearance.font.pixelSize.small
				color: Appearance.colors.colOnLayer1
				Layout.alignment: Qt.AlignVCenter
			}
			Item { Layout.fillWidth: true }
		}
	}

	// Wave visualizer on top, clipped to rounded island
	Rectangle {
		anchors.fill: parent
		z: -1
		color: "transparent"
		radius: Appearance.rounding.full
		clip: true
		// MouseArea has z:200, so interactions are not affected
		WaveVisualizer {
			anchors.fill: parent
			live: MprisController.activePlayer?.isPlaying
			points: dynamicIsland.visualizerPoints
			maxVisualizerValue: dynamicIsland.maxVisualizerValue
			smoothing: dynamicIsland.visualizerSmoothing
			color: Appearance.colors.colPrimary
			// Tune for short island height
			amplitude: 0.9
			minFill: 0.0
			heightRatio: 0.9   // use ~90% of height
			baseOffset: 0.0   // keep 0% headroom at top
			fillAlpha: live ? 0.55 : 0.0
			blurAmount: 0.2
			strokeOpacity: 0.12
			autoScale: true
			visible: !dynamicIsland.clipboardHoverActive
		}
	}

	// Main layout
	RowLayout {
		anchors.fill: parent
		spacing: 8
		// Keep row present so clipboard indicator/icon remains while previewing
		visible: true

		// Timer indicator slot on the far left (compact like clipboard/music)
		Item {
			id: timerIndicatorSlot
			visible: dynamicIsland.timerActive
			Layout.fillHeight: true
			implicitWidth: contentRow.implicitWidth
			RowLayout {
				id: contentRow
				anchors.verticalCenter: parent.verticalCenter
				spacing: 6
				// Pomodoro group: circular progress + time
				RowLayout {
					visible: TimerService.pomodoroRunning
					spacing: 4
					Layout.alignment: Qt.AlignVCenter
					ClippedFilledCircularProgress {
						id: pomoCirc
						Layout.alignment: Qt.AlignVCenter
						implicitSize: 20
						lineWidth: Appearance.rounding.unsharpen
						value: TimerService.pomodoroLapDuration > 0 ? (TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration) : 0
						colPrimary: Appearance.colors.colOnSecondaryContainer
						accountForLightBleeding: true
						Item {
							anchors.centerIn: parent
							width: pomoCirc.implicitSize
							height: pomoCirc.implicitSize
							MaterialSymbol {
								anchors.centerIn: parent
								font.weight: Font.DemiBold
								fill: 1
								text: "timer"
								iconSize: Appearance.font.pixelSize.normal
								color: Appearance.m3colors.m3onSecondaryContainer
							}
						}
					}
					StyledText {
						Layout.alignment: Qt.AlignVCenter
						text: dynamicIsland.formatSeconds(TimerService.pomodoroSecondsLeft)
						font.pixelSize: Appearance.font.pixelSize.small
						font.family: Appearance.fontFamily
						color: Appearance.colors.colOnLayer1
					}
				}
				// Stopwatch group: icon + time
				RowLayout {
					visible: TimerService.stopwatchRunning
					spacing: 4
					Layout.alignment: Qt.AlignVCenter
					MaterialSymbol {
						Layout.alignment: Qt.AlignVCenter
						text: "timer"
						iconSize: Appearance.font.pixelSize.normal - 2
						color: Appearance.m3colors.m3onSecondaryContainer
					}
					StyledText {
						Layout.alignment: Qt.AlignVCenter
						text: dynamicIsland.formatSeconds(Math.floor(TimerService.stopwatchTime * 0.01))
						font.pixelSize: Appearance.font.pixelSize.small
						font.family: Appearance.fontFamily
						color: Appearance.colors.colOnLayer1
					}
				}
			}
		}

		// Clipboard indicator slot (left of media text)
		Item {
			id: clipboardIndicatorSlot
			visible: ClipboardService.hasItem
			// Ensure this slot (and its icon) is above overlay stacking contexts
			z: 2000
			Layout.preferredWidth: visible ? 22 : 0
			Layout.fillHeight: true
			clip: false

			// Preview popup on hover
			MouseArea {
				id: clipHover
				anchors.fill: parent
				hoverEnabled: true
				acceptedButtons: Qt.NoButton
				preventStealing: true
				onEntered: {
                    clipboardHoverGrace.stop()
                    triggerClipboardToggle()
                }
                onExited: {
                    // Start grace timer; if pointer doesn't re-enter any area, unlatch
                    clipboardHoverGrace.start()
                }
			}
			Loader {
				id: previewLoader
				anchors.fill: parent
				z: 1000
				active: ClipboardService.hasItem && ClipboardService.kind !== "text"
				visible: active && dynamicIsland.clipboardHoverActive
				sourceComponent: Rectangle {
					z: 1000
					radius: Appearance.rounding.small
					color: Appearance.colors.colLayer2
					border.color: Appearance.colors.colLayer2Border
					border.width: 1
					width: 220
					height: dynamicIsland.height
					anchors {
						// Keep popup within island bounds to avoid clipping
						right: parent.right
						rightMargin: 0
						verticalCenter: parent.verticalCenter
					}
					clip: true
					// Expose hover area so Loader can detect pointer inside the popup
					property alias popupHover: popupHoverArea
					// Keep popup visible while hovering; do not toggle here
					MouseArea {
						id: popupHoverArea
						anchors.fill: parent
						hoverEnabled: true
						acceptedButtons: Qt.NoButton
						preventStealing: true
						onEntered: { clipboardHoverGrace.stop() }
						onExited: { clipboardHoverGrace.start() }
					}
					Item {
						anchors.fill: parent
						// Image preview
						Loader {
							anchors.fill: parent
							active: ClipboardService.kind === "image" && !!ClipboardService.imageUrl
							sourceComponent: Image {
								anchors.fill: parent
								fillMode: Image.PreserveAspectFit
								source: ClipboardService.imageUrl
							}
						}
					}
				}
			}

			// Draggable clipboard icon
			Rectangle {
				id: clipboardIconRect
				anchors.centerIn: parent
				width: 18; height: 18
				radius: 6
				z: 401
				color: Appearance.colors.colSecondaryContainer
				border.color: Appearance.colors.colPrimary
				border.width: 1
				// Attach Drag to the icon itself for reliability
				Drag.supportedActions: Qt.CopyAction
				Drag.proposedAction: Qt.CopyAction
				Drag.hotSpot.x: 9
				Drag.hotSpot.y: 9
				Drag.onActiveChanged: {
					if (!Drag.active) ClipboardService.clear()
				}
				Item {
					anchors.centerIn: parent
					width: 14; height: 14
					readonly property bool usePlumpy: true
					PlumpyIcon { id: diClipboardPlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: 'copy'; primaryColor: Appearance.colors.colOnSecondaryContainer }
					MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !diClipboardPlumpy.available; text: "content_paste"; iconSize: parent.width; color: Appearance.colors.colOnSecondaryContainer }
				}
				MouseArea {
					id: hoverArea
					anchors.fill: parent
					hoverEnabled: true
					preventStealing: true
					propagateComposedEvents: false
					cursorShape: Qt.PointingHandCursor
					acceptedButtons: Qt.LeftButton | Qt.RightButton
					onPressed: (event) => { event.accepted = true }
					onClicked: (event) => { event.accepted = true }
					onPressAndHold: {
						ClipboardService.buildDragData(clipboardIconRect)
						clipboardIconRect.Drag.active = true
					}
					onEntered: { clipboardHoverGrace.stop(); triggerClipboardToggle() }
					onExited: {
						clipboardHoverGrace.start()
					}
				}
				DragHandler {
					acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
					target: null
					grabPermissions: PointerHandler.CanTakeOverFromAnything
					onActiveChanged: {
						if (active) {
							ClipboardService.buildDragData(clipboardIconRect)
							clipboardIconRect.Drag.active = true
						}
					}
				}
			}
		}

		// Hidden measurer for stable baseline media title width
		StyledText {
			id: mediaTitleMeasure
			visible: false
			text: (MprisController.activePlayer?.trackTitle || "") + (MprisController.activePlayer?.trackArtist ? " - " + MprisController.activePlayer?.trackArtist : "")
			font.pixelSize: Appearance.font.pixelSize.small
			elide: Text.ElideNone
			horizontalAlignment: Text.AlignLeft
			clip: false
		}

		// Hidden measurer for lyrics current line width
		StyledText {
			id: lyricMeasure
			visible: false
			text: (GlobalStates.lyricsModeActive ? (LyricsService.available ? (LyricsService.currentText || "") : Translation.tr("Fetching lyrics...")) : "")
			font.pixelSize: Appearance.font.pixelSize.small
			elide: Text.ElideNone
			horizontalAlignment: Text.AlignLeft
			clip: false
		}

		// Ensure fetch triggers when toggling lyrics mode on
		Connections {
			target: GlobalStates
			function onLyricsModeActiveChanged() {
				if (GlobalStates.lyricsModeActive) {
					LyricsService.maybeFetch()
				}
				// Recalc on both enabling and disabling lyrics mode
				Qt.callLater(function(){ dynamicIsland.scheduleWidthRecalc() })
			
		}
	}

	// Media section
	Item {
		// Hide media content while ANY clipboard preview overlay is active
		// - Non-text: during hover
		// - Text: during hover, or when latched/override keeps it on
		visible: dynamicIsland.mediaActive && !(
			(dynamicIsland.clipboardHoverActive && ClipboardService.kind !== "text") ||
			(ClipboardService.kind === "text" && (dynamicIsland.clipboardHoverActive || dynamicIsland.clipboardPreviewLatched || dynamicIsland.clipboardPreviewActiveOverride))
		)
		// Let RowLayout manage sizing
		Layout.fillWidth: true
		Layout.fillHeight: true
		RowLayout {
			anchors.fill: parent
			spacing: 4
			// Lyrics toggle icon (music note) to the left of title/artist
			Item {
				id: lyricsToggleSlot
				visible: dynamicIsland.mediaActive
				Layout.preferredWidth: 20
				Layout.fillHeight: true
				Layout.alignment: Qt.AlignVCenter
				Rectangle {
					anchors.centerIn: parent
					width: 18; height: 18
					radius: 6
					color: GlobalStates.lyricsModeActive ? Appearance.colors.colSecondaryContainer : "transparent"
					border.color: GlobalStates.lyricsModeActive ? Appearance.colors.colPrimary : "transparent"
					border.width: GlobalStates.lyricsModeActive ? 1 : 0
					Item {
						anchors.centerIn: parent
						width: 14; height: 14
						readonly property bool usePlumpy: true
						PlumpyIcon { id: diMusicNotePlumpy; anchors.centerIn: parent; visible: parent.usePlumpy; iconSize: parent.width; name: 'icons8-music-note'; primaryColor: GlobalStates.lyricsModeActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1 }
						MaterialSymbol { anchors.centerIn: parent; visible: !parent.usePlumpy || !diMusicNotePlumpy.available; text: "music_note"; iconSize: parent.width; color: GlobalStates.lyricsModeActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1 }
					}
					MouseArea {
						id: lyricsToggleArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							GlobalStates.lyricsModeActive = !GlobalStates.lyricsModeActive
							if (GlobalStates.lyricsModeActive) {
								LyricsService.maybeFetch()
							}
							Qt.callLater(function(){ dynamicIsland.updateWidth() })
						}
					}
				}
			}

			// Media info popup on hover of the music-note toggle
			MediaInfoPopup {
				hoverTarget: lyricsToggleArea
			}
			// Info container (title/artist or lyrics or timer)
			Item {
				id: titleContainer
				// Ensure title sits above progress bar and controls
				z: 10
				Layout.fillWidth: true
				// Leave room for progress + controls + paddings using shared metrics
				Layout.preferredWidth: GlobalStates.lyricsModeActive
					? (parent ? parent.width : 0)
					: (((mediaTitleMeasure?.contentWidth || 0) > 0) ? (mediaTitleMeasure.contentWidth + 12) : 0)
				Layout.fillHeight: true
				Layout.alignment: Qt.AlignVCenter
				Layout.leftMargin: GlobalStates.lyricsModeActive ? 0 : 8

					
					property bool titleHovered: false
					// Reactive (live) truncation against current width
					property bool titleTruncated: mediaTitle.implicitWidth > titleScrollContainer.width
					// Latched truncation state captured at hover start to prevent oscillation
					property bool titleTruncatedLatched: false
					property int titleWidthBeforeHover: 0
					property bool shouldAnimateTitle: titleHovered && (titleTruncatedLatched || (mediaTitle.implicitWidth > titleScrollContainer.width))
					
					// Recalculate island width when hover/truncation state changes
					onTitleHoveredChanged: {
						if (titleHovered) {
							// Capture baseline width and latch truncation state to avoid hover oscillation
							titleWidthBeforeHover = titleScrollContainer.width
							titleTruncatedLatched = (mediaTitle.implicitWidth > titleWidthBeforeHover)
							if (titleContainer.titleTruncatedLatched) {
								marqueeAnim.restart()
							}
						} else {
							// Reset scroll position and latch when hover ends
							mediaTitle.x = 0
							titleTruncatedLatched = false
						}
						if (dynamicIsland.mediaActive) dynamicIsland.updateWidth()
					}
					onTitleTruncatedChanged: {
						if (titleContainer.titleHovered && titleContainer.titleTruncatedLatched) {
							marqueeAnim.restart()
						} else if (!titleContainer.titleTruncated) {
							mediaTitle.x = 0
						}
					}
					Behavior on Layout.maximumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}

					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						onEntered: {
							// Start hover immediately; animation will run only if truncated
							titleContainer.titleHovered = true
						}
						onExited: titleContainer.titleHovered = false
						onClicked: {
							// Propagate click to parent to open media controls
							GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
						}
					}
					// Content area: shows media title or lyrics based on flag
					Flickable {
						id: titleScrollContainer
						// Ensure the title area actually has width/height and clips overflow
						anchors.fill: parent
						clip: true
						interactive: false
						boundsBehavior: Flickable.StopAtBounds
						contentWidth: GlobalStates.lyricsModeActive ? width : (titleContainer.titleHovered ? mediaTitle.implicitWidth : width)
						contentHeight: GlobalStates.lyricsModeActive ? height : Math.max(mediaTitle.implicitHeight, height)

						// Lyrics view
						Item {
							id: lyricsView
							anchors.fill: parent
							visible: GlobalStates.lyricsModeActive
							opacity: visible ? 1 : 0
							Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
							property string currentText: (GlobalStates.lyricsModeActive ? (LyricsService.available ? (LyricsService.currentText || "") : Translation.tr("Fetching lyrics...")) : "")
							property string prevText: ""
							property int __tickCount: 0
                            // Drive karaoke highlight with an internal timer using effective position
                            property int karaokeMs: 0
                            property int __lastIdx: -1
                            // Small lead to compensate for UI latency/perception
                            property int karaokeLeadMs: 0
                            // Minimum leading-gap duration for dots; applied to KaraokeLine.gapMinMs
                            property int lyricsGapMinMs: 0
                            // Faster tick for smoother per-word progress
                            Timer {
                                id: karaokeTick
                                running: (GlobalStates.lyricsModeActive && dynamicIsland.mediaActive)
                                repeat: true
                                interval: 16 // ~60 FPS for smoother highlighting
                                onTriggered: {
                                    // Use raw effective playback position (ms) as the sole driver
                                    lyricsView.karaokeMs = LyricsService.effectivePosMs()
                                }
                            }
                            // Continuously drive highlighting for both old/new items
                            onKaraokeMsChanged: {
                                if (LyricsService.karaoke) {
                                    if (lyricOld.item) lyricOld.item.currentMs = karaokeMs
                                    if (lyricNew.item) lyricNew.item.currentMs = karaokeMs
                                }
                            }
							onVisibleChanged: {
                                console.log("DynamicIsland: lyricsView visible=", visible, "lyricsMode=", GlobalStates.lyricsModeActive, "timerActive=", dynamicIsland.timerActive)
                                if (visible) {
                                    // Ensure no residual scroll offset from title mode
                                    titleScrollContainer.contentX = 0
                                    titleScrollContainer.contentY = 0
									if (dynamicIsland.mediaActive) Qt.callLater(dynamicIsland.scheduleWidthRecalc)
                                }
                            }

                            // Centered stack for lyric line switching
                            Item {
                                id: lyricStack
                                anchors.centerIn: parent
                                width: parent.width
                                height: Math.max(
                                    lyricNew.item ? lyricNew.item.implicitHeight : 0,
                                    lyricOld.item ? lyricOld.item.implicitHeight : 0
                                )

                                // Two-line switcher for slide animation
                                Loader {
                                    id: lyricOld
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 0
                                    opacity: 0
                                    z: 1
                                    width: lyricStack.width
                                    sourceComponent: LyricsService.karaoke ? karaokeComp : textComp
									onLoaded: {
                                        console.log("DynamicIsland: lyricOld loaded comp=", (LyricsService.karaoke ? "karaoke" : "text"), "karaoke=", LyricsService.karaoke)
                                        // Enforce correct component (avoid flicker by only changing when needed)
                                        const targetOld = LyricsService.karaoke ? karaokeComp : textComp
                                        if (lyricOld.sourceComponent !== targetOld) lyricOld.sourceComponent = targetOld
                                        // Explicit No-lyrics fallback
                                        if (!LyricsService.available || !(LyricsService.lines && LyricsService.lines.length > 0)) {
                                            if (lyricOld.item) {
                                                lyricOld.item.text = qsTr("No lyrics")
                                                lyricOld.item.font.pixelSize = Appearance.font.pixelSize.small
                                                lyricOld.item.color = Appearance.colors.colOnLayer1
                                                lyricOld.item.horizontalAlignment = Text.AlignHCenter
                                                lyricOld.item.width = lyricStack.width
                                            }
                                            return
                                        }
                                        const hasKaraoke = (LyricsService.karaoke && LyricsService.karaokeLines && LyricsService.karaokeLines.length > 0)
                                        if (hasKaraoke) {
                                            const idx = Math.max(0, LyricsService.currentIndex)
                                            // For the very first line, keep lyricOld empty so it doesn't block leading dots
                                            if (idx === 0) {
                                                item.segments = []
                                                item.text = ""
                                                if (item.hasOwnProperty('suppressLeadingGap')) item.suppressLeadingGap = true
                                                item.baseStartMs = 0
                                                item.nextStartMs = 3600000
                                            } else {
                                                item.segments = LyricsService.karaokeSegmentsFor(idx - 1)
                                                item.baseStartMs = (LyricsService.karaokeLines[idx - 1]?.start || 0)
                                                item.nextStartMs = (LyricsService.karaokeLines[idx]?.start || lyricOld.item.baseStartMs)
                                                item.nextStartMs = (LyricsService.karaokeLines[idx]?.start !== undefined) ? LyricsService.karaokeLines[idx].start : (item.baseStartMs + 3600000)
                                                // Dots removed: no suppressLeadingGap
                                                item.text = (LyricsService.karaokeLines[idx - 1]?.text || lyricsView.prevText)
                                            }
                                            // Configure timing first to reset monotonic state before first ms hit
                                            item.timesRelative = false
                                            item.baseStartMs = (LyricsService.karaokeLines[idx - 1]?.start || 0)
                                            item.nextStartMs = (LyricsService.karaokeLines[idx]?.start !== undefined) ? LyricsService.karaokeLines[idx].start : (item.baseStartMs + 3600000)
                                            // Provide segments and visuals
                                            item.segments = LyricsService.karaokeSegmentsFor(idx - 1)
                                            item.baseColor = Appearance.colors.colOnLayer1
                                            item.highlightColor = "#8aadf4"
                                            item.pixelSize = Appearance.font.pixelSize.small
                                            item.baseOpacity = 0.25
                                            item.overlayOpacity = 1.0
                                            if (item.hasOwnProperty('gapMinMs')) item.gapMinMs = dynamicIsland.lyricsGapMinMs
                                            // Bind currentMs so it follows karaokeMs continuously (after base/segments set)
                                            try { item.currentMs = Qt.binding(function(){ return lyricsView.karaokeMs }) } catch(e) { item.currentMs = lyricsView.karaokeMs }
                                        } else {
                                            item.text = lyricsView.prevText
                                            item.font.pixelSize = Appearance.font.pixelSize.small
                                            item.color = Appearance.colors.colOnLayer1
                                            item.horizontalAlignment = Text.AlignHCenter
                                            item.width = lyricStack.width
                                        }
                                        console.log("DynamicIsland: lyricOld onLoaded prevText.len=", (lyricsView.prevText||"").length,
                                                    "segments.len=", (LyricsService.karaoke ? (item.segments||[]).length : 0),
                                                    "currentMs=", (LyricsService.karaoke ? item.currentMs : -1))
										if (visible && GlobalStates.lyricsModeActive && dynamicIsland.mediaActive) Qt.callLater(dynamicIsland.scheduleWidthRecalc)
                                    }
                                }
                                Loader {
                                    id: lyricNew
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    // Vertically centered; use offset for slide-in
                                    anchors.verticalCenter: parent.verticalCenter
                                    // Start off-screen above to avoid pre-flash
                                    anchors.verticalCenterOffset: -(lyricNew.item ? lyricNew.item.implicitHeight : lyricStack.height)
                                    opacity: 0
                                    visible: false
                                    z: 2
                                    width: lyricStack.width
                                    sourceComponent: LyricsService.karaoke ? karaokeComp : textComp
									onLoaded: {
                                        console.log("DynamicIsland: lyricNew loaded comp=", (LyricsService.karaoke ? "karaoke" : "text"), "karaoke=", LyricsService.karaoke)
                                        // Enforce correct component (avoid flicker by only changing when needed)
                                        const targetNew = LyricsService.karaoke ? karaokeComp : textComp
                                        if (lyricNew.sourceComponent !== targetNew) lyricNew.sourceComponent = targetNew
                                        // Only show explicit "No lyrics" when service resolved to that state
                                        const explicitNoLyrics = (LyricsService.available && LyricsService.lines && LyricsService.lines.length > 0 && LyricsService.lines[0]?.text === "No lyrics")
                                        if (explicitNoLyrics) {
                                            if (lyricNew.item) {
                                                lyricNew.item.text = qsTr("No lyrics")
                                                lyricNew.item.font.pixelSize = Appearance.font.pixelSize.small
                                                lyricNew.item.color = Appearance.colors.colOnLayer1
                                                lyricNew.item.horizontalAlignment = Text.AlignHCenter
                                                lyricNew.item.width = lyricStack.width
                                            }
                                            return
                                        }
                                        if (LyricsService.karaoke) {
                                            const idx = Math.max(0, LyricsService.currentIndex)
                                            item.segments = LyricsService.karaokeSegmentsFor(idx)
                                            // Bind currentMs so it follows karaokeMs continuously
                                            try { item.currentMs = Qt.binding(function(){ return lyricsView.karaokeMs }) } catch(e) { item.currentMs = lyricsView.karaokeMs }
                                            item.timesRelative = false
                                            item.baseStartMs = (LyricsService.karaokeLines[idx]?.start || 0)
                                            // Next start: if there is a next line, use it; else push far in future
                                            item.nextStartMs = (LyricsService.karaokeLines[idx + 1]?.start !== undefined) ? LyricsService.karaokeLines[idx + 1].start : (item.baseStartMs + 3600000)
                                            item.baseColor = Appearance.colors.colOnLayer1
                                            item.highlightColor = "#8aadf4"
                                            item.pixelSize = Appearance.font.pixelSize.small
                                            item.baseOpacity = 0.25
                                            item.overlayOpacity = 1.0
                                            item.text = (LyricsService.karaokeLines[idx]?.text || lyricsView.currentText)
                                            // Dots removed: normal transition with no special first-line gap handling
                                            // Keep visible to avoid missing early lines
                                            lyricNew.visible = true
                                            lyricNew.opacity = 0
                                            if (lyricNew.item) lyricNew.anchors.verticalCenterOffset = -lyricNew.item.implicitHeight
                                        } else {
                                            item.text = lyricsView.currentText
                                            item.font.pixelSize = Appearance.font.pixelSize.small
                                            item.color = Appearance.colors.colOnLayer1
                                            item.horizontalAlignment = Text.AlignHCenter
                                            item.width = lyricStack.width
                                        }
                                        console.log("DynamicIsland: lyricNew onLoaded currText.len=", (lyricsView.currentText||"").length,
                                                    "segments.len=", (LyricsService.karaoke ? (item.segments||[]).length : 0),
                                                    "currentMs=", (LyricsService.karaoke ? item.currentMs : -1),
                                                    "currentIndex=", LyricsService.currentIndex)
										if (visible && GlobalStates.lyricsModeActive && dynamicIsland.mediaActive) Qt.callLater(dynamicIsland.scheduleWidthRecalc)
                                    }
                                }

                                // Components for text vs karaoke
                                Component { id: textComp; StyledText {} }
                                Component { id: karaokeComp; KaraokeLine {} }

                                // Update visual when the current line changes
                                function refresh() {
                                    console.log("DynamicIsland: lyricStack.refresh karaoke=", LyricsService.karaoke, "idx=", LyricsService.currentIndex)
                                    const idx = Math.max(0, LyricsService.currentIndex)
                                    // For first line, keep lyricNew visible/centered to allow leading dots before first word
                                    if (LyricsService.karaoke && idx === 0) {
                                        lyricNew.visible = true
                                        lyricNew.opacity = 1
                                        lyricNew.anchors.verticalCenterOffset = 0
                                        lyricOld.opacity = 0
                                    } else {
                                        // Keep new line positioned above; remain visible in karaoke to avoid missing lines
                                        lyricNew.visible = LyricsService.karaoke ? true : lyricNew.visible
                                        lyricNew.opacity = 0
                                        if (lyricNew.item) lyricNew.anchors.verticalCenterOffset = -lyricNew.item.implicitHeight
                                    }
                                    // Enforce correct component each refresh (only if changed)
                                    const targetOld2 = LyricsService.karaoke ? karaokeComp : textComp
                                    const targetNew2 = LyricsService.karaoke ? karaokeComp : textComp
                                    if (lyricOld.sourceComponent !== targetOld2) lyricOld.sourceComponent = targetOld2
                                    if (lyricNew.sourceComponent !== targetNew2) lyricNew.sourceComponent = targetNew2
                                    // If lyrics are still loading/unavailable, keep current visuals (avoid flashing "No lyrics")
                                    const explicitNoLyrics2 = (LyricsService.available && LyricsService.lines && LyricsService.lines.length > 0 && LyricsService.lines[0]?.text === "No lyrics")
                                    if (explicitNoLyrics2) {
                                        // Show explicit no-lyrics once resolved
                                        lyricOld.sourceComponent = textComp
                                        lyricNew.sourceComponent = textComp
                                        if (lyricOld.item) {
                                            lyricOld.item.text = qsTr("No lyrics")
                                            lyricOld.item.font.pixelSize = Appearance.font.pixelSize.small
                                            lyricOld.item.color = Appearance.colors.colOnLayer1
                                            lyricOld.item.horizontalAlignment = Text.AlignHCenter
                                            lyricOld.item.width = lyricStack.width
                                        }
                                        if (lyricNew.item) {
                                            lyricNew.item.text = qsTr("No lyrics")
                                            lyricNew.item.font.pixelSize = Appearance.font.pixelSize.small
                                            lyricNew.item.color = Appearance.colors.colOnLayer1
                                            lyricNew.item.horizontalAlignment = Text.AlignHCenter
                                            lyricNew.item.width = lyricStack.width
                                        }
                                        return
                                    }
                                    if (lyricOld.item) {
                                        const hasKaraokeOld = (LyricsService.karaoke && LyricsService.karaokeLines && LyricsService.karaokeLines.length > 0)
                                        if (hasKaraokeOld) {
                                            const segsOld = LyricsService.karaokeSegmentsFor(Math.max(0, idx - 1)) || []
                                            // Always provide text so KaraokeLine can fallback
                                            lyricOld.item.text = lyricsView.prevText
                                            if (segsOld.length > 0) {
                                                lyricOld.item.baseStartMs = (LyricsService.karaokeLines[Math.max(0, idx - 1)]?.start || 0)
                                                lyricOld.item.nextStartMs = (LyricsService.karaokeLines[idx]?.start || lyricOld.item.baseStartMs)
                                                lyricOld.item.timesRelative = false
                                                lyricOld.item.segments = segsOld
                                                lyricOld.item.currentMs = lyricsView.karaokeMs
                                            } else {
                                                // Keep KaraokeLine and let it render plain text fallback
                                                lyricOld.item.segments = []
                                                lyricOld.item.currentMs = lyricsView.karaokeMs
                                                lyricOld.item.timesRelative = false
                                                lyricOld.item.baseStartMs = (LyricsService.karaokeLines[Math.max(0, idx - 1)]?.start || 0)
                                                lyricOld.item.nextStartMs = (LyricsService.karaokeLines[idx]?.start || lyricOld.item.baseStartMs)
                                            }
                                        } else {
                                            lyricOld.item.text = lyricsView.prevText
                                        }
                                    }
                                    if (lyricNew.item) {
                                        const hasKaraokeNew = (LyricsService.karaoke && LyricsService.karaokeLines && LyricsService.karaokeLines.length > 0)
                                        if (hasKaraokeNew) {
                                            const segsNew = LyricsService.karaokeSegmentsFor(idx) || []
                                            // Always provide text so KaraokeLine can fallback
                                            lyricNew.item.text = lyricsView.currentText
                                            if (segsNew.length > 0) {
                                                lyricNew.item.baseStartMs = (LyricsService.karaokeLines[idx]?.start || 0)
                                                lyricNew.item.nextStartMs = (LyricsService.karaokeLines[Math.min(LyricsService.karaokeLines.length - 1, idx + 1)]?.start || lyricNew.item.baseStartMs)
                                                lyricNew.item.timesRelative = false
                                                lyricNew.item.segments = segsNew
                                                lyricNew.item.currentMs = lyricsView.karaokeMs
                                                if (lyricNew.item.hasOwnProperty('suppressLeadingGap')) lyricNew.item.suppressLeadingGap = (idx > 0)
                                            } else {
                                                // Keep KaraokeLine and let it render plain text fallback
                                                lyricNew.item.segments = []
                                                lyricNew.item.currentMs = lyricsView.karaokeMs
                                                lyricNew.item.timesRelative = false
                                                lyricNew.item.baseStartMs = 0
                                                lyricNew.item.nextStartMs = 3600000
                                                lyricNew.item.currentMs = lyricsView.karaokeMs
                                            }
                                        } else {
                                            lyricNew.item.text = lyricsView.currentText
                                        }
                                    }
                                    if (lyricNew.item) console.log("DynamicIsland: lyricNew after refresh text.len=", (lyricNew.item.text||"").length, "segments.len=", (lyricNew.item.segments||[]).length)
                                    if (lyricOld.item) console.log("DynamicIsland: lyricOld after refresh text.len=", (lyricOld.item.text||"").length, "segments.len=", (lyricOld.item.segments||[]).length)
                                }

                                // Determine karaoke line index from current time
                                function idxForMs(ms) {
                                    const arr = LyricsService.karaokeLines || []
                                    if (!arr.length) return Math.max(0, LyricsService.currentIndex)
                                    for (let i = 0; i < arr.length; i++) {
                                        const s = arr[i]?.start || 0
                                        const n = arr[i+1]?.start
                                        if (ms < s) return Math.max(0, i - 1)
                                        if (n === undefined || ms < n) return i
                                    }
                                    return arr.length - 1
                                }
                            }

							onCurrentTextChanged: {
                                console.log("DynamicIsland: onCurrentTextChanged karaoke=", LyricsService.karaoke, "idx=", LyricsService.currentIndex,
                                            "curr.len=", (lyricsView.currentText||"").length, "prev.len=", (lyricsView.prevText||"").length)
                                // Prepare animation: move new from top (hidden), push old down
                                lyricsView.prevText = lyricNew.item && (LyricsService.karaoke ? (LyricsService.karaokeLines[Math.max(0, LyricsService.currentIndex - 1)]?.text || lyricNew.item.text) : lyricNew.item.text) || ""
                                // Ensure new is hidden and off-screen BEFORE refresh to avoid a flash
                                lyricNew.opacity = 0
                                lyricNew.anchors.verticalCenterOffset = -(lyricNew.item ? lyricNew.item.implicitHeight : lyricStack.height)
                                lyricOld.anchors.verticalCenterOffset = 0
                                lyricOld.opacity = 1
                                // Refresh content, then animate in the new line
                                lyricStack.refresh()
                                Qt.callLater(function() {
                                    // Position new just above using its final height and reveal right before animation
                                    if (lyricNew.item) lyricNew.anchors.verticalCenterOffset = -lyricNew.item.implicitHeight
                                    // Keep visible even in karaoke to avoid missing early lines
                                    lyricNew.visible = true
                                    lyricNew.opacity = 0
                                    animGrp.start()
									if (GlobalStates.lyricsModeActive && dynamicIsland.mediaActive) dynamicIsland.scheduleWidthRecalc()
                                })
                            }

                            /* onKaraokeMsChanged: {
                                __tickCount++
                                if (lyricNew.item && LyricsService.karaoke) lyricNew.item.currentMs = karaokeMs
                                if (lyricOld.item && LyricsService.karaoke) lyricOld.item.currentMs = karaokeMs
                                if ((__tickCount % 15) === 0) console.log("DynamicIsland: karaokeMs=", karaokeMs)
                            } */

                            SequentialAnimation {
                                id: animGrp
                                running: false
                                onStarted: {
                                    // Reveal the new line only at animation start (karaoke mode)
                                    if (LyricsService.karaoke) {
                                        lyricNew.visible = true
                                    }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: lyricOld.anchors; property: "verticalCenterOffset"; to: (lyricOld.item ? (lyricOld.item.implicitHeight) : lyricStack.height); duration: dynamicIsland.lyricsTransitionDuration; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: lyricOld; property: "opacity"; to: 0; duration: dynamicIsland.lyricsTransitionDuration; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: lyricNew.anchors; property: "verticalCenterOffset"; to: 0; duration: dynamicIsland.lyricsTransitionDuration; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: lyricNew; property: "opacity"; to: 1; duration: dynamicIsland.lyricsTransitionDuration; easing.type: Easing.InOutQuad }
                                }
                                onStopped: {
                                    // Ensure old is hidden and reset after animation completes
                                    lyricOld.opacity = 0
                                    lyricOld.anchors.verticalCenterOffset = 0
                                }
                            }
                        }

						// Media title view (fallback when lyrics not active)
						Item {
							id: titleView
							anchors.fill: parent
							visible: !GlobalStates.lyricsModeActive
							opacity: visible ? 1 : 0
							Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
							StyledText {
								id: mediaTitle
								// Make sure text is on top as well
								z: 11
								// Place at left of content and vertically centered within the visible area
								x: 0
								y: Math.floor((titleScrollContainer.height - implicitHeight) / 2)
								// Use full implicit width so Flickable can scroll the hidden part
								width: titleContainer.titleHovered ? implicitWidth : titleScrollContainer.width
								text: `${StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")}${MprisController.activePlayer?.trackArtist ? " - " + MprisController.activePlayer.trackArtist : ""}`
								font.pixelSize: Appearance.font.pixelSize.small
								color: Appearance.colors.colOnLayer1
								// No elide; clipping and Flickable manage visibility
								elide: titleContainer.titleHovered ? Text.ElideNone : Text.ElideRight
								// Amount to scroll when overflowing
								property real overflow: Math.max(0, titleScrollContainer.contentWidth - titleScrollContainer.width)
								// Marquee animation: scroll via Flickable contentX
								SequentialAnimation {
									id: marqueeAnim
									loops: Animation.Infinite
									running: titleContainer.titleHovered && titleContainer.titleTruncated
									onRunningChanged: {
										if (!running) titleScrollContainer.contentX = 0
									}
									PauseAnimation { duration: 600 }
									NumberAnimation { target: titleScrollContainer; property: "contentX"; to: mediaTitle.overflow; duration: Math.max(2000, 40 * mediaTitle.overflow); easing.type: Easing.InOutQuad }
									PauseAnimation { duration: 800 }
									NumberAnimation { target: titleScrollContainer; property: "contentX"; to: 0; duration: Math.max(1200, 30 * mediaTitle.overflow); easing.type: Easing.InOutQuad }
								}
								onTextChanged: { if (dynamicIsland.mediaActive) dynamicIsland.scheduleWidthRecalc() }
								onImplicitWidthChanged: {
									if (dynamicIsland.mediaActive) dynamicIsland.scheduleWidthRecalc()
									if (titleContainer.titleHovered && titleContainer.titleTruncated) marqueeAnim.restart()
								}
							}
						}
					}

					// Timer info removed from center; now shown as a left-side indicator
				}

				// Progress bar
				Item {
					Layout.fillWidth: true
					Layout.minimumWidth: (titleContainer.titleHovered && (titleContainer.titleTruncatedLatched || titleContainer.titleTruncated)) ? 60 : 80
					Layout.preferredWidth: (titleContainer.titleHovered && (titleContainer.titleTruncatedLatched || titleContainer.titleTruncated)) ? 80 : 120
					Layout.maximumWidth: (titleContainer.titleHovered && (titleContainer.titleTruncatedLatched || titleContainer.titleTruncated)) ? 100 : 160
					Layout.preferredHeight: 8
					// Keep progress bar visually below the title
					z: 0
					Layout.alignment: Qt.AlignVCenter
					Layout.leftMargin: 4
					Layout.rightMargin: 4
					visible: !GlobalStates.lyricsModeActive
					opacity: visible ? 1 : 0
					Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
					
					Behavior on Layout.minimumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
					Behavior on Layout.preferredWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
					Behavior on Layout.maximumWidth { 
						NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } 
					}
					StyledProgressBar {
						id: dynamicIslandProgressBar
						anchors.fill: parent
						highlightColor: Appearance.colors.colPrimary
						trackColor: Appearance.colors.colLayer1
						// Initial value
						value: (MprisController.activePlayer?.length > 0 && MprisController.activePlayer?.position >= 0) ? MprisController.activePlayer.position / MprisController.activePlayer.length : 0
						wavy: MprisController.activePlayer?.isPlaying ? true : false
						waveAmplitudeMultiplier: MprisController.activePlayer?.isPlaying ? 0.2 : 0.0
						valueBarHeight: 3
						valueBarWidth: parent.width
						valueBarGap: 8

						// Timer to force progress updates, as the binding can be unreliable
						Timer {
							interval: 500 // Update twice a second
							running: MprisController.activePlayer?.isPlaying
							repeat: true
							onTriggered: {
								if (MprisController.activePlayer && MprisController.activePlayer.length > 0) {
									dynamicIslandProgressBar.value = MprisController.activePlayer.position / MprisController.activePlayer.length;
								} else {
									dynamicIslandProgressBar.value = 0;
								}
							}
						}
					}
				}
				RippleButton {
					z: 0
					Layout.alignment: Qt.AlignVCenter
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.previous()
					colBackground: Appearance.colors.colSecondaryContainer
					colBackgroundHover: Appearance.colors.colSecondaryContainerHover
					colRipple: Appearance.colors.colSecondaryContainerActive
					visible: !GlobalStates.lyricsModeActive
					opacity: visible ? 1 : 0
					Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
					contentItem: Item {
						anchors.centerIn: parent
						width: 13; height: 13
						readonly property bool usePlumpy: true
						PlumpyIcon {
							id: islandPrevPlumpy
							anchors.centerIn: parent
							visible: parent.usePlumpy
							iconSize: parent.width
							name: "previous"
							primaryColor: Appearance.colors.colOnSecondaryContainer
						}
						MaterialSymbol {
							anchors.centerIn: parent
							visible: !parent.usePlumpy || !islandPrevPlumpy.available
							iconSize: parent.width
							fill: 1
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
							color: Appearance.colors.colOnSecondaryContainer
							text: "skip_previous"
						}
					}
				}
				RippleButton {
					Layout.alignment: Qt.AlignVCenter
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.togglePlaying()
					buttonRadius: MprisController.activePlayer?.isPlaying ? Appearance.rounding.howthingsshouldbe : 9
					colBackground: Appearance.colors.colPrimary
					colBackgroundHover: Appearance.colors.colPrimaryHover
					colRipple: Appearance.colors.colPrimaryActive
					visible: !GlobalStates.lyricsModeActive
					opacity: visible ? 1 : 0
					Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
					
					Behavior on buttonRadius { 
						NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } 
					}
					
					contentItem: Item {
						anchors.centerIn: parent
						width: 13; height: 13
						readonly property bool usePlumpy: true
						PlumpyIcon {
							id: islandPlayPlumpy
							anchors.centerIn: parent
							visible: parent.usePlumpy
							iconSize: parent.width
							name: MprisController.activePlayer?.isPlaying ? "pause" : "play"
							primaryColor: Appearance.colors.colOnPrimary
						}
						MaterialSymbol {
							anchors.centerIn: parent
							visible: !parent.usePlumpy || !islandPlayPlumpy.available
							iconSize: parent.width
							fill: 1
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
							color: Appearance.colors.colOnPrimary
							text: MprisController.activePlayer?.isPlaying ? "pause" : "play_arrow"
						}
					}
				}
				RippleButton {
					Layout.alignment: Qt.AlignVCenter
					Layout.preferredWidth: 18
					Layout.preferredHeight: 18
					padding: 0
					onPressed: MprisController.activePlayer.next()
					colBackground: Appearance.colors.colSecondaryContainer
					colBackgroundHover: Appearance.colors.colSecondaryContainerHover
					colRipple: Appearance.colors.colSecondaryContainerActive
					visible: !GlobalStates.lyricsModeActive
					opacity: visible ? 1 : 0
					Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
					contentItem: Item {
						anchors.centerIn: parent
						width: 13; height: 13
						readonly property bool usePlumpy: Config.options.sidebar?.icons?.usePlumpyRightToggles ?? false
						PlumpyIcon {
							id: islandNextPlumpy
							anchors.centerIn: parent
							visible: parent.usePlumpy
							iconSize: parent.width
							name: "skip"
							primaryColor: Appearance.colors.colOnSecondaryContainer
						}
						MaterialSymbol {
							anchors.centerIn: parent
							visible: !parent.usePlumpy || !islandNextPlumpy.available
							iconSize: parent.width
							fill: 1
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
							color: Appearance.colors.colOnSecondaryContainer
							text: "skip_next"
						}
					}
				}
			}
		}



		// Active window section
		Item {
			id: root
			readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
			readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

			property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
			property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
			property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)
			visible: dynamicIsland.showActiveWindow
			// Match the Dynamic Island's current width and center within the local parent
			width: dynamicIsland.width
			height: parent.height
			x: Math.round((parent.width - width) / 2)
			clip: true
			onVisibleChanged: if (visible) dynamicIsland.scheduleWidthRecalc()


			// When derived window state changes, recalc width
			onFocusingThisMonitorChanged: if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()
			onBiggestWindowChanged: if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()

			Connections {
				target: root.activeWindow
				function onActivatedChanged() {
					if (dynamicIsland.showActiveWindow) dynamicIsland.updateWidth()
				}
			}
			
			Item {
				id: activeWindowTitleBox
				// Fill the active window section exactly (the section itself matches/centers to island)
				width: parent.width
				height: parent.height
				x: 0
				y: 0

				// Inner content box: width tracks text, centered within the section
				Item {
					id: titleContentBox
					readonly property int sideMargin: 8
					// Width is the measured baseline content width of the text, clamped to the active window section's width
					width: Math.min(parent.width - sideMargin * 2, Math.max(0, activeWindowTitleMeasure.contentWidth))
					height: parent.height
					anchors.centerIn: parent

					onWidthChanged: if (dynamicIsland.showActiveWindow) activeWindowTitle.fitToAvailable()
					// Hidden measurer for stable baseline width (avoid feedback from fitted text)
					StyledText {
						id: activeWindowTitleMeasure
						visible: false
						text: activeWindowTitle.text
						font.pixelSize: Appearance.font.pixelSize.small
						// Ensure full baseline width is measured (no wrapping/elide)
						elide: Text.ElideNone
						horizontalAlignment: Text.AlignLeft
						clip: false
					}
					StyledText {
						id: activeWindowTitle
						anchors.fill: parent
						text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ? 
							root.activeWindow?.title :
							(root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${root.monitor?.activeWorkspace?.id ?? 1}`
						font.pixelSize: Appearance.font.pixelSize.small
						color: Appearance.colors.colOnLayer1
						elide: Text.ElideRight
						horizontalAlignment: Text.AlignHCenter
						verticalAlignment: Text.AlignVCenter
						clip: true
						function fitToAvailable() {
							// Only shrink font when the island is at its maximum width and text still overflows.
							Qt.callLater(function() {
								const baseline = Appearance.font.pixelSize.small
								const minSize = 8
								// reset to baseline to measure true width
								activeWindowTitle.font.pixelSize = baseline
								const atMax = Math.abs(dynamicIsland.width - dynamicIsland.effectiveMaxWidth) < 1
								const available = titleContentBox.width
								const iw = activeWindowTitle.implicitWidth
								if (atMax && iw > 0 && available > 0 && iw > available) {
									const scale = available / iw
									const newSize = Math.max(minSize, Math.floor(baseline * scale))
									activeWindowTitle.font.pixelSize = newSize
								} else {
									activeWindowTitle.font.pixelSize = baseline
								}
							})
						}
						onTextChanged: if (dynamicIsland.showActiveWindow) activeWindowTitle.fitToAvailable()
					}
				}
			}


		}
	}
}
